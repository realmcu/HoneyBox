package com.ebadge.ebadge_app

import android.content.Context
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.hardware.camera2.CaptureRequest
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Size
import android.view.Surface
import io.flutter.view.TextureRegistry
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer

/**
 * Encoder configuration passed from Dart.
 *
 * [cropZoom] is a center-crop / digital-zoom factor (1.0 = full field of view).
 * [iFrameIntervalSec] only applies to H.264.
 */
data class EncoderConfig(
    val format: String,        // "h264" | "jpeg" | "mvs1"
    val width: Int,
    val height: Int,
    val fps: Int,
    val bitrate: Int,          // bits per second
    val iFrameIntervalSec: Int,
    val cropZoom: Double,
)

/** Sink for diagnostic / lifecycle events delivered back to Dart. */
interface EncoderEvents {
    fun onEvent(payload: Map<String, Any?>)
}

/**
 * Camera2 → GL → MediaCodec H.264 encoding pipeline.
 *
 * Camera2 renders into a single OES texture owned by [GlRenderer]. The GL stage
 * draws each frame — crop → uniform-scale → rotation baked in — to the Flutter
 * preview texture and (while encoding) to the MediaCodec input surface. Because
 * GL scales, the encoder output may be **any** resolution, independent of the
 * camera's supported sizes, with crop-then-uniform-scale (等比例) semantics.
 *
 * H.264 is configured for constrained-baseline profile, no B-frames, and a
 * YUV420 internal color format (Surface input). MVS1/JPEG are placeholders.
 */
class CameraEncoder(
    private val context: Context,
    private val textureRegistry: TextureRegistry,
    private val events: EncoderEvents,
) {
    private val mainHandler = Handler(Looper.getMainLooper())

    // ── Camera ────────────────────────────────────────────────────────────
    private val cameraManager =
        context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private var cameraThread: HandlerThread? = null
    private var cameraHandler: Handler? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var sensorOrientation = 90
    private var lensFacing = CameraCharacteristics.LENS_FACING_BACK
    private var facingFront = false
    private var supportedSizes: Array<Size>? = null
    private var availableFpsRanges: Array<android.util.Range<Int>>? = null
    private var captureSize = Size(1280, 720)

    // ── Focus / exposure ───────────────────────────────────────────────────
    private var sensorActiveArray: android.graphics.Rect? = null
    private var maxAfRegions = 0
    private var maxAeRegions = 0
    private var aeCompRange: android.util.Range<Int>? = null
    private var aeCompStep = 0.0 // EV per compensation step
    private var evSteps = 0
    private var afRegion: android.hardware.camera2.params.MeteringRectangle? = null

    // ── Preview (Flutter texture) ───────────────────────────────────────────
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var previewSurface: Surface? = null
    private var previewSize = Size(1280, 720)

    // ── GL stage ──────────────────────────────────────────────────────────
    private var renderer: GlRenderer? = null

    // ── Encoder ───────────────────────────────────────────────────────────
    private var codec: MediaCodec? = null
    private var inputSurface: Surface? = null
    private var codecThread: HandlerThread? = null
    private var codecHandler: Handler? = null
    private var outputStream: FileOutputStream? = null
    private var outputFile: File? = null

    @Volatile private var encoding = false
    @Volatile private var finishing = false
    @Volatile private var config: EncoderConfig? = null
    private var encWidth = 0
    private var encHeight = 0

    private var frameCount = 0
    private var keyframeCount = 0
    private var totalBytes = 0L
    private var firstPtsUs = -1L
    private var lastPtsUs = 0L

    // -------------------------------------------------------------------------
    // Camera lifecycle
    // -------------------------------------------------------------------------

    fun openCamera(facingFront: Boolean, cfg: EncoderConfig) {
        closeCamera()
        config = cfg
        this.facingFront = facingFront
        startCameraThread()

        try {
            lensFacing = if (facingFront) {
                CameraCharacteristics.LENS_FACING_FRONT
            } else {
                CameraCharacteristics.LENS_FACING_BACK
            }
            val id = pickCameraId(lensFacing) ?: run {
                emitError("未找到摄像头")
                return
            }
            val chars = cameraManager.getCameraCharacteristics(id)
            sensorOrientation = chars.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
            val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            supportedSizes = map?.getOutputSizes(SurfaceTexture::class.java)
            availableFpsRanges =
                chars.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
            captureSize = chooseSize(supportedSizes, 1280, 720)

            // Focus / exposure capabilities.
            sensorActiveArray =
                chars.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
            maxAfRegions = chars.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AF) ?: 0
            maxAeRegions = chars.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AE) ?: 0
            aeCompRange =
                chars.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE)
            val step = chars.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP)
            aeCompStep =
                if (step != null) step.numerator.toDouble() / step.denominator else 0.0
            evSteps = 0
            afRegion = null

            // Flutter preview texture, sized to the output aspect ratio so the
            // preview is WYSIWYG with the encoded frame.
            previewSize = previewSizeFor(cfg.width, cfg.height)
            val entry = textureRegistry.createSurfaceTexture()
            textureEntry = entry
            val st = entry.surfaceTexture()
            st.setDefaultBufferSize(previewSize.width, previewSize.height)
            previewSurface = Surface(st)

            // Spin up the GL stage; it creates the camera input surface.
            val gl = GlRenderer(
                onError = { msg -> emitError(msg) },
                onInfo = { msg -> emitInfo(msg) },
            )
            renderer = gl
            gl.setParams(
                sensorOrientation, facingFront, cfg.width, cfg.height, cfg.cropZoom,
            )
            gl.start(captureSize.width, captureSize.height) { camSurface ->
                gl.setPreviewSurface(previewSurface, previewSize.width, previewSize.height)
                openDevice(id, camSurface)
            }
        } catch (e: Exception) {
            emitError("打开摄像头失败: ${e.message}")
        }
    }

    private fun openDevice(id: String, cameraSurface: Surface) {
        try {
            cameraManager.openCamera(id, object : CameraDevice.StateCallback() {
                override fun onOpened(device: CameraDevice) {
                    cameraDevice = device
                    buildSession(cameraSurface)
                }

                override fun onDisconnected(device: CameraDevice) {
                    device.close()
                    cameraDevice = null
                }

                override fun onError(device: CameraDevice, error: Int) {
                    device.close()
                    cameraDevice = null
                    emitError("摄像头错误: $error")
                }
            }, cameraHandler)
        } catch (e: SecurityException) {
            emitError("缺少相机权限")
        } catch (e: Exception) {
            emitError("打开摄像头失败: ${e.message}")
        }
    }

    private fun buildSession(cameraSurface: Surface) {
        val device = cameraDevice ?: return
        try {
            @Suppress("DEPRECATION")
            device.createCaptureSession(
                listOf(cameraSurface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        captureSession = session
                        issueRepeating()
                        emitCameraReady()
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        emitError("会话配置失败")
                    }
                },
                cameraHandler,
            )
        } catch (e: Exception) {
            emitError("创建会话失败: ${e.message}")
        }
    }

    /** Apply FPS, exposure compensation, and AF/AE regions to a request. */
    private fun applyRequest(builder: CaptureRequest.Builder) {
        builder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
        builder.set(
            CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE,
            chooseFpsRange(config?.fps ?: 30),
        )
        aeCompRange?.let {
            builder.set(
                CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION,
                evSteps.coerceIn(it.lower, it.upper),
            )
        }

        val region = afRegion
        if (region != null && maxAfRegions > 0) {
            builder.set(CaptureRequest.CONTROL_AF_MODE, CameraMetadata.CONTROL_AF_MODE_AUTO)
            builder.set(CaptureRequest.CONTROL_AF_REGIONS, arrayOf(region))
        } else {
            builder.set(
                CaptureRequest.CONTROL_AF_MODE,
                CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_VIDEO,
            )
        }
        if (region != null && maxAeRegions > 0) {
            builder.set(CaptureRequest.CONTROL_AE_REGIONS, arrayOf(region))
        }
    }

    private fun issueRepeating() {
        val device = cameraDevice ?: return
        val session = captureSession ?: return
        val surface = renderer?.cameraSurface() ?: return
        try {
            val builder = device.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
            builder.addTarget(surface)
            applyRequest(builder)
            session.setRepeatingRequest(builder.build(), null, cameraHandler)
        } catch (e: Exception) {
            emitError("启动取景失败: ${e.message}")
        }
    }

    /** Tap-to-focus: [nx],[ny] are normalized [0,1] in the displayed preview. */
    fun focusAt(nx: Double, ny: Double) {
        val active = sensorActiveArray ?: return
        if (maxAfRegions <= 0 && maxAeRegions <= 0) return

        // 1. Undo the GL display crop → full upright-image normalized coords.
        val (fx, fy) = visibleFraction()
        val ux = 0.5 + (nx - 0.5) * fx
        val uy = 0.5 + (ny - 0.5) * fy

        // 2. Undo rotation → sensor-native normalized coords.
        var vx: Double
        var vy: Double
        when (sensorOrientation) {
            90 -> { vx = uy; vy = 1 - ux }
            270 -> { vx = 1 - uy; vy = ux }
            180 -> { vx = 1 - ux; vy = 1 - uy }
            else -> { vx = ux; vy = uy }
        }
        if (facingFront) vx = 1 - vx
        vx = vx.coerceIn(0.0, 1.0)
        vy = vy.coerceIn(0.0, 1.0)

        // 3. Build a small metering rectangle around the point.
        val cx = active.left + (vx * active.width()).toInt()
        val cy = active.top + (vy * active.height()).toInt()
        val half = (active.width() * 0.07).toInt().coerceAtLeast(1)
        val left = (cx - half).coerceIn(active.left, active.right - 1)
        val top = (cy - half).coerceIn(active.top, active.bottom - 1)
        val right = (cx + half).coerceIn(left + 1, active.right)
        val bottom = (cy + half).coerceIn(top + 1, active.bottom)
        afRegion = android.hardware.camera2.params.MeteringRectangle(
            left, top, right - left, bottom - top,
            android.hardware.camera2.params.MeteringRectangle.METERING_WEIGHT_MAX,
        )

        issueRepeating()
        triggerAf()
    }

    /** Fire a one-shot AF trigger for the current region. */
    private fun triggerAf() {
        val device = cameraDevice ?: return
        val session = captureSession ?: return
        val surface = renderer?.cameraSurface() ?: return
        try {
            val builder = device.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
            builder.addTarget(surface)
            applyRequest(builder)
            builder.set(
                CaptureRequest.CONTROL_AF_TRIGGER,
                CameraMetadata.CONTROL_AF_TRIGGER_START,
            )
            session.capture(builder.build(), null, cameraHandler)
        } catch (_: Exception) {
        }
    }

    /** Set exposure compensation in EV stops. */
    fun setEv(ev: Double) {
        evSteps = if (aeCompStep > 0) Math.round(ev / aeCompStep).toInt() else 0
        issueRepeating()
    }

    /** Display-space visible width/height fractions after crop + zoom. */
    private fun visibleFraction(): Pair<Double, Double> {
        val cfg = config ?: return 1.0 to 1.0
        val swap = sensorOrientation % 180 != 0
        val ew = (if (swap) captureSize.height else captureSize.width).toDouble()
        val eh = (if (swap) captureSize.width else captureSize.height).toDouble()
        val outAspect = cfg.width.toDouble() / cfg.height
        var fx: Double
        var fy: Double
        if (ew / eh > outAspect) {
            fx = (eh * outAspect) / ew
            fy = 1.0
        } else {
            fx = 1.0
            fy = (ew / outAspect) / eh
        }
        val zoom = cfg.cropZoom.coerceAtLeast(1.0)
        return (fx / zoom) to (fy / zoom)
    }

    /** Update live params (crop/zoom/aspect/fps) without reopening the camera. */
    fun setConfig(cfg: EncoderConfig) {
        config = cfg
        renderer?.setParams(
            sensorOrientation, facingFront, cfg.width, cfg.height, cfg.cropZoom,
        )

        // If the output aspect changed, resize the preview texture to match.
        val newPreview = previewSizeFor(cfg.width, cfg.height)
        if (newPreview.width != previewSize.width ||
            newPreview.height != previewSize.height
        ) {
            previewSize = newPreview
            textureEntry?.surfaceTexture()?.setDefaultBufferSize(
                newPreview.width, newPreview.height,
            )
            previewSurface?.release()
            val st = textureEntry?.surfaceTexture()
            if (st != null) {
                val s = Surface(st)
                previewSurface = s
                renderer?.setPreviewSurface(s, newPreview.width, newPreview.height)
            }
            emitCameraReady()
        }

        // Re-issue the repeating request so an updated FPS takes effect.
        issueRepeating()
    }

    fun closeCamera() {
        stopEncodingInternal()
        try {
            captureSession?.close()
        } catch (_: Exception) {
        }
        captureSession = null
        try {
            cameraDevice?.close()
        } catch (_: Exception) {
        }
        cameraDevice = null

        renderer?.release()
        renderer = null

        previewSurface?.release()
        previewSurface = null
        textureEntry?.release()
        textureEntry = null

        stopCameraThread()
    }

    // -------------------------------------------------------------------------
    // Encoding lifecycle
    // -------------------------------------------------------------------------

    fun startEncoding(cfg: EncoderConfig) {
        if (encoding) {
            emitError("已在编码中")
            return
        }
        if (cfg.format != "h264") {
            emitError("${cfg.format.uppercase()} 编码暂未实现（占位）")
            return
        }
        if (cameraDevice == null || renderer == null) {
            emitError("摄像头未就绪")
            return
        }
        config = cfg
        encWidth = cfg.width
        encHeight = cfg.height
        renderer?.setParams(
            sensorOrientation, facingFront, cfg.width, cfg.height, cfg.cropZoom,
        )

        try {
            prepareOutputFile(cfg)
            configureCodec(cfg)

            frameCount = 0
            keyframeCount = 0
            totalBytes = 0L
            firstPtsUs = -1L
            lastPtsUs = 0L
            encoding = true
            finishing = false

            codec?.start()
            // Route GL frames into the encoder input surface.
            renderer?.setEncoderSurface(inputSurface, encWidth, encHeight)

            mainHandler.post {
                events.onEvent(
                    mapOf(
                        "event" to "started",
                        "path" to outputFile?.absolutePath,
                        "width" to encWidth,
                        "height" to encHeight,
                    ),
                )
            }
        } catch (e: Exception) {
            encoding = false
            emitError("启动编码失败: ${e.message}")
            stopEncodingInternal()
        }
    }

    fun stopEncoding() {
        if (!encoding) return
        encoding = false
        // Stop feeding the encoder, then flush it with an end-of-stream signal.
        renderer?.setEncoderSurface(null, 0, 0)
        try {
            codec?.signalEndOfInputStream()
        } catch (e: Exception) {
            finishEncoding()
        }
    }

    private fun configureCodec(cfg: EncoderConfig) {
        startCodecThread()

        val format = MediaFormat.createVideoFormat(
            MediaFormat.MIMETYPE_VIDEO_AVC, encWidth, encHeight,
        )
        format.setInteger(
            MediaFormat.KEY_COLOR_FORMAT,
            MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
        )
        format.setInteger(MediaFormat.KEY_BIT_RATE, cfg.bitrate)
        format.setInteger(MediaFormat.KEY_FRAME_RATE, cfg.fps)
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, cfg.iFrameIntervalSec)

        // Constrained baseline profile, YUV420 (Surface input), no B-frames.
        format.setInteger(
            MediaFormat.KEY_PROFILE,
            MediaCodecInfo.CodecProfileLevel.AVCProfileConstrainedBaseline,
        )
        format.setInteger(
            MediaFormat.KEY_LEVEL,
            MediaCodecInfo.CodecProfileLevel.AVCLevel31,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            format.setInteger(MediaFormat.KEY_MAX_B_FRAMES, 0)
            format.setInteger(MediaFormat.KEY_LATENCY, 1)
        }
        format.setInteger(
            MediaFormat.KEY_BITRATE_MODE,
            MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR,
        )

        val mediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        mediaCodec.setCallback(codecCallback, codecHandler)
        mediaCodec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        inputSurface = mediaCodec.createInputSurface()
        codec = mediaCodec
    }

    private val codecCallback = object : MediaCodec.Callback() {
        override fun onInputBufferAvailable(mc: MediaCodec, index: Int) {
            // Surface input — no manual input buffers.
        }

        override fun onOutputBufferAvailable(
            mc: MediaCodec,
            index: Int,
            info: MediaCodec.BufferInfo,
        ) {
            try {
                val buffer: ByteBuffer? = mc.getOutputBuffer(index)
                if (buffer != null && info.size > 0) {
                    buffer.position(info.offset)
                    buffer.limit(info.offset + info.size)
                    val bytes = ByteArray(info.size)
                    buffer.get(bytes)
                    outputStream?.write(bytes)
                    totalBytes += info.size

                    val isConfig =
                        (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0
                    val isKey =
                        (info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME) != 0
                    if (!isConfig) {
                        frameCount++
                        if (isKey) keyframeCount++
                        if (firstPtsUs < 0) firstPtsUs = info.presentationTimeUs
                        lastPtsUs = info.presentationTimeUs
                        maybeEmitStats()
                    }
                }
                mc.releaseOutputBuffer(index, false)

                if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                    finishEncoding()
                }
            } catch (e: Exception) {
                emitError("写入失败: ${e.message}")
            }
        }

        override fun onError(mc: MediaCodec, e: MediaCodec.CodecException) {
            emitError("编码器错误: ${e.message}")
        }

        override fun onOutputFormatChanged(mc: MediaCodec, format: MediaFormat) {
            // SPS/PPS arrive as a CODEC_CONFIG output buffer for Annex-B output.
        }
    }

    private fun maybeEmitStats() {
        if (frameCount % 10 != 0) return
        val durSec = if (firstPtsUs >= 0) (lastPtsUs - firstPtsUs) / 1_000_000.0 else 0.0
        val fps = if (durSec > 0) frameCount / durSec else 0.0
        val frames = frameCount
        val keyframes = keyframeCount
        val bytes = totalBytes
        mainHandler.post {
            events.onEvent(
                mapOf(
                    "event" to "stats",
                    "frames" to frames,
                    "keyframes" to keyframes,
                    "bytes" to bytes,
                    "fps" to fps,
                ),
            )
        }
    }

    /** Drained EOS (codec thread) → tear down on the main thread. */
    private fun finishEncoding() {
        if (finishing) return
        finishing = true
        val file = outputFile
        val frames = frameCount
        val keyframes = keyframeCount
        val bytes = totalBytes
        mainHandler.post {
            stopEncodingInternal()
            events.onEvent(
                mapOf(
                    "event" to "stopped",
                    "path" to file?.absolutePath,
                    "frames" to frames,
                    "keyframes" to keyframes,
                    "bytes" to bytes,
                ),
            )
        }
    }

    private fun stopEncodingInternal() {
        encoding = false
        renderer?.setEncoderSurface(null, 0, 0)
        try {
            codec?.stop()
        } catch (_: Exception) {
        }
        try {
            codec?.release()
        } catch (_: Exception) {
        }
        codec = null
        inputSurface?.release()
        inputSurface = null

        try {
            outputStream?.flush()
            outputStream?.close()
        } catch (_: Exception) {
        }
        outputStream = null

        stopCodecThread()
    }

    // -------------------------------------------------------------------------
    // Output file
    // -------------------------------------------------------------------------

    private fun prepareOutputFile(cfg: EncoderConfig) {
        val dir = File(context.getExternalFilesDir(null), "encode_test")
        if (!dir.exists()) dir.mkdirs()
        val name = "enc_${encWidth}x${encHeight}_${cfg.fps}fps_${nextSeq()}.h264"
        val file = File(dir, name)
        outputFile = file
        outputStream = FileOutputStream(file)
    }

    // -------------------------------------------------------------------------
    // Threads
    // -------------------------------------------------------------------------

    private fun startCameraThread() {
        if (cameraThread != null) return
        cameraThread = HandlerThread("CameraThread").apply { start() }
        cameraHandler = Handler(cameraThread!!.looper)
    }

    private fun stopCameraThread() {
        cameraThread?.quitSafely()
        cameraThread = null
        cameraHandler = null
    }

    private fun startCodecThread() {
        if (codecThread != null) return
        codecThread = HandlerThread("CodecThread").apply { start() }
        codecHandler = Handler(codecThread!!.looper)
    }

    private fun stopCodecThread() {
        codecThread?.quitSafely()
        codecThread = null
        codecHandler = null
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private fun pickCameraId(facing: Int): String? {
        for (id in cameraManager.cameraIdList) {
            val chars = cameraManager.getCameraCharacteristics(id)
            if (chars.get(CameraCharacteristics.LENS_FACING) == facing) return id
        }
        return cameraManager.cameraIdList.firstOrNull()
    }

    private fun chooseSize(sizes: Array<Size>?, targetW: Int, targetH: Int): Size {
        if (sizes == null || sizes.isEmpty()) return Size(targetW, targetH)
        val targetArea = targetW.toLong() * targetH
        return sizes.minByOrNull {
            Math.abs(it.width.toLong() * it.height - targetArea)
        } ?: sizes[0]
    }

    /** Preview texture size at the output aspect ratio, long side ~1280. */
    private fun previewSizeFor(outW: Int, outH: Int): Size {
        if (outW <= 0 || outH <= 0) return Size(1280, 720)
        val aspect = outW.toDouble() / outH
        var pw: Int
        var ph: Int
        if (aspect >= 1.0) {
            pw = 1280
            ph = (1280 / aspect).toInt()
        } else {
            ph = 1280
            pw = (1280 * aspect).toInt()
        }
        pw = (pw / 2) * 2
        ph = (ph / 2) * 2
        return Size(pw.coerceAtLeast(2), ph.coerceAtLeast(2))
    }

    private fun chooseFpsRange(target: Int): android.util.Range<Int> {
        val ranges = availableFpsRanges
        if (ranges == null || ranges.isEmpty()) {
            return android.util.Range(target, target)
        }
        return ranges.minByOrNull { r ->
            val containsPenalty = if (target in r.lower..r.upper) 0 else 1000
            val fixedBonus = if (r.lower == r.upper) -1 else 0
            containsPenalty + Math.abs(r.upper - target) + fixedBonus
        } ?: android.util.Range(target, target)
    }

    private fun emitCameraReady() {
        val id = textureEntry?.id() ?: -1L
        val pw = previewSize.width
        val ph = previewSize.height
        val range = aeCompRange
        val evMin = if (range != null) range.lower * aeCompStep else 0.0
        val evMax = if (range != null) range.upper * aeCompStep else 0.0
        val focusSupported = maxAfRegions > 0 || maxAeRegions > 0
        mainHandler.post {
            events.onEvent(
                mapOf(
                    "event" to "camera",
                    "textureId" to id,
                    "previewWidth" to pw,
                    "previewHeight" to ph,
                    // Rotation is handled in GL, so the texture is already upright.
                    "sensorOrientation" to 0,
                    "facingFront" to facingFront,
                    "evMin" to evMin,
                    "evMax" to evMax,
                    "evStep" to aeCompStep,
                    "focusSupported" to focusSupported,
                ),
            )
        }
    }

    private fun emitError(message: String) {
        mainHandler.post {
            events.onEvent(mapOf("event" to "error", "message" to message))
        }
    }

    private fun emitInfo(message: String) {
        mainHandler.post {
            events.onEvent(mapOf("event" to "info", "message" to message))
        }
    }

    companion object {
        private var seq = 0
        private fun nextSeq(): Int = ++seq
    }
}

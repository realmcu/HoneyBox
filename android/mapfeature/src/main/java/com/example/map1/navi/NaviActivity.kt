package com.example.map1.navi

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import android.widget.Toast
import com.amap.api.navi.AMapNavi
import com.amap.api.navi.AMapNaviView
import com.amap.api.navi.AMapNaviViewOptions
import com.amap.api.navi.enums.NaviType
import com.amap.api.navi.enums.PathPlanningStrategy
import com.amap.api.navi.model.NaviLatLng
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/**
 * 模拟导航页面：
 *
 * 使用高德导航 SDK 的 [AMapNaviView] 自带 UI，配合 [AMapNavi] 进行路线规划，
 * 路线算好后调用 startNavi(NaviType.EMULATOR) 启动“模拟导航”。
 *
 * 起点 / 终点经纬度通过 Intent 传入，缺省使用北京天安门 -> 北京南站。
 */
class NaviActivity : Activity() {

    private lateinit var naviView: AMapNaviView
    private lateinit var aMapNavi: AMapNavi
    private var jpgTcpSender: NaviJpgTcpSender? = null
    private val captureHandler = Handler(Looper.getMainLooper())
    private val compressExecutor = Executors.newSingleThreadExecutor()
    private val nextSeq = AtomicInteger(0)
    private var fpsTextView: TextView? = null
    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var imageReader: ImageReader? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var captureWindowStartNs = 0L
    private var captureWindowFrames = 0
    private var captureWindowUiMs = 0L
    private var captureWindowEncodeMs = 0L
    private var captureWindowSendMs = 0L
    private var lastActualSendFps = 0.0
    private var lastBytesPerSecond = 0L

    private val startLatLng by lazy {
        NaviLatLng(
            intent.getDoubleExtra(EXTRA_START_LAT, 31.314),
            intent.getDoubleExtra(EXTRA_START_LNG, 120.728)
        )
    }
    private val endLatLng by lazy {
        NaviLatLng(
            intent.getDoubleExtra(EXTRA_END_LAT, 31.325),
            intent.getDoubleExtra(EXTRA_END_LNG, 120.629)
        )
    }

    /** 模拟导航行驶速度，单位 km/h */
    private val emulatorSpeed by lazy { intent.getIntExtra(EXTRA_SPEED, 60) }
    private val tcpHost by lazy { intent.getStringExtra(EXTRA_TCP_HOST).orEmpty().trim() }
    private val tcpPort by lazy { intent.getIntExtra(EXTRA_TCP_PORT, DEFAULT_TCP_PORT) }
    private val tcpFps by lazy { intent.getIntExtra(EXTRA_TCP_FPS, DEFAULT_TCP_FPS).coerceAtLeast(1) }

    private val captureRunnable = object : Runnable {
        override fun run() {
            captureAndSendJpgFrame()
            if (jpgTcpSender?.isRunning == true) {
                captureHandler.postDelayed(this, 1_000L / tcpFps)
            }
        }
    }

    private val naviListener = object : NaviListenerAdapter() {
        override fun onInitNaviSuccess() {
            // 初始化成功后开始算路（驾车，默认策略）。
            // 采用高德官方 demo 的标准写法：NaviLatLng 列表 + PathPlanningStrategy。
            val startList = arrayListOf(startLatLng)
            val endList = arrayListOf(endLatLng)
            val ok = aMapNavi.calculateDriveRoute(
                startList,
                endList,
                /* wayPoints = */ null,
                PathPlanningStrategy.DRIVING_DEFAULT
            )
            if (!ok) {
                toast("发起算路失败，请检查起终点坐标")
            }
        }

        override fun onInitNaviFailure() {
            toast("导航初始化失败")
        }

        override fun onCalculateRouteSuccess(result: com.amap.api.navi.model.AMapCalcRouteResult?) {
            // 算路成功，设置模拟速度并启动模拟导航
            aMapNavi.setEmulatorNaviSpeed(emulatorSpeed)
            aMapNavi.startNavi(NaviType.EMULATOR)
        }

        override fun onCalculateRouteFailure(result: com.amap.api.navi.model.AMapCalcRouteResult?) {
            // 参考高德 demo：打印错误码 + 中文描述，方便定位
            val code = result?.errorCode
            val desc = result?.errorDescription
            val detail = result?.errorDetail
            Log.e(TAG, "路线计算失败：错误码=$code, 描述=$desc, 详情=$detail")
            Log.e(TAG, "错误码说明: http://lbs.amap.com/api/android-navi-sdk/guide/tools/errorcode/")
            toast("路线规划失败[$code]：${desc ?: ""} ${detail ?: ""}")
        }

        override fun onArriveDestination() {
            toast("已到达目的地")
        }

        override fun onEndEmulatorNavi() {
            toast("模拟导航结束")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        naviView = AMapNaviView(this)
        naviView.onCreate(savedInstanceState)
        setContentView(naviView)

        // 自带 UI 的一些配置
        val options = AMapNaviViewOptions().apply {
            isAutoLockCar = true          // 自动锁车
            isTrafficLine = true          // 显示路况
        }
        naviView.viewOptions = options
        naviView.setAMapNaviViewListener(object : NaviViewListenerAdapter() {
            override fun onNaviCancel() {
                finish()
            }

            override fun onNaviBackClick(): Boolean {
                finish()
                return true
            }
        })

        try {
            aMapNavi = AMapNavi.getInstance(applicationContext)
            aMapNavi.addAMapNaviListener(naviListener)
            // 使用 SDK 内置语音播报
            aMapNavi.setUseInnerVoice(true, true)
        } catch (e: Exception) {
            toast("获取导航实例失败：${e.message}")
        }

        startJpgTcpSenderIfNeeded()
    }

    override fun onResume() {
        super.onResume()
        naviView.onResume()
    }

    override fun onPause() {
        super.onPause()
        naviView.onPause()
    }

    override fun onDestroy() {
        super.onDestroy()
        captureHandler.removeCallbacks(captureRunnable)
        jpgTcpSender?.stop()
        compressExecutor.shutdownNow()
        releaseScreenCapture()
        naviView.onDestroy()
        if (this::aMapNavi.isInitialized) {
            aMapNavi.stopNavi()
            aMapNavi.removeAMapNaviListener(naviListener)
        }
        AMapNavi.destroy()
    }

    private fun toast(msg: String) {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
    }

    private fun startJpgTcpSenderIfNeeded() {
        if (tcpHost.isBlank()) return
        addFpsTextView()
        jpgTcpSender = NaviJpgTcpSender(
            host = tcpHost,
            port = tcpPort,
            networkProvider = { com.example.map1.VehicleWifiManager.selectedNetwork },
            onStatus = { msg -> runOnUiThread { toast(msg) } },
            onFps = { fps, seq, bps ->
                lastActualSendFps = fps
                lastBytesPerSecond = bps
                updateFpsText(seq = seq)
            },
            onSendTiming = { _, _, sendMs ->
                captureWindowSendMs += sendMs
            },
        ).also { it.start() }

        captureWindowStartNs = System.nanoTime()
        requestScreenCapturePermission()
    }

    private fun addFpsTextView() {
        if (fpsTextView != null) return
        fpsTextView = TextView(this).apply {
            text = "TCP -- fps"
            setTextColor(Color.WHITE)
            setBackgroundColor(0x99000000.toInt())
            textSize = 14f
            setPadding(12, 6, 12, 6)
        }
        val params = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.TOP or Gravity.START,
        ).apply {
            setMargins(12, 48, 12, 12)
        }
        addContentView(fpsTextView, params)
    }

    private fun captureAndSendJpgFrame() {
        val screenBitmap = acquireScreenBitmap() ?: return

        compressAndSend(screenBitmap)
    }

    private fun compressAndSend(screenBitmap: Bitmap) {
        try {
            compressExecutor.execute {
                try {
                    val encodeStartedNs = System.nanoTime()
                    val jpeg = TurboJpegEncoder.encode(screenBitmap, JPG_QUALITY)
                        ?: ByteArrayOutputStream().use { stream ->
                            screenBitmap.compress(Bitmap.CompressFormat.JPEG, JPG_QUALITY, stream)
                            stream.toByteArray()
                        }
                    if (!screenBitmap.isRecycled) screenBitmap.recycle()

                    val encodeMs = (System.nanoTime() - encodeStartedNs) / 1_000_000L
                    val seq = nextSeq.getAndIncrement()
                    jpgTcpSender?.enqueue(seq, jpeg)
                    recordCaptureTiming(seq, encodeMs, jpeg.size)
                } catch (e: Exception) {
                    Log.e(TAG, "JPG 帧生成失败", e)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "提交 JPG 帧生成任务失败", e)
            if (!screenBitmap.isRecycled) screenBitmap.recycle()
        }
    }

    private fun requestScreenCapturePermission() {
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(
            mediaProjectionManager!!.createScreenCaptureIntent(),
            REQUEST_MEDIA_PROJECTION,
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_MEDIA_PROJECTION) return

        if (resultCode != RESULT_OK || data == null) {
            toast("未授权屏幕截图，JPG TCP 不发送")
            jpgTcpSender?.stop()
            return
        }

        releaseScreenCapture()
        mediaProjection = mediaProjectionManager?.getMediaProjection(resultCode, data)
        startScreenCapture()
        captureHandler.postDelayed(captureRunnable, 500)
    }

    private fun startScreenCapture() {
        val densityDpi = resources.displayMetrics.densityDpi
        imageReader = ImageReader.newInstance(CAPTURE_WIDTH, CAPTURE_HEIGHT, PixelFormat.RGBA_8888, 3)
        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "NaviJpgCapture",
            CAPTURE_WIDTH,
            CAPTURE_HEIGHT,
            densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null,
            null,
        )
        toast("已启用快速屏幕截图")
    }

    private fun releaseScreenCapture() {
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        mediaProjection?.stop()
        mediaProjection = null
    }

    private fun acquireScreenBitmap(): Bitmap? {
        val captureStartedNs = System.nanoTime()
        val image = try {
            imageReader?.acquireLatestImage()
        } catch (e: Exception) {
            Log.e(TAG, "读取屏幕图像失败", e)
            null
        } ?: return null

        return try {
            image.toBitmapTopCrop().also {
                captureWindowUiMs += (System.nanoTime() - captureStartedNs) / 1_000_000L
            }
        } finally {
            image.close()
        }
    }

    private fun Image.toBitmapTopCrop(): Bitmap {
        val plane = planes[0]
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val rowPadding = rowStride - pixelStride * width
        val rowWidth = width + rowPadding / pixelStride
        val padded = Bitmap.createBitmap(rowWidth, height, Bitmap.Config.ARGB_8888)
        padded.copyPixelsFromBuffer(plane.buffer)

        val source = if (rowWidth == width) {
            padded
        } else {
            Bitmap.createBitmap(padded, 0, 0, width, height).also { padded.recycle() }
        }

        return try {
            Bitmap.createBitmap(JPG_WIDTH, JPG_HEIGHT, Bitmap.Config.ARGB_8888).also { output ->
                val scale = maxOf(
                    JPG_WIDTH.toFloat() / source.width,
                    JPG_HEIGHT.toFloat() / source.height,
                )
                val scaledWidth = (source.width * scale).toInt()
                val scaledHeight = (source.height * scale).toInt()
                val left = (JPG_WIDTH - scaledWidth) / 2

                Canvas(output).drawBitmap(
                    source,
                    null,
                    Rect(left, 0, left + scaledWidth, scaledHeight),
                    null,
                )
            }
        } finally {
            source.recycle()
        }
    }

    private fun recordCaptureTiming(
        seq: Int,
        encodeMs: Long,
        bytes: Int,
    ) {
        captureWindowFrames += 1
        captureWindowEncodeMs += encodeMs

        val now = System.nanoTime()
        val elapsedNs = now - captureWindowStartNs
        if (elapsedNs >= 1_000_000_000L) {
            val elapsedSeconds = elapsedNs / 1_000_000_000.0
            val producedFps = captureWindowFrames / elapsedSeconds
            val frames = captureWindowFrames.coerceAtLeast(1)
            Log.d(
                TAG,
                "produce_fps=${"%.2f".format(producedFps)}, target_fps=$tcpFps, " +
                    "avg_ui_capture_ms=${captureWindowUiMs / frames}, " +
                    "avg_encode_ms=${captureWindowEncodeMs / frames}, " +
                    "avg_send_ms=${captureWindowSendMs / frames}, " +
                    "last_seq=$seq, last_jpg_bytes=$bytes",
            )
            updateFpsText(
                seq = seq,
                producedFps = producedFps,
                avgUiCaptureMs = captureWindowUiMs / frames,
                avgEncodeMs = captureWindowEncodeMs / frames,
                avgSendMs = captureWindowSendMs / frames,
                jpgBytes = bytes,
            )
            captureWindowStartNs = now
            captureWindowFrames = 0
            captureWindowUiMs = 0L
            captureWindowEncodeMs = 0L
            captureWindowSendMs = 0L
        }
    }

    private fun updateFpsText(
        seq: Int,
        producedFps: Double? = null,
        avgUiCaptureMs: Long? = null,
        avgEncodeMs: Long? = null,
        avgSendMs: Long? = null,
        jpgBytes: Int? = null,
    ) {
        runOnUiThread {
            val lines = mutableListOf(
                "target $tcpFps fps  send ${"%.1f".format(lastActualSendFps)} fps",
                "#$seq  ${lastBytesPerSecond / 1024} KB/s",
            )
            if (producedFps != null) {
                lines += "produce ${"%.1f".format(producedFps)} fps  jpg ${jpgBytes?.div(1024) ?: 0} KB"
            }
            if (avgUiCaptureMs != null && avgEncodeMs != null && avgSendMs != null) {
                lines += "screen ${avgUiCaptureMs}ms jpg ${avgEncodeMs}ms tcp ${avgSendMs}ms"
            }
            fpsTextView?.text = lines.joinToString("\n")
        }
    }

    companion object {
        private const val TAG = "NaviActivity"
        private const val CAPTURE_WIDTH = 720
        private const val CAPTURE_HEIGHT = 1280
        private const val JPG_WIDTH = 400
        private const val JPG_HEIGHT = 480
        private const val JPG_QUALITY = 60
        private const val DEFAULT_TCP_PORT = 5004
        private const val DEFAULT_TCP_FPS = 5
        private const val REQUEST_MEDIA_PROJECTION = 1001
        const val EXTRA_START_LAT = "extra_start_lat"
        const val EXTRA_START_LNG = "extra_start_lng"
        const val EXTRA_END_LAT = "extra_end_lat"
        const val EXTRA_END_LNG = "extra_end_lng"
        const val EXTRA_SPEED = "extra_speed"
        const val EXTRA_TCP_HOST = "extra_tcp_host"
        const val EXTRA_TCP_PORT = "extra_tcp_port"
        const val EXTRA_TCP_FPS = "extra_tcp_fps"
    }
}

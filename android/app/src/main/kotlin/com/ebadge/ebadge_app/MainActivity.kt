package com.ebadge.ebadge_app

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Hosts the native H.264 encoding-test pipeline ([CameraEncoder]) and bridges it
 * to Dart over a [MethodChannel] (commands) + [EventChannel] (camera-ready,
 * stats, lifecycle, errors).
 */
class MainActivity : FlutterActivity() {
    private val methodChannelName = "ebadge/encoder"
    private val eventChannelName = "ebadge/encoder/events"
    private val wifiChannelName = "ebadge/wifi"
    private val converterChannelName = "ebadge/converter"

    private var encoder: CameraEncoder? = null
    private var eventSink: EventChannel.EventSink? = null
    private var hotspot: HotspotManager? = null

    private val converter = VideoConverter()
    private var converterChannel: MethodChannel? = null
    private val converterExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var convertCancel: AtomicBoolean? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )

        val events = object : EncoderEvents {
            override fun onEvent(payload: Map<String, Any?>) {
                eventSink?.success(payload)
            }
        }

        MethodChannel(messenger, methodChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "openCamera" -> {
                    val front = call.argument<Boolean>("facingFront") ?: false
                    ensureEncoder(events).openCamera(front, parseConfig(call))
                    result.success(null)
                }

                "closeCamera" -> {
                    encoder?.closeCamera()
                    result.success(null)
                }

                "setConfig" -> {
                    encoder?.setConfig(parseConfig(call))
                    result.success(null)
                }

                "startEncoding" -> {
                    ensureEncoder(events).startEncoding(parseConfig(call))
                    result.success(null)
                }

                "stopEncoding" -> {
                    encoder?.stopEncoding()
                    result.success(null)
                }

                "focusAt" -> {
                    val x = call.argument<Double>("x") ?: 0.5
                    val y = call.argument<Double>("y") ?: 0.5
                    encoder?.focusAt(x, y)
                    result.success(null)
                }

                "setEv" -> {
                    val ev = call.argument<Double>("ev") ?: 0.0
                    encoder?.setEv(ev)
                    result.success(null)
                }

                "setZoom" -> {
                    val zoom = call.argument<Double>("zoom") ?: 1.0
                    encoder?.setZoom(zoom)
                    result.success(null)
                }

                "setPreviewMode" -> {
                    val encoded = call.argument<Boolean>("encoded") ?: false
                    encoder?.setPreviewMode(encoded)
                    result.success(null)
                }

                "requestKeyframe" -> {
                    encoder?.requestKeyframe()
                    result.success(null)
                }

                "requestEncoderFrame" -> {
                    encoder?.requestEncoderFrame()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, wifiChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "startHotspot" -> ensureHotspot().start(result)
                "stopHotspot" -> {
                    hotspot?.stop()
                    result.success(null)
                }
                "isHotspotActive" -> result.success(hotspot?.isActive ?: false)
                else -> result.notImplemented()
            }
        }

        val converterCh = MethodChannel(messenger, converterChannelName)
        converterChannel = converterCh
        converterCh.setMethodCallHandler { call, result ->
            when (call.method) {
                "getVideoThumbnail" -> handleThumbnail(call, result)
                "convertVideo" -> handleConvertVideo(call, result)
                "cancelConvert" -> {
                    convertCancel?.set(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun handleThumbnail(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("bad_args", "path required", null)
            return
        }
        converterExecutor.execute {
            try {
                val t = converter.thumbnail(path)
                mainHandler.post {
                    result.success(
                        mapOf(
                            "bytes" to t.png,
                            "width" to t.width,
                            "height" to t.height,
                            "isGif" to t.isGif,
                        ),
                    )
                }
            } catch (e: Exception) {
                mainHandler.post { result.error("thumb_failed", e.message ?: "读取视频失败", null) }
            }
        }
    }

    private fun handleConvertVideo(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("bad_args", "path required", null)
            return
        }
        val width = call.argument<Int>("width") ?: 360
        val height = call.argument<Int>("height") ?: 360
        val fps = call.argument<Int>("fps") ?: 10
        val quality = call.argument<Int>("quality") ?: 60
        val refine = call.argument<Int>("refine") ?: 3
        val strips = call.argument<Int>("strips") ?: 2
        val skipThresh = call.argument<Int>("skipThresh") ?: 720
        val keyint = call.argument<Int>("keyint") ?: 0
        val cropMode = call.argument<String>("cropMode") ?: "cover"
        val maxFrames = call.argument<Int>("maxFrames") ?: 300
        // bgColor arrives as an int64 (ARGB > 0x7FFFFFFF), so read via Number.
        val bgColor = (call.argument<Number>("bgColor"))?.toInt() ?: 0xFF000000.toInt()
        val cropMap = call.argument<Map<String, Any?>>("crop")
        val crop = if (cropMap != null) {
            doubleArrayOf(
                (cropMap["nx"] as? Number)?.toDouble() ?: 0.0,
                (cropMap["ny"] as? Number)?.toDouble() ?: 0.0,
                (cropMap["nw"] as? Number)?.toDouble() ?: 0.0,
                (cropMap["nh"] as? Number)?.toDouble() ?: 0.0,
            )
        } else {
            null
        }

        val cancel = AtomicBoolean(false)
        convertCancel = cancel
        val channel = converterChannel
        converterExecutor.execute {
            try {
                val res = converter.convert(
                    path, width, height, fps, quality, refine, strips, skipThresh, keyint,
                    cropMode, crop, maxFrames, bgColor, cancel,
                ) { done, total ->
                    mainHandler.post {
                        channel?.invokeMethod("onProgress", mapOf("done" to done, "total" to total))
                    }
                }
                mainHandler.post {
                    result.success(
                        mapOf(
                            "avi" to res.avi,
                            "width" to res.width,
                            "height" to res.height,
                            "frameCount" to res.frameCount,
                            "fps" to res.fps,
                        ),
                    )
                }
            } catch (e: VideoConverter.Cancelled) {
                mainHandler.post { result.error("cancelled", "已取消", null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("convert_failed", e.message ?: "视频转换失败", null) }
            }
        }
    }

    private fun ensureHotspot(): HotspotManager {
        val existing = hotspot
        if (existing != null) return existing
        val created = HotspotManager(applicationContext)
        hotspot = created
        return created
    }

    private fun parseConfig(call: MethodCall): EncoderConfig = EncoderConfig(
        format = call.argument<String>("format") ?: "h264",
        width = call.argument<Int>("width") ?: 640,
        height = call.argument<Int>("height") ?: 480,
        fps = call.argument<Int>("fps") ?: 15,
        bitrate = call.argument<Int>("bitrate") ?: 2_000_000,
        iFrameIntervalSec = call.argument<Int>("iFrameIntervalSec") ?: 1,
        cropZoom = call.argument<Double>("cropZoom") ?: 1.0,
        msv1Skip = call.argument<Boolean>("msv1Skip") ?: true,
        msv1SkipThr = call.argument<Int>("msv1SkipThr") ?: 0,
        jpegQuality = call.argument<Int>("jpegQuality") ?: 80,
        recordToFile = call.argument<Boolean>("recordToFile") ?: false,
        stream = call.argument<Boolean>("stream") ?: false,
    )

    private fun ensureEncoder(events: EncoderEvents): CameraEncoder {
        val existing = encoder
        if (existing != null) return existing
        val created = CameraEncoder(applicationContext, flutterEngine!!.renderer, events)
        encoder = created
        return created
    }

    override fun onDestroy() {
        encoder?.closeCamera()
        encoder = null
        hotspot?.stop()
        hotspot = null
        convertCancel?.set(true)
        converterChannel = null
        converterExecutor.shutdownNow()
        super.onDestroy()
    }
}

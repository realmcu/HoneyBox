package com.ebadge.ebadge_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the native H.264 encoding-test pipeline ([CameraEncoder]) and bridges it
 * to Dart over a [MethodChannel] (commands) + [EventChannel] (camera-ready,
 * stats, lifecycle, errors).
 */
class MainActivity : FlutterActivity() {
    private val methodChannelName = "ebadge/encoder"
    private val eventChannelName = "ebadge/encoder/events"
    private val wifiChannelName = "ebadge/wifi"

    private var encoder: CameraEncoder? = null
    private var eventSink: EventChannel.EventSink? = null
    private var hotspot: HotspotManager? = null

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
        super.onDestroy()
    }
}

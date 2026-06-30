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

    private var encoder: CameraEncoder? = null
    private var eventSink: EventChannel.EventSink? = null

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

                else -> result.notImplemented()
            }
        }
    }

    private fun parseConfig(call: MethodCall): EncoderConfig = EncoderConfig(
        format = call.argument<String>("format") ?: "h264",
        width = call.argument<Int>("width") ?: 640,
        height = call.argument<Int>("height") ?: 480,
        fps = call.argument<Int>("fps") ?: 15,
        bitrate = call.argument<Int>("bitrate") ?: 2_000_000,
        iFrameIntervalSec = call.argument<Int>("iFrameIntervalSec") ?: 1,
        cropZoom = call.argument<Double>("cropZoom") ?: 1.0,
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
        super.onDestroy()
    }
}

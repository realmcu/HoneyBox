package com.honeygui.honeybox

import android.app.Notification
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Android [NotificationListenerService] that captures posted notifications and
 * forwards them to the Flutter side over an [EventChannel].
 *
 * The service is declared in AndroidManifest.xml with the
 * [android.permission.BIND_NOTIFICATION_LISTENER_SERVICE] permission.
 *
 * Communication with Dart:
 *   - MethodChannel "honeybox/notification_listener" for commands
 *     (openNotificationSettings, isListenerEnabled)
 *   - EventChannel "honeybox/notification_events" for notification data
 */
class NotificationListener : NotificationListenerService() {
    companion object {
        private const val TAG = "NotificationListener"

        // Method channel (set up once from MainActivity).
        private var methodChannel: MethodChannel? = null

        // Event sink for forwarding notifications to Dart.
        private var eventSink: EventChannel.EventSink? = null

        /// Called from [MainActivity.configureFlutterEngine] to register
        /// the channels used by the notification service.
        fun registerChannels(flutterEngine: FlutterEngine) {
            val messenger = flutterEngine.dartExecutor.binaryMessenger

            methodChannel = MethodChannel(messenger, "honeybox/notification_listener").also { ch ->
                ch.setMethodCallHandler { call, result ->
                    val service = NotificationListener()
                    when (call.method) {
                        "openNotificationSettings" -> {
                            service.openNotificationSettings()
                            result.success(true)
                        }
                        "isListenerEnabled" -> {
                            result.success(service.isListenerEnabled())
                        }
                        else -> result.notImplemented()
                    }
                }
            }

            EventChannel(messenger, "honeybox/notification_events").setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                        eventSink = sink
                    }

                    override fun onCancel(arguments: Any?) {
                        eventSink = null
                    }
                }
            )
        }

        /// Send a captured notification to the Dart side.
        fun sendNotificationEvent(appName: String, title: String, message: String) {
            eventSink?.success(
                mapOf(
                    "appName" to (appName.ifEmpty { "未知应用" }),
                    "title" to title,
                    "message" to message,
                    "timestamp" to System.currentTimeMillis(),
                )
            )
        }

        /// Check whether this service has been granted notification listener
        /// access by the user.
        private fun isServiceEnabled(): Boolean {
            val cn = android.content.ComponentName(
                "com.honeygui.honeybox",
                "com.honeygui.honeybox.NotificationListener"
            )
            val flat =
                android.provider.Settings.Secure.getString(
                    androidAppContext?.contentResolver,
                    "enabled_notification_listeners"
                ) ?: ""
            return flat.contains(cn.flattenToString())
        }

        // HACK: Application context for reading settings (method channel has
        // no context). Set once from registerChannels or a static init.
        private var androidAppContext: android.content.Context? = null
    }

    init {
        androidAppContext = applicationContext
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "NotificationListener service created")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!compatIsServiceEnabled()) return
        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        // Extract app name, title, and text from the notification extras.
        val appName = sbn.packageName  // Will be mapped to a friendly name on the Dart side.
        val title = extras.getString(Notification.EXTRA_TITLE, "") ?: ""
        val text = extras.getString(Notification.EXTRA_TEXT, "") ?: ""

        if (title.isEmpty() && text.isEmpty()) return  // Skip content-free ticks

        Log.d(TAG, "Notification: $appName / $title")
        sendNotificationEvent(appName, title, text)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // Can be used to notify Dart about notification dismissal (future use).
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Notification listener connected")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "Notification listener disconnected")
    }

    /// Open the system's notification listener settings page.
    private fun openNotificationSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            val intent = android.content.Intent(
                android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS
            ).apply {
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        }
    }

    /// Check whether this notification listener is enabled in system settings.
    private fun isListenerEnabled(): Boolean = compatIsServiceEnabled()

    private fun compatIsServiceEnabled(): Boolean {
        return try {
            isServiceEnabled()
        } catch (e: Exception) {
            false  // Best-effort; the permission banner will guide the user.
        }
    }
}

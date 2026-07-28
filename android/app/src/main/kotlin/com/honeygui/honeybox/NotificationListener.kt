package com.honeygui.honeybox

import android.app.Notification
import android.os.Build
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

        // Event sink for forwarding notifications to Dart.
        private var eventSink: EventChannel.EventSink? = null

        // Application context obtained from FlutterEngine (not the service instance).
        private var appContext: android.content.Context? = null

        /// Called from [MainActivity.configureFlutterEngine] to register
        /// the channels used by the notification service.
        fun registerChannels(flutterEngine: FlutterEngine) {
            appContext = flutterEngine.androidContext
            val messenger = flutterEngine.dartExecutor.binaryMessenger

            MethodChannel(messenger, "honeybox/notification_listener").setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationSettings" -> {
                        openNotificationSettingsInternal()
                        result.success(true)
                    }
                    "isListenerEnabled" -> {
                        result.success(isListenerEnabledInternal())
                    }
                    else -> result.notImplemented()
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

        /// Open the system's notification listener settings page.
        private fun openNotificationSettingsInternal() {
            val ctx = appContext ?: return
            val intent = android.content.Intent(
                android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS
            ).apply {
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            ctx.startActivity(intent)
        }

        /// Check whether this notification listener is enabled in system settings.
        private fun isListenerEnabledInternal(): Boolean {
            val cn = android.content.ComponentName(
                "com.honeygui.honeybox",
                "com.honeygui.honeybox.NotificationListener"
            )
            return try {
                val flat = android.provider.Settings.Secure.getString(
                    appContext?.contentResolver,
                    "enabled_notification_listeners"
                ) ?: ""
                flat.contains(cn.flattenToString())
            } catch (e: Exception) {
                false
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "NotificationListener service created")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!isListenerEnabledInternal()) return
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
}

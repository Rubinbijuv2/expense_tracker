package com.rubin.expense_tracker

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Payment app notifications (PLAN.md section 7), off by default.
 *
 * Android calls [onNotificationPosted] for EVERY notification once the user
 * gives "Notification access". We look only at the package name first and
 * return straight away for any app not in [ALLOWED_PACKAGES], so their text
 * is never read, sent to Dart, logged or stored. We also drop everything
 * while the Settings switch is off.
 *
 * Allowed notifications go to Dart:
 *  - app running → through the EventChannel ([liveSink], set by MainActivity);
 *  - app closed  → a hidden Flutter engine runs `paymentNotificationMain`
 *    (lib/main.dart), which runs the same pipeline and shows our notification.
 */
class PaymentNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "PaymentNotifications"
        private const val PREFS = "payment_notifications"
        private const val KEY_ENABLED = "enabled"
        private const val BG_CHANNEL = "expense_tracker/notification_background"
        private const val BG_ENTRYPOINT = "paymentNotificationMain"
        private const val MAX_WAITING = 20

        /** PLAN.md 7.3 — keep in sync with NotificationParser.allowedApps. */
        val ALLOWED_PACKAGES = setOf(
            "com.google.android.apps.nbu.paisa.user", // Google Pay
            "com.phonepe.app",                        // PhonePe
            "net.one97.paytm",                        // Paytm
            "in.org.npci.upiapp",                     // BHIM
            "com.dreamplug.androidapp",               // CRED
            "in.amazon.mShop.android.shopping",       // Amazon (Amazon Pay)
        )

        /** Set by MainActivity while the app's Dart code is listening. */
        @Volatile
        var liveSink: EventChannel.EventSink? = null

        fun isEnabled(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean(KEY_ENABLED, false)

        fun setEnabled(context: Context, on: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY_ENABLED, on).apply()
            if (on) {
                // Ask Android to connect the service again, in case it was
                // disconnected while access was off.
                try {
                    requestRebind(ComponentName(context, PaymentNotificationListener::class.java))
                } catch (e: Exception) {
                    Log.w(TAG, "requestRebind failed: $e")
                }
            }
        }

        /** True if this app is ticked on Android's Notification access page. */
        fun hasAccess(context: Context): Boolean {
            val enabled = Settings.Secure.getString(
                context.contentResolver, "enabled_notification_listeners"
            ) ?: return false
            val me = ComponentName(context, PaymentNotificationListener::class.java)
            return enabled.split(":").any {
                ComponentName.unflattenFromString(it) == me
            }
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var bgEngine: FlutterEngine? = null
    private var bgChannel: MethodChannel? = null
    private var bgReady = false
    private val waiting = ArrayDeque<Map<String, Any?>>()

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        // 1. Allow-list first: other apps are ignored completely.
        if (sbn.packageName !in ALLOWED_PACKAGES) return
        // 2. The Settings switch.
        if (!isEnabled(this)) return

        val n = sbn.notification ?: return
        // Group summaries ("3 new messages") repeat the real notifications.
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val extras = n.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        if (title.isBlank() && text.isBlank() && bigText.isNullOrBlank()) return

        val event = mapOf(
            "package" to sbn.packageName,
            "title" to title,
            "text" to text,
            "bigText" to bigText,
            "postedAt" to sbn.postTime,
        )
        // Flutter channels must be used from the main thread.
        mainHandler.post { deliver(event) }
    }

    private fun deliver(event: Map<String, Any?>) {
        val sink = liveSink
        if (sink != null) {
            sink.success(event)
            return
        }
        // App is closed: hand it to the hidden engine (start it if needed).
        if (bgReady) {
            bgChannel?.invokeMethod("onNotification", event)
        } else {
            if (waiting.size >= MAX_WAITING) waiting.removeFirst()
            waiting.addLast(event)
            startBackgroundEngine()
        }
    }

    private fun startBackgroundEngine() {
        if (bgEngine != null) return
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)

            // FlutterEngine registers all plugins (database, notifications)
            // automatically, like the main app does.
            val engine = FlutterEngine(applicationContext)
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, BG_CHANNEL)
            channel.setMethodCallHandler { call, result ->
                if (call.method == "ready") {
                    bgReady = true
                    result.success(null)
                    while (waiting.isNotEmpty()) {
                        channel.invokeMethod("onNotification", waiting.removeFirst())
                    }
                } else {
                    result.notImplemented()
                }
            }
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), BG_ENTRYPOINT)
            )
            bgEngine = engine
            bgChannel = channel
        } catch (e: Exception) {
            Log.e(TAG, "Could not start background engine: $e")
        }
    }

    private fun stopBackgroundEngine() {
        bgChannel?.setMethodCallHandler(null)
        bgEngine?.destroy()
        bgEngine = null
        bgChannel = null
        bgReady = false
        waiting.clear()
    }

    override fun onListenerDisconnected() {
        stopBackgroundEngine()
        super.onListenerDisconnected()
    }

    override fun onDestroy() {
        stopBackgroundEngine()
        super.onDestroy()
    }
}

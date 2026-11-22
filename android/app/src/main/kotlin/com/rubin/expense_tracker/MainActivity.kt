package com.rubin.expense_tracker

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.ComponentName
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (instead of FlutterActivity) is required by
// local_auth to show Android's fingerprint popup.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "Call organiser" (chitti): Dart's DialerService calls "dial".
        // ACTION_DIAL only opens the dialer with the number filled in; the
        // user presses call, so no CALL_PHONE permission is needed.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "expense_tracker/dialer")
            .setMethodCallHandler { call, result ->
                if (call.method != "dial") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val phone = call.argument<String>("phone").orEmpty()
                val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + Uri.encode(phone)))
                try {
                    startActivity(intent)
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    result.success(false)
                }
            }

        // Payment app notifications (PLAN.md section 7): the Settings switch
        // and Android's Notification access page. Dart: PaymentNotificationService.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "expense_tracker/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAccess" -> result.success(PaymentNotificationListener.hasAccess(this))
                    "isEnabled" -> result.success(PaymentNotificationListener.isEnabled(this))
                    "setEnabled" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        PaymentNotificationListener.setEnabled(this, on)
                        result.success(true)
                    }
                    "openAccessSettings" -> result.success(openNotificationAccess())
                    else -> result.notImplemented()
                }
            }

        // Allowed payment notifications while the app is running.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "expense_tracker/notification_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    PaymentNotificationListener.liveSink = events
                }

                override fun onCancel(arguments: Any?) {
                    PaymentNotificationListener.liveSink = null
                }
            })
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // The app is closing: from now on the service uses its hidden engine.
        PaymentNotificationListener.liveSink = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /** Android 11+ can open this app's own switch directly; older phones get the list. */
    private fun openNotificationAccess(): Boolean {
        val me = ComponentName(this, PaymentNotificationListener::class.java)
        val intents = mutableListOf<Intent>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            intents.add(
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                    .putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, me.flattenToString())
            )
        }
        intents.add(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        for (intent in intents) {
            try {
                startActivity(intent)
                return true
            } catch (e: ActivityNotFoundException) {
                // try the next one
            }
        }
        return false
    }
}

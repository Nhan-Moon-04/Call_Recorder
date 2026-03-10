package com.zalocall.zalo_call_recorder

import android.app.ActivityManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.zalocall.zalo_call_recorder/call_service"
    private val EVENT_CHANNEL = "com.zalocall.zalo_call_recorder/call_events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Auto-start call detection service
        CallDetectionService.start(this)
        Log.d("MainActivity", "Auto-started CallDetectionService")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startCallDetection" -> {
                    startCallDetectionService()
                    result.success(null)
                }
                "stopCallDetection" -> {
                    stopCallDetectionService()
                    result.success(null)
                }
                "showBubble" -> {
                    val source = call.argument<String>("source") ?: "Unknown"
                    val autoRecord = call.argument<Boolean>("autoRecord") ?: false
                    showBubble(source, autoRecord)
                    result.success(null)
                }
                "hideBubble" -> {
                    hideBubble()
                    result.success(null)
                }
                "hasOverlayPermission" -> {
                    result.success(hasOverlayPermission())
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(null)
                }
                "isAccessibilityServiceEnabled" -> {
                    result.success(isNotificationListenerEnabled())
                }
                "openAccessibilitySettings" -> {
                    openNotificationListenerSettings()
                    result.success(null)
                }
                "startScreenRecording" -> {
                    // Screen recording requires MediaProjection API
                    result.success(null)
                }
                "stopScreenRecording" -> {
                    result.success(null)
                }
                "isServiceRunning" -> {
                    result.success(isServiceRunning(CallDetectionService::class.java))
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    CallEventHandler.eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    CallEventHandler.eventSink = null
                }
            }
        )
    }

    private fun startCallDetectionService() {
        val intent = Intent(this, CallDetectionService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopCallDetectionService() {
        val intent = Intent(this, CallDetectionService::class.java)
        stopService(intent)
    }

    private fun showBubble(source: String, autoRecord: Boolean) {
        val intent = Intent(this, BubbleService::class.java).apply {
            putExtra("source", source)
            putExtra("autoRecord", autoRecord)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun hideBubble() {
        val intent = Intent(this, BubbleService::class.java)
        stopService(intent)
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        val componentName = ComponentName(this, CallNotificationListenerService::class.java)
        return flat.contains(componentName.flattenToString())
    }

    private fun openNotificationListenerSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        startActivity(intent)
    }

    @Suppress("DEPRECATION")
    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        for (service in manager.getRunningServices(Int.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }
}

// Singleton to share event sink between services and Flutter
object CallEventHandler {
    var eventSink: EventChannel.EventSink? = null

    fun sendCallEvent(eventType: String, source: String, phoneNumber: String? = null) {
        eventSink?.success(mapOf(
            "eventType" to eventType,
            "source" to source,
            "phoneNumber" to (phoneNumber ?: ""),
            "timestamp" to System.currentTimeMillis()
        ))
    }
}


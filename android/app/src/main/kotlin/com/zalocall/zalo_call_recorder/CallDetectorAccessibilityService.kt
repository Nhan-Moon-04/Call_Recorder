package com.zalocall.zalo_call_recorder

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Build
import android.view.accessibility.AccessibilityEvent

class CallDetectorAccessibilityService : AccessibilityService() {

    // Package names of apps to monitor
    private val monitoredPackages = mapOf(
        "com.zing.zalo" to "Zalo",
        "com.whatsapp" to "WhatsApp",
        "org.telegram.messenger" to "Telegram",
        "com.viber.voip" to "Viber",
        "com.facebook.orca" to "Messenger"
    )

    // Track call state per app
    private val activeCallApps = mutableSetOf<String>()

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: return
        val appName = monitoredPackages[packageName] ?: return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                val className = event.className?.toString() ?: ""
                
                // Detect call screens based on class names
                if (isCallScreen(className, packageName)) {
                    if (!activeCallApps.contains(packageName)) {
                        activeCallApps.add(packageName)
                        onCallDetected(appName, packageName)
                    }
                } else if (activeCallApps.contains(packageName)) {
                    // Call might have ended
                    activeCallApps.remove(packageName)
                    onCallEnded(appName, packageName)
                }
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                // Additional call detection through content changes
                if (activeCallApps.contains(packageName)) {
                    val text = event.text?.joinToString(" ") ?: ""
                    if (isCallEndedText(text)) {
                        activeCallApps.remove(packageName)
                        onCallEnded(appName, packageName)
                    }
                }
            }
        }
    }

    private fun isCallScreen(className: String, packageName: String): Boolean {
        val callIndicators = listOf(
            "call", "voip", "incall", "ongoing", "calling",
            "videocall", "video_call", "audiocall", "audio_call"
        )
        val lowerClassName = className.lowercase()
        return callIndicators.any { lowerClassName.contains(it) }
    }

    private fun isCallEndedText(text: String): Boolean {
        val endIndicators = listOf(
            "call ended", "cuộc gọi đã kết thúc",
            "call declined", "gọi nhỡ",
            "no answer", "không trả lời"
        )
        val lowerText = text.lowercase()
        return endIndicators.any { lowerText.contains(it) }
    }

    private fun onCallDetected(appName: String, packageName: String) {
        // Notify Flutter about the incoming call
        CallEventHandler.sendCallEvent("incoming", appName)

        // Show floating bubble
        val intent = Intent(this, BubbleService::class.java).apply {
            putExtra("source", appName)
            putExtra("autoRecord", false)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun onCallEnded(appName: String, packageName: String) {
        // Notify Flutter that the call ended
        CallEventHandler.sendCallEvent("ended", appName)

        // Hide bubble
        val intent = Intent(this, BubbleService::class.java)
        stopService(intent)
    }

    override fun onInterrupt() {
        activeCallApps.clear()
    }

    override fun onServiceConnected() {
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 100
            packageNames = monitoredPackages.keys.toTypedArray()
        }
        serviceInfo = info
    }
}

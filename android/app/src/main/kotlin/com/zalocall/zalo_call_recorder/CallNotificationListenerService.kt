package com.zalocall.zalo_call_recorder

import android.app.Notification
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class CallNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "CallNotifListener"
    }

    // Package names of apps to monitor for calls
    private val monitoredPackages = mapOf(
        "com.zing.zalo" to "Zalo",
        "com.whatsapp" to "WhatsApp",
        "org.telegram.messenger" to "Telegram",
        "com.viber.voip" to "Viber",
        "com.facebook.orca" to "Messenger"
    )

    // Track active call notifications
    private val activeCallNotifications = mutableSetOf<String>()

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        val appName = monitoredPackages[packageName] ?: return

        val notification = sbn.notification ?: return
        val extras = notification.extras

        // Check if this is a call notification
        // Call notifications use CATEGORY_CALL or have ongoing/fullscreen intent
        val isCallNotification = isCallRelatedNotification(notification, extras, packageName)

        if (isCallNotification && !activeCallNotifications.contains(packageName)) {
            activeCallNotifications.add(packageName)
            Log.d(TAG, "Call detected from $appName ($packageName)")
            onCallDetected(appName, packageName)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        val appName = monitoredPackages[packageName] ?: return

        if (activeCallNotifications.contains(packageName)) {
            activeCallNotifications.remove(packageName)
            Log.d(TAG, "Call ended from $appName ($packageName)")
            onCallEnded(appName, packageName)
        }
    }

    private fun isCallRelatedNotification(
        notification: Notification,
        extras: android.os.Bundle?,
        packageName: String
    ): Boolean {
        // Method 1: Check notification category
        if (notification.category == Notification.CATEGORY_CALL) {
            return true
        }

        // Method 2: Check for full-screen intent (incoming call screens)
        if (notification.fullScreenIntent != null) {
            return true
        }

        // Method 3: Check if notification is ongoing and from a monitored app
        val isOngoing = (notification.flags and Notification.FLAG_ONGOING_EVENT) != 0
        if (isOngoing) {
            val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.lowercase() ?: ""
            val text = extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.lowercase() ?: ""
            val combined = "$title $text"
            
            val callKeywords = listOf(
                "calling", "incoming call", "ongoing call", "video call", "voice call",
                "cuộc gọi", "đang gọi", "gọi đến", "gọi video", "cuộc gọi thoại",
                "ringing", "đổ chuông",
                "appel", "llamada", // French/Spanish
            )
            
            if (callKeywords.any { combined.contains(it) }) {
                return true
            }
        }

        // Method 4: Check notification channel for call-related channels
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = notification.channelId?.lowercase() ?: ""
            if (channelId.contains("call") || channelId.contains("voip")) {
                return true
            }
        }

        return false
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
}

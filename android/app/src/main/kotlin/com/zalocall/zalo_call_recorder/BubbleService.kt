package com.zalocall.zalo_call_recorder

import android.app.*
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

class BubbleService : Service() {
    private var windowManager: WindowManager? = null
    private var bubbleView: View? = null
    private var expandedView: View? = null
    private var isExpanded = false
    private var source = "Unknown"
    private var autoRecord = false
    private var isRecording = false

    companion object {
        const val CHANNEL_ID = "bubble_service_channel"
        const val NOTIFICATION_ID = 1001
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        source = intent?.getStringExtra("source") ?: "Unknown"
        autoRecord = intent?.getBooleanExtra("autoRecord", false) ?: false

        startForeground(NOTIFICATION_ID, createNotification())
        showBubble()

        if (autoRecord) {
            CallEventHandler.sendCallEvent("autoRecordStart", source)
        }

        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Call Recording Bubble",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows recording bubble overlay"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Call Recorder")
            .setContentText("Recording bubble active - $source")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun showBubble() {
        if (bubbleView != null) return

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 200
        }

        // Create bubble programmatically
        bubbleView = createBubbleView()
        
        bubbleView?.let { view ->
            setupTouchListener(view, params)
            windowManager?.addView(view, params)
        }
    }

    private fun createBubbleView(): View {
        val context = this

        // Main container
        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(8, 8, 8, 8)
        }

        // Bubble circle (collapsed state)
        val bubbleCircle = ImageView(context).apply {
            setImageResource(android.R.drawable.ic_btn_speak_now)
            val size = (56 * resources.displayMetrics.density).toInt()
            layoutParams = LinearLayout.LayoutParams(size, size)
            setBackgroundResource(android.R.drawable.dialog_holo_light_frame)
            setPadding(12, 12, 12, 12)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            tag = "bubble_icon"
        }
        container.addView(bubbleCircle)

        // Expanded panel
        val expandedPanel = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(16, 16, 16, 16)
            setBackgroundResource(android.R.drawable.dialog_holo_light_frame)
            visibility = View.GONE
            tag = "expanded_panel"
        }

        // Title
        val title = TextView(context).apply {
            text = "📞 $source Call"
            textSize = 16f
            setPadding(0, 0, 0, 12)
        }
        expandedPanel.addView(title)

        // Record Audio Button
        val recordAudioBtn = TextView(context).apply {
            text = "🎙️ Record Audio"
            textSize = 14f
            setPadding(16, 12, 16, 12)
            setBackgroundResource(android.R.drawable.btn_default)
            tag = "record_audio_btn"
            setOnClickListener {
                if (!isRecording) {
                    val intent = Intent(CallDetectionService.ACTION_START_RECORDING).apply {
                        setPackage(packageName)
                        putExtra("source", source)
                    }
                    sendBroadcast(intent)
                    isRecording = true
                    text = "⏹️ Stop Recording"
                } else {
                    val intent = Intent(CallDetectionService.ACTION_STOP_RECORDING).apply {
                        setPackage(packageName)
                    }
                    sendBroadcast(intent)
                    isRecording = false
                    text = "🎙️ Record Audio"
                }
                collapseBubble()
            }
        }
        expandedPanel.addView(recordAudioBtn)

        // Record Video Button
        val recordVideoBtn = TextView(context).apply {
            text = "📹 Record Video"
            textSize = 14f
            setPadding(16, 12, 16, 12)
            setBackgroundResource(android.R.drawable.btn_default)
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            params.topMargin = 8
            layoutParams = params
            setOnClickListener {
                CallEventHandler.sendCallEvent("recordVideo", source)
                collapseBubble()
            }
        }
        expandedPanel.addView(recordVideoBtn)

        // Dismiss Button
        val dismissBtn = TextView(context).apply {
            text = "✖ Dismiss"
            textSize = 14f
            setPadding(16, 12, 16, 12)
            setBackgroundResource(android.R.drawable.btn_default)
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            params.topMargin = 8
            layoutParams = params
            setOnClickListener {
                stopSelf()
            }
        }
        expandedPanel.addView(dismissBtn)

        container.addView(expandedPanel)

        // Click on bubble to expand
        bubbleCircle.setOnClickListener {
            if (isExpanded) {
                collapseBubble()
            } else {
                expandBubble()
            }
        }

        return container
    }

    private fun expandBubble() {
        isExpanded = true
        bubbleView?.findViewWithTag<View>("expanded_panel")?.visibility = View.VISIBLE
    }

    private fun collapseBubble() {
        isExpanded = false
        bubbleView?.findViewWithTag<View>("expanded_panel")?.visibility = View.GONE
    }

    private fun setupTouchListener(view: View, params: WindowManager.LayoutParams) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f

        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    false
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX + (event.rawX - initialTouchX).toInt()
                    params.y = initialY + (event.rawY - initialTouchY).toInt()
                    windowManager?.updateViewLayout(view, params)
                    true
                }
                else -> false
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        bubbleView?.let {
            windowManager?.removeView(it)
            bubbleView = null
        }
    }
}

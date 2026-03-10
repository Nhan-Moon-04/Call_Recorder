package com.zalocall.zalo_call_recorder

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.MediaRecorder
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.provider.Settings
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class CallDetectionService : Service() {
    private var telephonyManager: TelephonyManager? = null
    private var phoneStateListener: PhoneStateListener? = null
    private var lastState = TelephonyManager.CALL_STATE_IDLE
    private var mediaRecorder: MediaRecorder? = null
    private var isRecording = false
    private var currentRecordingPath: String? = null
    private var recordingStartTime: Long = 0

    companion object {
        const val CHANNEL_ID = "call_detection_channel"
        const val NOTIFICATION_ID = 1002
        const val TAG = "CallDetectionSvc"
        const val ACTION_START_RECORDING = "com.zalocall.START_RECORDING"
        const val ACTION_STOP_RECORDING = "com.zalocall.STOP_RECORDING"

        fun start(context: Context) {
            val intent = Intent(context, CallDetectionService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, CallDetectionService::class.java)
            context.stopService(intent)
        }

        fun getRecordingDir(): File {
            val dateFormat = SimpleDateFormat("yyyy-MM", Locale.getDefault())
            val monthFolder = dateFormat.format(Date())
            val dayFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val dayFolder = dayFormat.format(Date())

            val baseDir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS),
                "CallRecorder"
            )
            val dir = File(baseDir, "$monthFolder/$dayFolder")
            if (!dir.exists()) {
                dir.mkdirs()
            }
            return dir
        }
    }

    private val recordingReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_START_RECORDING -> {
                    val source = intent.getStringExtra("source") ?: "Unknown"
                    startRecording(source)
                }
                ACTION_STOP_RECORDING -> {
                    stopRecording()
                }
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification("Monitoring calls..."))
        startListening()
        registerRecordingReceiver()
        Log.d(TAG, "CallDetectionService started")
    }

    @Suppress("UnspecifiedRegisterReceiverFlag")
    private fun registerRecordingReceiver() {
        val filter = IntentFilter().apply {
            addAction(ACTION_START_RECORDING)
            addAction(ACTION_STOP_RECORDING)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(recordingReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(recordingReceiver, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Call Detection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors incoming and outgoing calls"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(text: String): Notification {
        val notificationIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Call Recorder")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun updateNotification(text: String) {
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, createNotification(text))
    }

    @Suppress("DEPRECATION")
    private fun startListening() {
        telephonyManager = getSystemService(TELEPHONY_SERVICE) as TelephonyManager

        phoneStateListener = object : PhoneStateListener() {
            override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                if (state == lastState) return
                lastState = state

                when (state) {
                    TelephonyManager.CALL_STATE_RINGING -> {
                        Log.d(TAG, "Incoming call from: $phoneNumber")
                        CallEventHandler.sendCallEvent("incoming", "SIM", phoneNumber)
                        showBubble("SIM")
                    }
                    TelephonyManager.CALL_STATE_OFFHOOK -> {
                        Log.d(TAG, "Call answered/outgoing")
                        CallEventHandler.sendCallEvent("answered", "SIM", phoneNumber)
                        showBubble("SIM")
                        // Auto-start recording when call is answered
                        startRecording("SIM")
                    }
                    TelephonyManager.CALL_STATE_IDLE -> {
                        Log.d(TAG, "Call ended")
                        CallEventHandler.sendCallEvent("ended", "SIM", phoneNumber)
                        // Auto-stop recording when call ends
                        stopRecording()
                        hideBubble()
                    }
                }
            }
        }

        telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
    }

    fun startRecording(source: String) {
        if (isRecording) {
            Log.d(TAG, "Already recording, skipping")
            return
        }

        try {
            val dir = getRecordingDir()
            val timeFormat = SimpleDateFormat("HHmmss", Locale.getDefault())
            val timestamp = timeFormat.format(Date())
            val fileName = "${source}_$timestamp.m4a"
            val filePath = File(dir, fileName).absolutePath
            currentRecordingPath = filePath

            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            mediaRecorder?.apply {
                setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setAudioEncodingBitRate(128000)
                setOutputFile(filePath)
                prepare()
                start()
            }

            isRecording = true
            recordingStartTime = System.currentTimeMillis()
            updateNotification("🔴 Recording ($source)...")
            Log.d(TAG, "Recording started: $filePath")

            CallEventHandler.sendCallEvent("recordingStarted", source)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording: ${e.message}", e)
            cleanupRecorder()
        }
    }

    fun stopRecording() {
        if (!isRecording) return

        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null
            isRecording = false

            val duration = (System.currentTimeMillis() - recordingStartTime) / 1000
            Log.d(TAG, "Recording stopped: $currentRecordingPath (duration: ${duration}s)")
            updateNotification("Monitoring calls...")

            CallEventHandler.sendCallEvent("recordingStopped", "SIM", null)

            // Notify Flutter about saved file
            currentRecordingPath?.let { path ->
                CallEventHandler.eventSink?.success(mapOf(
                    "eventType" to "recordingSaved",
                    "filePath" to path,
                    "duration" to duration,
                    "timestamp" to System.currentTimeMillis()
                ))
            }

            currentRecordingPath = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop recording: ${e.message}", e)
            cleanupRecorder()
        }
    }

    private fun cleanupRecorder() {
        try {
            mediaRecorder?.release()
        } catch (_: Exception) {}
        mediaRecorder = null
        isRecording = false
        currentRecordingPath = null
    }

    private fun showBubble(source: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Log.w(TAG, "No overlay permission, cannot show bubble")
            return
        }

        try {
            val intent = Intent(this, BubbleService::class.java).apply {
                putExtra("source", source)
                putExtra("autoRecord", true)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            Log.d(TAG, "Bubble shown for source: $source")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show bubble: ${e.message}")
        }
    }

    private fun hideBubble() {
        try {
            val intent = Intent(this, BubbleService::class.java)
            stopService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to hide bubble: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopRecording()
        telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)
        try {
            unregisterReceiver(recordingReceiver)
        } catch (_: Exception) {}
        Log.d(TAG, "CallDetectionService stopped")
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "Task removed, scheduling restart")
        val restartIntent = Intent(applicationContext, CallDetectionService::class.java)
        val pendingIntent = PendingIntent.getService(
            applicationContext, 1, restartIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.set(
            AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis() + 1000,
            pendingIntent
        )
        super.onTaskRemoved(rootIntent)
    }
}

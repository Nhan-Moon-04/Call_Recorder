package com.zalocall.zalo_call_recorder

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.provider.Settings
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.text.SimpleDateFormat
import java.util.*

class CallDetectionService : Service() {
    private var telephonyManager: TelephonyManager? = null
    private var phoneStateListener: PhoneStateListener? = null
    private var lastState = TelephonyManager.CALL_STATE_IDLE
    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null
    private var aec: AcousticEchoCanceler? = null
    private var ns: NoiseSuppressor? = null
    private var agc: AutomaticGainControl? = null
    @Volatile private var isRecording = false
    private var preStartedDuringRinging = false
    private var currentRecordingPath: String? = null
    private var recordingStartTime: Long = 0

    // Audio state - save/restore when recording  
    private var audioManager: AudioManager? = null
    private var wasSpeakerOn = false
    private var previousAudioMode = AudioManager.MODE_NORMAL
    private var previousVolume = -1

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
                        // PRE-START recording during RINGING to bypass MIUI mute policy
                        // MIUI applies mute when AudioRecord starts during active call
                        // Starting BEFORE call connects may bypass this
                        if (!isRecording) {
                            preStartedDuringRinging = true
                            Log.d(TAG, "PRE-RECORDING: Starting before call connects (MIUI bypass)")
                            startRecording("SIM")
                        }
                    }
                    TelephonyManager.CALL_STATE_OFFHOOK -> {
                        Log.d(TAG, "Call answered/outgoing")
                        CallEventHandler.sendCallEvent("answered", "SIM", phoneNumber)
                        showBubble("SIM")
                        // For outgoing calls or if pre-start failed
                        if (!isRecording) {
                            preStartedDuringRinging = false
                            startRecording("SIM")
                        }
                    }
                    TelephonyManager.CALL_STATE_IDLE -> {
                        Log.d(TAG, "Call ended")
                        CallEventHandler.sendCallEvent("ended", "SIM", phoneNumber)
                        stopRecording()
                        hideBubble()
                        preStartedDuringRinging = false
                    }
                }
            }
        }

        telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
    }

    /** Apply aggressive audio parameter hacks to bypass MIUI call recording restrictions */
    private fun applyAudioHacks() {
        val am = audioManager ?: return

        // Hack 1: Qualcomm audio HAL - enables audio I/O during incall
        try {
            am.setParameters("incall_music_enabled=true")
            Log.d(TAG, "HACK1: incall_music_enabled=true ✓")
        } catch (e: Exception) {
            Log.w(TAG, "HACK1 failed: ${e.message}")
        }

        // Hack 2: Disable noise suppression
        try {
            am.setParameters("noise_suppression=off")
            am.setParameters("ec_supported=0")
            Log.d(TAG, "HACK2: noise_suppression=off, ec=0 ✓")
        } catch (e: Exception) {}

        // Hack 3: AudioSystem.setParameters via reflection (system-level bypass)
        try {
            val audioSystem = Class.forName("android.media.AudioSystem")
            val setParams = audioSystem.getMethod("setParameters", String::class.java)
            setParams.invoke(null, "incall_music_enabled=true")
            setParams.invoke(null, "noise_suppression=off")
            setParams.invoke(null, "call_recording.enabled=true")
            setParams.invoke(null, "ec_supported=0")
            Log.d(TAG, "HACK3: AudioSystem.setParameters ✓")
        } catch (e: Exception) {
            Log.w(TAG, "HACK3: AudioSystem reflection failed: ${e.message}")
        }

        // Hack 4: Vendor-specific SystemProperties (Qualcomm/Xiaomi)
        try {
            val sysProp = Class.forName("android.os.SystemProperties")
            val set = sysProp.getMethod("set", String::class.java, String::class.java)
            set.invoke(null, "persist.vendor.audio.calrecording", "1")
            set.invoke(null, "persist.vendor.audio.voicecall.speaker", "true")
            Log.d(TAG, "HACK4: SystemProperties ✓")
        } catch (e: Exception) {
            Log.w(TAG, "HACK4: SystemProperties failed: ${e.message}")
        }

        // Hack 5: Force audio routing to speaker channel
        try {
            am.setParameters("routing=2")
            Log.d(TAG, "HACK5: routing=SPEAKER ✓")
        } catch (e: Exception) {}

        // Hack 6: Try to disable MIUI mic privacy guard
        try {
            val resolver = contentResolver
            android.provider.Settings.Secure.putInt(resolver, "camera_and_mic_privacy_indicators", 0)
            Log.d(TAG, "HACK6: privacy indicators disabled ✓")
        } catch (e: Exception) {
            Log.w(TAG, "HACK6: privacy indicators failed: ${e.message}")
        }
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
            val fileName = "${source}_$timestamp.wav"
            val filePath = File(dir, fileName).absolutePath
            currentRecordingPath = filePath

            // === AUDIO ROUTING ===
            audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager?.let { am ->
                wasSpeakerOn = am.isSpeakerphoneOn
                previousAudioMode = am.mode
                previousVolume = am.getStreamVolume(AudioManager.STREAM_VOICE_CALL)

                am.isSpeakerphoneOn = true
                val maxVol = am.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL)
                am.setStreamVolume(AudioManager.STREAM_VOICE_CALL, maxVol, 0)
                Log.d(TAG, "Audio routing: speaker=ON, mode=${am.mode}, vol=$maxVol/$maxVol")
            }

            // === STEP 2: APPLY ALL AUDIO HACKS ===
            applyAudioHacks()

            try { Thread.sleep(300) } catch (_: Exception) {}

            // === STEP 3: TRY ALL AUDIO SOURCES (including hidden APIs) ===
            val sampleRate = 44100
            val channelConfig = AudioFormat.CHANNEL_IN_MONO
            val audioFmt = AudioFormat.ENCODING_PCM_16BIT
            val minBufSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFmt)
            val bufferSize = maxOf(minBufSize * 4, 8192)

            // ALL possible sources including hidden/internal APIs
            // Priority: sources most likely to bypass MIUI mute first
            val audioSources = listOf(
                3,  // VOICE_DOWNLINK (hidden) - direct modem capture, remote party
                2,  // VOICE_UPLINK (hidden) - direct modem capture, local party
                4,  // VOICE_CALL - both parties
                7,  // VOICE_COMMUNICATION - VoIP audio path
                9,  // UNPROCESSED - raw unprocessed mic data
                1,  // MIC - standard microphone
                6,  // VOICE_RECOGNITION - speech optimized
                5,  // CAMCORDER - camera mic
                8,  // REMOTE_SUBMIX - system audio mix
                0   // DEFAULT
            )

            var started = false
            var usedSource = -1
            for (src in audioSources) {
                try {
                    audioRecord = AudioRecord(src, sampleRate, channelConfig, audioFmt, bufferSize)
                    if (audioRecord?.state == AudioRecord.STATE_INITIALIZED) {
                        usedSource = src
                        started = true
                        Log.d(TAG, "AudioRecord initialized: source=$src \u2713")
                        break
                    }
                    audioRecord?.release()
                    audioRecord = null
                    Log.d(TAG, "Source $src: BLOCKED")
                } catch (e: Exception) {
                    Log.d(TAG, "Source $src: ERROR - ${e.message}")
                    try { audioRecord?.release() } catch (_: Exception) {}
                    audioRecord = null
                }
            }

            if (!started || audioRecord == null) {
                // LAST RESORT: Switch to MODE_IN_COMMUNICATION (VoIP audio path)
                // This creates a separate audio pipeline that MIUI may not block
                Log.w(TAG, "All sources BLOCKED! LAST RESORT: MODE_IN_COMMUNICATION...")
                audioManager?.mode = AudioManager.MODE_IN_COMMUNICATION
                try { Thread.sleep(200) } catch (_: Exception) {}
                for (src in listOf(7, 1, 9, 0)) {
                    try {
                        audioRecord = AudioRecord(src, sampleRate, channelConfig, audioFmt, bufferSize)
                        if (audioRecord?.state == AudioRecord.STATE_INITIALIZED) {
                            usedSource = src
                            started = true
                            Log.d(TAG, "LAST RESORT: Source $src with MODE_IN_COMMUNICATION \u2713")
                            break
                        }
                        audioRecord?.release()
                        audioRecord = null
                    } catch (e: Exception) {
                        try { audioRecord?.release() } catch (_: Exception) {}
                        audioRecord = null
                    }
                }
                if (!started || audioRecord == null) {
                    Log.e(TAG, "COMPLETELY FAILED - no audio source available at all")
                    audioManager?.mode = previousAudioMode
                    restoreAudioState()
                    currentRecordingPath = null
                    return
                }
            }

            // === CRITICAL: Disable Echo Cancellation & Noise Suppression ===
            // Android AEC actively REMOVES speaker audio from MIC input.
            // This is why recordings were silent even with speakerphone ON.
            val sessionId = audioRecord!!.audioSessionId
            try {
                if (AcousticEchoCanceler.isAvailable()) {
                    aec = AcousticEchoCanceler.create(sessionId)
                    aec?.enabled = false
                    Log.d(TAG, "AEC DISABLED \u2713")
                } else {
                    Log.d(TAG, "AEC not available on this device")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to disable AEC: ${e.message}")
            }

            try {
                if (NoiseSuppressor.isAvailable()) {
                    ns = NoiseSuppressor.create(sessionId)
                    ns?.enabled = false
                    Log.d(TAG, "NoiseSuppressor DISABLED")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to disable NS: ${e.message}")
            }

            try {
                if (AutomaticGainControl.isAvailable()) {
                    agc = AutomaticGainControl.create(sessionId)
                    agc?.enabled = true
                    Log.d(TAG, "AGC ENABLED for better volume")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to enable AGC: ${e.message}")
            }

            // Start AudioRecord
            audioRecord!!.startRecording()
            isRecording = true
            recordingStartTime = System.currentTimeMillis()

            // Background thread reads audio data and writes WAV file with gain boost
            recordingThread = Thread {
                writeAudioDataToFile(filePath, sampleRate, bufferSize)
            }
            recordingThread?.start()

            val sourceLabel = when (usedSource) {
                0 -> "DEFAULT"
                1 -> "MIC"
                2 -> "VOICE_UPLINK"
                3 -> "VOICE_DOWNLINK"
                4 -> "VOICE_CALL"
                5 -> "CAMCORDER"
                6 -> "VOICE_RECOG"
                7 -> "VOICE_COMM"
                8 -> "REMOTE_SUBMIX"
                9 -> "UNPROCESSED"
                else -> "SRC_$usedSource"
            }
            updateNotification("\uD83D\uDD34 Recording ($source) [$sourceLabel]")
            Log.d(TAG, "Recording started: $filePath source=$sourceLabel (speaker=ON, hacks=ON)")

            CallEventHandler.sendCallEvent("recordingStarted", source)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording: ${e.message}", e)
            restoreAudioState()
            cleanupRecorder()
        }
    }

    /** Write audio with AGGRESSIVE 20x gain and real-time mute detection */
    private fun writeAudioDataToFile(filePath: String, sampleRate: Int, bufferSize: Int) {
        val buffer = ShortArray(bufferSize / 2)
        var totalBytesWritten = 0L
        var totalSamples = 0L
        var nonZeroSamples = 0L
        var lastLogTime = System.currentTimeMillis()

        try {
            FileOutputStream(File(filePath)).use { fos ->
                fos.write(ByteArray(44)) // WAV header placeholder

                while (isRecording) {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: -1
                    if (read > 0) {
                        val byteBuffer = ByteArray(read * 2)
                        for (i in 0 until read) {
                            totalSamples++
                            if (buffer[i] != 0.toShort()) nonZeroSamples++

                            // AGGRESSIVE 20x gain amplification
                            val amplified = (buffer[i].toInt() * 20)
                                .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                            byteBuffer[i * 2] = (amplified and 0xFF).toByte()
                            byteBuffer[i * 2 + 1] = (amplified shr 8 and 0xFF).toByte()
                        }
                        fos.write(byteBuffer)
                        totalBytesWritten += byteBuffer.size

                        // Log mute status every 3 seconds
                        val now = System.currentTimeMillis()
                        if (now - lastLogTime >= 3000) {
                            val pct = if (totalSamples > 0) nonZeroSamples * 100 / totalSamples else 0
                            val status = if (pct < 1) "MUTED \u2717" else "AUDIO \u2713"
                            Log.d(TAG, "REC: ${(now - recordingStartTime) / 1000}s $status ($pct% non-zero, ${totalBytesWritten / 1024}KB)")
                            lastLogTime = now
                        }
                    }
                }
            }

            writeWavHeader(filePath, totalBytesWritten, sampleRate)
            val finalPct = if (totalSamples > 0) nonZeroSamples * 100 / totalSamples else 0
            Log.d(TAG, "WAV complete: ${totalBytesWritten}B, ${finalPct}% non-zero audio")
        } catch (e: Exception) {
            Log.e(TAG, "Error writing audio: ${e.message}", e)
        }
    }

    /** Write a valid WAV/RIFF header to the beginning of the file */
    private fun writeWavHeader(filePath: String, totalAudioLen: Long, sampleRate: Int) {
        try {
            val channels = 1
            val bitsPerSample = 16
            val byteRate = sampleRate * channels * bitsPerSample / 8
            val blockAlign = channels * bitsPerSample / 8
            val totalDataLen = totalAudioLen + 36

            RandomAccessFile(filePath, "rw").use { raf ->
                raf.seek(0)
                raf.writeBytes("RIFF")
                raf.write(intToByteArrayLE(totalDataLen.toInt()))
                raf.writeBytes("WAVE")
                raf.writeBytes("fmt ")
                raf.write(intToByteArrayLE(16))  // PCM sub-chunk size
                raf.write(shortToByteArrayLE(1)) // PCM format
                raf.write(shortToByteArrayLE(channels.toShort()))
                raf.write(intToByteArrayLE(sampleRate))
                raf.write(intToByteArrayLE(byteRate))
                raf.write(shortToByteArrayLE(blockAlign.toShort()))
                raf.write(shortToByteArrayLE(bitsPerSample.toShort()))
                raf.writeBytes("data")
                raf.write(intToByteArrayLE(totalAudioLen.toInt()))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write WAV header: ${e.message}")
        }
    }

    private fun intToByteArrayLE(value: Int): ByteArray {
        return byteArrayOf(
            (value and 0xFF).toByte(),
            (value shr 8 and 0xFF).toByte(),
            (value shr 16 and 0xFF).toByte(),
            (value shr 24 and 0xFF).toByte()
        )
    }

    private fun shortToByteArrayLE(value: Short): ByteArray {
        return byteArrayOf(
            (value.toInt() and 0xFF).toByte(),
            (value.toInt() shr 8 and 0xFF).toByte()
        )
    }

    fun stopRecording() {
        if (!isRecording) return

        val duration = (System.currentTimeMillis() - recordingStartTime) / 1000
        val filePath = currentRecordingPath

        // Signal recording thread to stop
        isRecording = false

        try {
            // Wait for recording thread to finish writing WAV data
            recordingThread?.join(3000)
            recordingThread = null

            // Stop and release AudioRecord
            audioRecord?.apply {
                try { stop() } catch (_: Exception) {}
                release()
            }
            audioRecord = null

            // Release audio effects
            try { aec?.release() } catch (_: Exception) {}
            try { ns?.release() } catch (_: Exception) {}
            try { agc?.release() } catch (_: Exception) {}
            aec = null; ns = null; agc = null

            Log.d(TAG, "Recording stopped: $filePath (duration: ${duration}s)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop recording: ${e.message}", e)
            try { audioRecord?.release() } catch (_: Exception) {}
            audioRecord = null
            try { aec?.release() } catch (_: Exception) {}
            try { ns?.release() } catch (_: Exception) {}
            try { agc?.release() } catch (_: Exception) {}
            aec = null; ns = null; agc = null
        }

        // Restore audio routing (speaker off, volume back)
        restoreAudioState()
        updateNotification("Monitoring calls...")

        // Validate the recorded file
        val isValidFile = filePath?.let { path ->
            try {
                val file = File(path)
                val fileSize = if (file.exists()) file.length() else 0
                Log.d(TAG, "Recording file size: $fileSize bytes at $path")
                // WAV: 44 bytes header + audio data. Minimum ~4KB for a valid recording
                if (fileSize < 4096) {
                    Log.w(TAG, "Recording file too small ($fileSize bytes), deleting corrupt file")
                    file.delete()
                    false
                } else {
                    true
                }
            } catch (ex: Exception) {
                Log.e(TAG, "Error validating recording file: ${ex.message}")
                false
            }
        } ?: false

        CallEventHandler.sendCallEvent("recordingStopped", "SIM", null)

        // Only notify Flutter if file is valid
        if (isValidFile && filePath != null) {
            val file = File(filePath)
            CallEventHandler.eventSink?.success(mapOf(
                "eventType" to "recordingSaved",
                "filePath" to filePath,
                "duration" to duration,
                "fileSize" to file.length(),
                "timestamp" to System.currentTimeMillis()
            ))
            Log.d(TAG, "Valid recording saved: $filePath (${duration}s, ${file.length()} bytes)")
        } else {
            Log.w(TAG, "Recording discarded - file was corrupt or too small")
            CallEventHandler.eventSink?.success(mapOf(
                "eventType" to "recordingFailed",
                "reason" to "File corrupt or empty",
                "timestamp" to System.currentTimeMillis()
            ))
        }

        currentRecordingPath = null
    }

    private fun cleanupRecorder() {
        try { audioRecord?.release() } catch (_: Exception) {}
        audioRecord = null
        try { aec?.release() } catch (_: Exception) {}
        try { ns?.release() } catch (_: Exception) {}
        try { agc?.release() } catch (_: Exception) {}
        aec = null; ns = null; agc = null
        isRecording = false
        currentRecordingPath = null
    }

    /** Restore audio settings that were changed before recording */
    private fun restoreAudioState() {
        audioManager?.let { am ->
            try {
                am.isSpeakerphoneOn = wasSpeakerOn
                if (previousVolume >= 0) {
                    am.setStreamVolume(AudioManager.STREAM_VOICE_CALL, previousVolume, 0)
                }
                // Restore mode if we changed it (MODE_IN_COMMUNICATION hack)
                if (am.mode != previousAudioMode) {
                    am.mode = previousAudioMode
                }
                Log.d(TAG, "Audio restored: speaker=$wasSpeakerOn, mode=$previousAudioMode, vol=$previousVolume")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to restore audio state: ${e.message}")
            }
        }
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

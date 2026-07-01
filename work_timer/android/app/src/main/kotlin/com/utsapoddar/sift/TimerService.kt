package com.utsapoddar.sift

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import java.io.File

class TimerService : Service() {

    companion object {
        const val CHANNEL_ID = "sift_timer_service"
        const val NOTIF_ID = 42
        const val ACTION_STOP = "com.sift.timer.stop"
        const val ACTION_SILENCE = "com.sift.timer.silence"
        const val ACTION_ALARM_FIRED = "com.sift.timer.alarm_fired"
        const val ACTION_SCHEDULE_ALARMS = "com.sift.timer.schedule_alarms"
        const val ACTION_CANCEL_ALARMS = "com.sift.timer.cancel_alarms"
        const val EXTRA_PHASE_NAMES = "phase_names"
        const val EXTRA_PHASE_END_TIMES = "phase_end_times"
        const val EXTRA_PHASE_NAME = "phase_name"
    }

    private var mediaPlayer: MediaPlayer? = null
    private var currentPhaseName: String = "Work"
    private var wakeLock: android.os.PowerManager.WakeLock? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var vibrator: Vibrator? = null
    private var alarmGateStartedAt: Long? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIF_ID, buildNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, buildNotification())
        }
        val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        wakeLock = pm.newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "sift:timer").apply {
            acquire(12 * 60 * 60 * 1000L) // max 12h, auto-released when service stops
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // On START_STICKY restart the system passes null intent — restore phase name from prefs
        if (intent == null) {
            val saved = getSharedPreferences("sift_boot", Context.MODE_PRIVATE)
                .getString("phase_names", null)
            if (saved != null) {
                currentPhaseName = saved.split(",").firstOrNull() ?: currentPhaseName
                updateNotification()
            }
            return START_STICKY
        }

        when (intent.action) {
            ACTION_ALARM_FIRED -> {
                currentPhaseName = intent.getStringExtra(EXTRA_PHASE_NAME) ?: currentPhaseName
                alarmGateStartedAt = System.currentTimeMillis()
                cancelAlarms()
                updateNotification()
                playAlarm()
                // Notify Flutter if it's alive
                sendBroadcast(Intent(ACTION_STOP).setPackage(packageName).apply {
                    action = "com.sift.timer.alarm_notify"
                })
            }
            ACTION_SCHEDULE_ALARMS -> {
                val names = intent.getStringArrayExtra(EXTRA_PHASE_NAMES) ?: return START_STICKY
                val times = intent.getLongArrayExtra(EXTRA_PHASE_END_TIMES) ?: return START_STICKY
                currentPhaseName = if (names.isNotEmpty()) names[0] else "Work"
                updateNotification()
                scheduleAlarms(names, times)
                // Persist for BootReceiver to reschedule after device reboot
                savePhaseDataForBoot(names, times)
            }
            ACTION_SILENCE -> {
                stopAlarmSound()
                resumeAlarmsAfterGate()
                // Also notify Flutter so the UI can react
                sendBroadcast(Intent("com.sift.timer.alarm_notify").setPackage(packageName).apply {
                    action = ACTION_SILENCE
                })
            }
            ACTION_CANCEL_ALARMS -> {
                cancelAlarms()
                clearPhaseDataForBoot()
                try { stopAlarmSound() } catch (_: Exception) {}
                try { abandonAudioFocus() } catch (_: Exception) {}
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        try { stopAlarmSound() } catch (_: Exception) {}
        try { abandonAudioFocus() } catch (_: Exception) {}
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun scheduleAlarms(names: Array<String>, times: LongArray) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val canScheduleExactAlarms =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()
        times.forEachIndexed { i, timeMs ->
            if (timeMs <= System.currentTimeMillis()) return@forEachIndexed
            val alarmIntent = Intent(this, AlarmReceiver::class.java).apply {
                putExtra(EXTRA_PHASE_NAME, if (i + 1 < names.size) names[i + 1] else "Done")
            }
            val pi = PendingIntent.getBroadcast(
                this, i, alarmIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            // setAlarmClock has highest priority — OEMs display it in the status bar and
            // virtually never suppress it, unlike setExactAndAllowWhileIdle on aggressive OEMs.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && canScheduleExactAlarms) {
                val showIntent = PendingIntent.getActivity(
                    this, i + 100,
                    Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    },
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                alarmManager.setAlarmClock(AlarmManager.AlarmClockInfo(timeMs, showIntent), pi)
            } else if (canScheduleExactAlarms) {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeMs, pi)
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, timeMs, pi)
            }
        }
    }

    private fun cancelAlarms() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (i in 0..6) {
            val pi = PendingIntent.getBroadcast(
                this, i, Intent(this, AlarmReceiver::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE
            )
            pi?.let { alarmManager.cancel(it) }
        }
    }

    private fun requestAlarmAudioFocus() {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .build()
            audioFocusRequest = req
            am.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
        }
    }

    private fun abandonAudioFocus() {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { am.abandonAudioFocusRequest(it) }
            audioFocusRequest = null
        } else {
            @Suppress("DEPRECATION")
            am.abandonAudioFocus(null)
        }
    }

    private fun savePhaseDataForBoot(names: Array<String>, times: LongArray) {
        getSharedPreferences("sift_boot", Context.MODE_PRIVATE).edit().apply {
            // Store as comma-separated strings to preserve insertion order
            putString("phase_names", names.joinToString(","))
            putString("phase_times", times.joinToString(","))
            apply()
        }
    }

    private fun clearPhaseDataForBoot() {
        getSharedPreferences("sift_boot", Context.MODE_PRIVATE).edit().clear().apply()
    }

    private fun resumeAlarmsAfterGate() {
        val gateStartedAt = alarmGateStartedAt ?: return
        val elapsedMs = (System.currentTimeMillis() - gateStartedAt).coerceAtLeast(0L)
        val prefs = getSharedPreferences("sift_boot", Context.MODE_PRIVATE)
        val namesStr = prefs.getString("phase_names", null) ?: return
        val timesStr = prefs.getString("phase_times", null) ?: return
        val names = namesStr.split(",").toTypedArray()
        val shiftedTimes = timesStr.split(",")
            .mapNotNull { it.toLongOrNull() }
            .map { if (it > gateStartedAt) it + elapsedMs else it }
            .toLongArray()
        if (shiftedTimes.isNotEmpty()) {
            scheduleAlarms(names, shiftedTimes)
            savePhaseDataForBoot(names, shiftedTimes)
        }
        alarmGateStartedAt = null
    }

    private fun playAlarm() {
        stopAlarmSound()
        requestAlarmAudioFocus()
        startAlarmVibration()
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val ringtonePath = prefs.getString("flutter.ringtone_path", null)

        try {
            mediaPlayer = when {
                ringtonePath.isNullOrBlank() -> null
                ringtonePath.startsWith("content://") -> {
                    contentResolver.openFileDescriptor(Uri.parse(ringtonePath), "r")?.use { pfd ->
                        MediaPlayer().apply {
                            setAudioAttributes(AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build())
                            setDataSource(pfd.fileDescriptor)
                            prepare()
                        }
                    }
                }
                File(ringtonePath).exists() -> {
                    MediaPlayer().apply {
                        setAudioAttributes(AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build())
                        setDataSource(ringtonePath)
                        prepare()
                    }
                }
                else -> null
            } ?: run {
                val afd = assets.openFd("flutter_assets/assets/alarm.mp3")
                MediaPlayer().apply {
                    setAudioAttributes(AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build())
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    prepare()
                }
            }
            mediaPlayer?.apply {
                isLooping = true
                setOnCompletionListener { mp ->
                    if (mediaPlayer == mp) {
                        try { mp.release() } catch (_: Exception) {}
                        mediaPlayer = null
                        stopAlarmVibration()
                    }
                }
                start()
            }
        } catch (_: Exception) {}
    }

    private fun stopAlarmSound() {
        mediaPlayer?.let { mp ->
            try {
                if (mp.isPlaying) mp.stop()
                mp.release()
            } catch (_: Exception) {}
            mediaPlayer = null
        }
        stopAlarmVibration()
    }

    private fun startAlarmVibration() {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val pattern = longArrayOf(0, 700, 700)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }
    }

    private fun stopAlarmVibration() {
        try { vibrator?.cancel() } catch (_: Exception) {}
        vibrator = null
    }

    private fun updateNotification() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, buildNotification())
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(ACTION_STOP).setPackage(packageName)
        val stopPi = PendingIntent.getBroadcast(
            this, 0, stopIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val silenceIntent = Intent(this, TimerService::class.java).apply { action = ACTION_SILENCE }
        val silencePi = PendingIntent.getService(
            this, 1, silenceIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openAppPi = PendingIntent.getActivity(
            this, 2, openAppIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Sift — $currentPhaseName")
            .setContentText("Timer running")
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setContentIntent(openAppPi)
            .addAction(0, "Stop", stopPi)
            .addAction(0, "Silence", silencePi)
            .build()
    }

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID, "Timer Service", NotificationManager.IMPORTANCE_LOW
        ).apply { description = "Keeps timer running in background" }
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(channel)
    }
}

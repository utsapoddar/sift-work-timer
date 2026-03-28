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
                // Also notify Flutter so the UI can react
                sendBroadcast(Intent("com.sift.timer.alarm_notify").setPackage(packageName).apply {
                    action = ACTION_SILENCE
                })
            }
            ACTION_CANCEL_ALARMS -> {
                cancelAlarms()
                clearPhaseDataForBoot()
                stopAlarmSound()
                abandonAudioFocus()
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAlarmSound()
        abandonAudioFocus()
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
        // On Android 12+ the user can revoke exact-alarm permission from Settings.
        // setAlarmClock falls back to inexact delivery if the permission is missing —
        // log a notification so the user knows to re-grant it.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIF_ID + 1,
                NotificationCompat.Builder(this, CHANNEL_ID)
                    .setSmallIcon(R.drawable.ic_notification)
                    .setContentTitle("Sift needs permission")
                    .setContentText("Allow exact alarms so the timer rings on time. Tap to open settings.")
                    .setContentIntent(PendingIntent.getActivity(
                        this, 99,
                        android.content.Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM),
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    ))
                    .setAutoCancel(true)
                    .build()
            )
        }
        times.forEachIndexed { i, timeMs ->
            val alarmIntent = Intent(this, AlarmReceiver::class.java).apply {
                putExtra(EXTRA_PHASE_NAME, if (i + 1 < names.size) names[i + 1] else "Done")
            }
            val pi = PendingIntent.getBroadcast(
                this, i, alarmIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            // setAlarmClock has highest priority — OEMs display it in the status bar and
            // virtually never suppress it, unlike setExactAndAllowWhileIdle on aggressive OEMs.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val showIntent = PendingIntent.getActivity(
                    this, i + 100,
                    Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    },
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                alarmManager.setAlarmClock(AlarmManager.AlarmClockInfo(timeMs, showIntent), pi)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeMs, pi)
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

    private fun playAlarm() {
        stopAlarmSound()
        requestAlarmAudioFocus()
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val ringtonePath = prefs.getString("flutter.ringtone_path", null)

        try {
            mediaPlayer = if (ringtonePath != null && File(ringtonePath).exists()) {
                MediaPlayer().apply {
                    setAudioAttributes(AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build())
                    setDataSource(ringtonePath)
                    prepare()
                }
            } else {
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
                isLooping = false
                setOnCompletionListener { mp -> mp.release(); mediaPlayer = null }
                start()
            }
        } catch (_: Exception) {}
    }

    private fun stopAlarmSound() {
        mediaPlayer?.apply { if (isPlaying) stop(); release() }
        mediaPlayer = null
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
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Sift — $currentPhaseName")
            .setContentText("Timer running")
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
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

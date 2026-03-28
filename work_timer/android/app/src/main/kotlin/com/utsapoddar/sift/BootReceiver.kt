package com.utsapoddar.sift

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val prefs = context.getSharedPreferences("sift_boot", Context.MODE_PRIVATE)
        val namesStr = prefs.getString("phase_names", null) ?: return
        val timesStr = prefs.getString("phase_times", null) ?: return

        val times = timesStr.split(",").mapNotNull { it.toLongOrNull() }.toLongArray()
        if (times.isEmpty()) return

        // Discard alarms that have already passed — no point rescheduling them
        val now = System.currentTimeMillis()
        val futureCount = times.count { it > now }
        if (futureCount == 0) {
            prefs.edit().clear().apply()
            return
        }

        val names = namesStr.split(",").toTypedArray()
        val serviceIntent = Intent(context, TimerService::class.java).apply {
            action = TimerService.ACTION_SCHEDULE_ALARMS
            putExtra(TimerService.EXTRA_PHASE_NAMES, names)
            putExtra(TimerService.EXTRA_PHASE_END_TIMES, times)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}

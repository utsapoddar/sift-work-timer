package com.utsapoddar.sift

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val serviceIntent = Intent(context, TimerService::class.java).apply {
            action = TimerService.ACTION_ALARM_FIRED
            putExtra(TimerService.EXTRA_PHASE_NAME, intent.getStringExtra(TimerService.EXTRA_PHASE_NAME) ?: "")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}

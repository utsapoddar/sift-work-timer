package com.utsapoddar.sift

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var timerActionCh: MethodChannel? = null

    private val actionReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            val action = when (intent.action) {
                TimerService.ACTION_STOP -> "stop"
                TimerService.ACTION_SILENCE -> "silence"
                "com.sift.timer.alarm_notify" -> "alarm"
                else -> return
            }
            runOnUiThread {
                timerActionCh?.invokeMethod("onTimerAction", action)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        timerActionCh = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.sift.timer_action")
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.sift.live_activity")
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "startTimerService" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as? Map<String, Any> ?: emptyMap<String, Any>()
                    val phaseNames = (args["phaseNames"] as? List<*>)
                        ?.filterIsInstance<String>()?.toTypedArray() ?: emptyArray()
                    val phaseEndTimes = (args["phaseEndTimes"] as? List<*>)
                        ?.map { (it as Number).toLong() }?.toLongArray() ?: LongArray(0)

                    val intent = Intent(this, TimerService::class.java).apply {
                        action = TimerService.ACTION_SCHEDULE_ALARMS
                        putExtra(TimerService.EXTRA_PHASE_NAMES, phaseNames)
                        putExtra(TimerService.EXTRA_PHASE_END_TIMES, phaseEndTimes)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopTimerService" -> {
                    val intent = Intent(this, TimerService::class.java).apply {
                        action = TimerService.ACTION_CANCEL_ALARMS
                    }
                    startService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Request notification permission on launch so it's settled before timer starts
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
        }
        val filter = IntentFilter().apply {
            addAction(TimerService.ACTION_STOP)
            addAction(TimerService.ACTION_SILENCE)
            addAction("com.sift.timer.alarm_notify")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(actionReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(actionReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(actionReceiver)
    }
}

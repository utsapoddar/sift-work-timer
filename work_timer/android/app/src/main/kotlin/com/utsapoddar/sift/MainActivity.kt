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
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                            != PackageManager.PERMISSION_GRANTED) {
                        ActivityCompat.requestPermissions(
                            this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
                    }
                    val intent = Intent(this, TimerService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopTimerService" -> {
                    stopService(Intent(this, TimerService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter().apply {
            addAction(TimerService.ACTION_STOP)
            addAction(TimerService.ACTION_SILENCE)
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

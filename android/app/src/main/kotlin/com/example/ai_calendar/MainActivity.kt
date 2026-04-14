package com.example.ai_calendar

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.ai_calendar/alarm"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.navigationBarColor = android.graphics.Color.TRANSPARENT

        // 如果从通知点击进来，停止铃声
        if (intent?.getBooleanExtra("stop_alarm", false) == true) {
            AlarmSoundService.stop(this)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra("stop_alarm", false)) {
            AlarmSoundService.stop(this)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleNativeAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val triggerAtMillis = call.argument<Long>("triggerAtMillis") ?: 0L
                    val title = call.argument<String>("title") ?: "AI日历提醒"
                    val body = call.argument<String>("body") ?: ""
                    scheduleAlarm(id, triggerAtMillis, title, body)
                    result.success(true)
                }
                "cancelNativeAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    cancelAlarm(id)
                    result.success(true)
                }
                "startAlarm" -> {
                    AlarmSoundService.start(this)
                    result.success(true)
                }
                "stopAlarm" -> {
                    AlarmSoundService.stop(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun scheduleAlarm(id: Int, triggerAtMillis: Long, title: String, body: String) {
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra(AlarmReceiver.EXTRA_ID, id)
            putExtra(AlarmReceiver.EXTRA_TITLE, title)
            putExtra(AlarmReceiver.EXTRA_BODY, body)
        }
        val pending = PendingIntent.getBroadcast(
            this, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
    }

    private fun cancelAlarm(id: Int) {
        val intent = Intent(this, AlarmReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            this, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pending)
    }
}

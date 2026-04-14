package com.example.ai_calendar

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        const val EXTRA_TITLE = "alarm_title"
        const val EXTRA_BODY = "alarm_body"
        const val EXTRA_ID = "alarm_id"
        const val CHANNEL_ID = "calendar_alarm_v3"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "AI日历提醒"
        val body = intent.getStringExtra(EXTRA_BODY) ?: ""
        val id = intent.getIntExtra(EXTRA_ID, 0)

        // 创建通知通道
        val channel = NotificationChannel(
            CHANNEL_ID, "日程闹钟",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "日历事项到期闹钟提醒"
            setSound(null, null) // 声音由 AlarmSoundService 播放
            enableVibration(false)
        }
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(channel)

        // 点击通知打开 app 并停止铃声
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("stop_alarm", true)
        }
        val tapPending = PendingIntent.getActivity(
            context, id, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 全屏 Intent（触发 heads-up 桌面弹窗）
        val fullScreenPending = PendingIntent.getActivity(
            context, id + 100000, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 发通知
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setOngoing(true)
            .setContentIntent(tapPending)
            .setFullScreenIntent(fullScreenPending, true)
            .build()
        nm.notify(id, notification)

        // 启动闹钟铃声
        AlarmSoundService.start(context)
    }
}

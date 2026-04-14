package com.example.ai_calendar

import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

class AlarmSoundService : Service() {
    companion object {
        private var ringtone: Ringtone? = null
        private var vibrator: Vibrator? = null

        fun start(context: Context) {
            val intent = Intent(context, AlarmSoundService::class.java)
            context.startService(intent)
        }

        fun stop(context: Context) {
            ringtone?.stop()
            ringtone = null
            vibrator?.cancel()
            vibrator = null
            val intent = Intent(context, AlarmSoundService::class.java)
            context.stopService(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        playAlarm()
        return START_NOT_STICKY
    }

    private fun playAlarm() {
        // 播放系统闹钟铃声
        val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        ringtone = RingtoneManager.getRingtone(this, alarmUri)?.apply {
            audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            isLooping = true
            play()
        }

        // 振动
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val pattern = longArrayOf(0, 500, 200, 500, 200, 500, 1000)
        vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
    }

    override fun onDestroy() {
        ringtone?.stop()
        ringtone = null
        vibrator?.cancel()
        vibrator = null
        super.onDestroy()
    }
}

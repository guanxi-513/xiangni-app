package com.missyou.miss_you_lover

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

/**
 * 前台保活服务
 *
 * 通过启动一个前台通知服务来提升 App 进程优先级，
 * 降低系统杀后台的概率。
 *
 * 同时持有 WakeLock + WiFi Lock，确保：
 * - CPU 不休眠（WebSocket 能继续收消息）
 * - WiFi 不断连（屏幕关闭后仍保持网络连接）
 *
 * 限制说明：
 * - 国产深度定制系统（小米/华为/OPPO/vivo）会查杀后台，
 *   无法做到永久常驻。
 * - 进程被杀后需要重新打开 App 重建 WebSocket 连接。
 * - 此服务仅提升保活概率，不保证 100% 存活。
 *
 * 调用方式（Flutter 端）：
 *   MethodChannel("miss_you_lover/foreground_service")
 *     .invokeMethod("startService")  // 启动
 *     .invokeMethod("stopService")   // 停止
 */
class ForegroundService : Service() {

    companion object {
        private const val TAG = "ForegroundService"
        private const val CHANNEL_ID = "miss_you_lover_background"
        private const val NOTIFICATION_ID = 8888
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "ForegroundService onCreate")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "ForegroundService onStartCommand")

        val action = intent?.action ?: "START"

        if (action == "STOP") {
            releaseLocks()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        // 创建通知渠道（Android 8.0+ 必须）
        createNotificationChannel()

        // 构建前台通知
        val notification = buildNotification()

        // 启动前台服务
        startForeground(NOTIFICATION_ID, notification)

        // 获取 WakeLock + WiFi Lock，确保后台不休眠、不断网
        acquireLocks()

        // 如果服务被杀，尝试重新启动
        return START_STICKY
    }

    /**
     * 获取 WakeLock 和 WiFi Lock
     *
     * WakeLock: PARTIAL_WAKE_LOCK — 保持 CPU 运行，不亮屏
     * WiFi Lock: WIFI_MODE_FULL_HIGH_PERF — 保持 WiFi 高性能连接
     */
    private fun acquireLocks() {
        // ── WakeLock：防止 CPU 休眠 ──
        if (wakeLock == null) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "miss_you_lover::websocket_keepalive"
            )
            wakeLock?.setReferenceCounted(false)
        }
        if (wakeLock?.isHeld == false) {
            wakeLock?.acquire()
            Log.i(TAG, "WakeLock acquired")
        }

        // ── WiFi Lock：防止 WiFi 在熄屏后断连 ──
        if (wifiLock == null) {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifiLock = wifiManager.createWifiLock(
                WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                "miss_you_lover::wifi_lock"
            )
            wifiLock?.setReferenceCounted(false)
        }
        if (wifiLock?.isHeld == false) {
            wifiLock?.acquire()
            Log.i(TAG, "WiFi Lock acquired")
        }
    }

    /**
     * 释放 WakeLock 和 WiFi Lock
     */
    private fun releaseLocks() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.i(TAG, "WakeLock released")
            }
        } catch (e: Exception) {
            Log.e(TAG, "release WakeLock error: ${e.message}")
        }
        try {
            if (wifiLock?.isHeld == true) {
                wifiLock?.release()
                Log.i(TAG, "WiFi Lock released")
            }
        } catch (e: Exception) {
            Log.e(TAG, "release WiFi Lock error: ${e.message}")
        }
    }

    /**
     * 创建通知渠道
     * Android 8.0 (API 26) 及以上必须创建渠道才能显示通知
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "后台保活服务",
                NotificationManager.IMPORTANCE_LOW  // 低优先级，不发声
            ).apply {
                description = "保持 WebSocket 连接，及时收到想你消息"
                setShowBadge(false)
                enableVibration(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    /**
     * 构建前台通知
     *
     * 低优先级、不可点击跳转、常驻通知栏
     */
    private fun buildNotification(): Notification {
        // 点击通知跳转到 MainActivity
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("想你 ❤")
            .setContentText("正在守护你的连接...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)  // 常驻通知栏，不可滑动清除
            .setPriority(Notification.PRIORITY_LOW)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? {
        // 不支持绑定，返回 null
        return null
    }

    override fun onDestroy() {
        releaseLocks()
        super.onDestroy()
        Log.i(TAG, "ForegroundService onDestroy")
    }
}

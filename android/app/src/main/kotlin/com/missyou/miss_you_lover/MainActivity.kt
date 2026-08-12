package com.missyou.miss_you_lover

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 主 Activity
 *
 * 提供 MethodChannel 供 Flutter 调用原生前台服务
 *
 * 通道名：miss_you_lover/foreground_service
 * 方法：
 *   - startService()  启动前台保活服务
 *   - stopService()   停止前台保活服务
 */
class MainActivity : FlutterActivity() {

    private val CHANNEL = "miss_you_lover/foreground_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        startForegroundService()
                        result.success(true)
                    }
                    "stopService" -> {
                        stopForegroundService()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 启动前台保活服务
     */
    private fun startForegroundService() {
        val intent = Intent(this, ForegroundService::class.java)
        intent.action = "START"
        startService(intent)
    }

    /**
     * 停止前台保活服务
     */
    private fun stopForegroundService() {
        val intent = Intent(this, ForegroundService::class.java)
        intent.action = "STOP"
        startService(intent)
    }
}

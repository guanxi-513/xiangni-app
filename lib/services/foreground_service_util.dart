// ============================================================
// 前台服务工具类
//
// 通过 MethodChannel 调用 Android 原生前台服务，
// 提升 App 进程优先级，降低被系统杀死概率。
//
// ============================================================
// 限制说明（重要！）：
//
// 1. 国产深度定制系统（小米/华为/OPPO/vivo）会主动查杀后台进程，
//    前台服务只能提升保活概率，无法做到 100% 永久常驻。
//
// 2. 进程被杀后，WebSocket 连接会断开。
//    需要用户重新打开 App，WebSocketService 的自动重连机制会尝试恢复。
//
// 3. 前台服务会在通知栏显示一条常驻通知（"正在守护你的连接..."），
//    这是 Android 系统要求，不可隐藏。
//
// 4. 建议在配对成功后调用 startService()，断开连接时调用 stopService()。
// ============================================================

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

class ForegroundServiceUtil {
  ForegroundServiceUtil._();

  static final _log = Logger();

  /// MethodChannel 名称，与 MainActivity.kt 中一致
  static const _channel = MethodChannel('miss_you_lover/foreground_service');

  /// 启动前台保活服务
  ///
  /// 在通知栏显示常驻通知，提升进程优先级。
  /// 建议在 WebSocket 配对成功后调用。
  static Future<bool> startService() async {
    try {
      await _channel.invokeMethod('startService');
      _log.i('foreground service started');
      return true;
    } catch (e) {
      _log.e('start foreground service failed: $e');
      return false;
    }
  }

  /// 停止前台保活服务
  ///
  /// 清除通知栏常驻通知。
  /// 建议在断开连接 / 退出 App 时调用。
  static Future<bool> stopService() async {
    try {
      await _channel.invokeMethod('stopService');
      _log.i('foreground service stopped');
      return true;
    } catch (e) {
      _log.e('stop foreground service failed: $e');
      return false;
    }
  }
}

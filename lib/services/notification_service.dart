// ============================================================
// 本地通知服务
//
// 使用 flutter_local_notifications 实现：
//   1. 创建高优先级通知渠道（IMPORTANCE_HIGH，弹窗 + 响铃 + 震动）
//   2. 收到「想你」消息且 App 在后台时，弹出高优先级通知
//   3. 用户点击通知 → 唤醒 App 到前台 → 触发爱心悬浮窗
//   4. 处理 App 被杀死后通过通知启动的边界场景
//
// 通知 payload：爱心颜色的 hex 字符串（如 "#ff69b4"）
// ============================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:logger/logger.dart';

class NotificationService {
  NotificationService._();
  static final _log = Logger();
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── 通知渠道配置 ──
  // v2: 显式指定系统默认通知铃声（微信同款），ID 变更是为了让系统重建渠道（
  //     Android 渠道一旦创建，修改 sound 不生效，必须换 ID）
  static const String _channelId = 'miss_you_heart_v2';
  static const String _channelName = '想你消息';
  static const String _channelDesc = '收到想你/文字消息时的高优先级通知，点击查看';

  // ── 通知 ID ──
  static int _notificationId = 0;

  // ── 待处理的爱心消息（App 被杀死时通过通知启动）──
  /// 当 App 被杀死后通过通知启动时，此字段保存通知携带的颜色
  /// WebSocketService 初始化完成后会检查并触发动画
  static String? pendingMissYouColor;

  // ── 通知点击回调 ──
  /// 当用户点击通知时调用，参数为颜色 hex 字符串
  static void Function(String colorHex)? onNotificationTap;

  // ══════════════════════════════════════════════
  //  初始化
  // ══════════════════════════════════════════════

  /// 初始化通知服务
  ///
  /// 在 main() 中 runApp 之前调用
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // 创建高优先级通知渠道
    await _createHighPriorityChannel();

    // 检查 App 是否通过通知启动
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse?.payload != null) {
      final payload = launchDetails.notificationResponse!.payload!;
      _log.i('App launched from notification, payload: $payload');
      pendingMissYouColor = payload;
    }

    _log.i('NotificationService initialized');
  }

  /// 创建高优先级通知渠道
  ///
  /// IMPORTANCE_HIGH: 弹出横幅（heads-up）、响铃、震动
  /// 未显式指定自定义 sound + playSound=true → 使用系统默认通知铃声
  ///   （= Settings.System.DEFAULT_NOTIFICATION_URI，与微信收到消息默认音效完全一致）
  static Future<void> _createHighPriorityChannel() async {
    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
      enableLights: true,
      ledColor: const Color(0xFFFF4081),
      // sound 不设置 = 使用系统 DEFAULT_NOTIFICATION_URI（微信同款）
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _log.i('High priority channel created: $_channelId (sound=system default)');
  }

  // ══════════════════════════════════════════════
  //  通知点击处理
  // ══════════════════════════════════════════════

  /// 通知点击回调
  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    _log.i('Notification tapped, payload: $payload, actionId: ${response.actionId}');

    if (payload != null && payload.isNotEmpty) {
      // 如果回调已设置，直接调用
      if (onNotificationTap != null) {
        onNotificationTap!(payload);
      } else {
        // 回调未设置（App 刚启动），暂存等待初始化完成
        _log.w('onNotificationTap not set yet, storing payload');
        pendingMissYouColor = payload;
      }
    }
  }

  // ══════════════════════════════════════════════
  //  显示通知
  // ══════════════════════════════════════════════

  /// 显示「想你」通知
  ///
  /// [colorHex] 爱心颜色 hex 字符串（如 "#ff69b4"）
  static Future<void> showMissYouNotification(String colorHex) async {
    // 检查并请求通知权限
    if (!await _ensurePermission()) {
      _log.w('Notification permission not granted, cannot show notification');
      return;
    }

    _notificationId++;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      showWhen: true,
      when: null,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      fullScreenIntent: false,
      autoCancel: true,
      enableVibration: true,
      enableLights: true,
      // 不指定 sound + playSound=true → 系统默认通知铃声（微信同款）
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      _notificationId,
      '想你 ❤',
      '收到一个「想你」消息，点击查看爱心动画',
      details,
      payload: colorHex,
    );

    _log.i('Miss you notification shown (id=$_notificationId, color=$colorHex)');
  }

  /// 显示「文字消息」通知
  ///
  /// 后台收到对方消息时调用，高优先级横幅展示内容，
  /// 用户点击后 payload = "text:内容" 被 dispatch 到聊天记录。
  static Future<void> showTextNotification(String content) async {
    if (!await _ensurePermission()) {
      _log.w('Notification permission not granted, cannot show text notification');
      return;
    }

    _notificationId++;

    // 通知区域有限，超过 ~60 字截断显示，完整内容在 payload 携带
    final displayText = content.length > 80
        ? '${content.substring(0, 80)}…'
        : content;
    final payload = 'text:$content';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      showWhen: true,
      when: null,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      fullScreenIntent: false,
      autoCancel: true,
      enableVibration: true,
      enableLights: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      _notificationId,
      'TA 发来消息 ❤',
      displayText,
      details,
      payload: payload,
    );

    final preview = content.length > 40 ? '${content.substring(0, 40)}…' : content;
    _log.i('Text notification shown (id=$_notificationId): "$preview"');
  }

  // ══════════════════════════════════════════════
  //  权限管理
  // ══════════════════════════════════════════════

  /// 确保通知权限已授予
  ///
  /// Android 13+ (API 33) 需要运行时申请 POST_NOTIFICATIONS
  static Future<bool> _ensurePermission() async {
    if (!Platform.isAndroid) return true;

    final status = await perm.Permission.notification.status;
    if (status.isGranted) return true;

    // 请求权限
    final result = await perm.Permission.notification.request();
    _log.i('Notification permission request result: $result');
    return result.isGranted;
  }

  /// 检查通知权限是否已授予
  static Future<bool> hasPermission() async {
    final status = await perm.Permission.notification.status;
    return status.isGranted;
  }

  // ══════════════════════════════════════════════
  //  工具
  // ══════════════════════════════════════════════

  /// 取消所有通知
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
    _log.i('All notifications cancelled');
  }

  /// 将 hex 字符串转为 Color
  static Color parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    try {
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      } else if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFFFF4081);
  }
}

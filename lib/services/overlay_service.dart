// ============================================================
// 悬浮窗服务 OverlayService
//
// 基于 flutter_overlay_window 0.5.0 封装
//
// 功能：
//   1. 初始化悬浮窗引擎
//   2. showLoveWindow() — 显示全屏爱心动画悬浮窗
//   3. closeOverlayWindow() — 关闭悬浮窗
//   4. 权限检测与异常捕获
//   5. 动画 3~5 秒后自动关闭
//
// flutter_overlay_window API 说明：
//   - showOverlay()        显示悬浮窗
//   - closeOverlay()       关闭悬浮窗
//   - isActive()           检查悬浮窗是否活跃
//   - isPermissionGranted() 检查悬浮窗权限
//   - requestPermission()  请求悬浮窗权限（跳转系统设置）
//   - shareData(data)      向悬浮窗发送数据
//   - overlayListener      监听来自悬浮窗的数据
//
// WindowSize 说明：
//   - fullCover = -1999  覆盖全屏（含状态栏和导航栏）
//   - matchParent = -1   匹配父容器宽度
//
// OverlayFlag 说明：
//   - defaultFlag    不获取焦点，标准悬浮窗行为
//   - clickThrough   点击穿透
//   - focusPointer   允许外部点击传递到后方窗口
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:logger/logger.dart';

/// 悬浮窗服务
///
/// 负责悬浮窗的生命周期管理、权限校验、异常处理。
/// 所有方法均为静态方法，无需实例化。
class OverlayService {
  OverlayService._();

  static final _log = Logger();

  /// 悬浮窗显示时长（毫秒）
  /// 动画默认 4 秒，加 500ms 缓冲后自动关闭
  static const int _autoCloseDelayMs = 4500;

  /// 自动关闭定时器
  static Timer? _autoCloseTimer;

  /// 防重复打开标志
  ///
  /// 当 showLoveWindow() 正在执行时设为 true，
  /// 阻止后续调用重复触发。
  static bool _isShowing = false;

  // ──────────────────────────────────────────────
  // 初始化
  // ──────────────────────────────────────────────

  /// 初始化悬浮窗引擎
  ///
  /// 在 App 启动时调用，检查权限状态并预热 overlay 引擎。
  /// 此方法不会显示悬浮窗，仅做准备工作。
  static Future<void> initialize() async {
    try {
      final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
      _log.i('overlay permission granted: $hasPermission');

      if (!hasPermission) {
        _log.w(
          'overlay permission not granted, '
          'call requestPermission() to request',
        );
      }
    } catch (e) {
      _log.e('initialize overlay error: $e');
    }
  }

  // ──────────────────────────────────────────────
  // 权限管理
  // ──────────────────────────────────────────────

  /// 检查悬浮窗权限是否已授予
  static Future<bool> hasPermission() async {
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (e) {
      _log.e('check permission error: $e');
      return false;
    }
  }

  /// 请求悬浮窗权限
  ///
  /// 会跳转到系统悬浮窗权限设置页面。
  /// 用户开启后返回 App 即可使用悬浮窗功能。
  static Future<bool> requestPermission() async {
    try {
      final result = await FlutterOverlayWindow.requestPermission();
      _log.i('request permission result: $result');
      return result ?? false;
    } catch (e) {
      _log.e('request permission error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────
  // 悬浮窗显示 / 关闭
  // ──────────────────────────────────────────────

  /// 显示爱心动画悬浮窗
  ///
  /// 流程：
  /// 1. 检查悬浮窗权限
  /// 2. 如权限不足，返回 false（调用方应引导用户开启权限）
  /// 3. 如已有悬浮窗在显示，先关闭旧的
  /// 4. 调用 showOverlay() 全屏显示
  /// 5. 延迟发送 'miss_you' 数据触发动画
  /// 6. 设置自动关闭定时器
  ///
  /// 返回 true 表示成功显示，false 表示权限不足或出错
  static Future<bool> showLoveWindow() async {
    // 防重复打开：如果正在显示中，直接返回
    if (_isShowing) {
      _log.w('showLoveWindow skipped: already in progress');
      return false;
    }

    _isShowing = true;
    _log.i('showLoveWindow: starting...');

    try {
      // 1. 权限检查
      final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
      if (!hasPermission) {
        _log.w('overlay permission not granted, cannot show');
        _isShowing = false;
        return false;
      }

      // 2. 如已有悬浮窗在显示，先关闭
      final active = await FlutterOverlayWindow.isActive();
      if (active) {
        _log.i('overlay already active, closing first...');
        await FlutterOverlayWindow.closeOverlay();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 3. 显示悬浮窗 — 全屏覆盖，层级置顶
      _log.i('calling showOverlay()...');
      await FlutterOverlayWindow.showOverlay(
        height: WindowSize.fullCover,    // 覆盖全屏
        width: WindowSize.matchParent,   // 匹配屏幕宽度
        alignment: OverlayAlignment.center,
        flag: OverlayFlag.defaultFlag,   // 标准悬浮窗
        enableDrag: false,               // 禁止拖动
      );
      _log.i('showOverlay() completed');

      // 4. 等待 overlay 引擎启动后发送触发数据
      _log.i('waiting 800ms for overlay engine...');
      await Future.delayed(const Duration(milliseconds: 800));
      await FlutterOverlayWindow.shareData('miss_you');
      _log.i('trigger data sent: miss_you');

      // 5. 设置自动关闭定时器
      _autoCloseTimer?.cancel();
      _autoCloseTimer = Timer(
        const Duration(milliseconds: _autoCloseDelayMs),
        () async {
          _log.i('auto closing overlay (timeout)...');
          await closeOverlayWindow();
        },
      );

      _log.i('showLoveWindow: success');
      return true;
    } catch (e, stack) {
      _log.e('showLoveWindow error: $e\n$stack');
      _isShowing = false;
      return false;
    }
  }

  /// 关闭悬浮窗
  static Future<void> closeOverlayWindow() async {
    try {
      _autoCloseTimer?.cancel();
      _autoCloseTimer = null;

      await FlutterOverlayWindow.closeOverlay();
      _log.i('overlay closed');
    } catch (e) {
      _log.e('close overlay error: $e');
    } finally {
      _isShowing = false;
    }
  }

  // ──────────────────────────────────────────────
  // 状态查询
  // ──────────────────────────────────────────────

  /// 检查悬浮窗是否正在显示
  static Future<bool> isActive() async {
    try {
      return await FlutterOverlayWindow.isActive();
    } catch (e) {
      _log.e('check active error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────
  // 权限不足时的 UI 提示
  // ──────────────────────────────────────────────

  /// 权限不足时显示提示对话框
  ///
  /// 在调用 [showLoveWindow] 返回 false 时调用此方法，
  /// 引导用户前往系统设置开启悬浮窗权限。
  static Future<void> showPermissionDeniedDialog(
    BuildContext context,
  ) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text('权限不足', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          '需要「显示在其他应用上层」权限才能显示爱心动画。\n\n'
          '请前往系统设置 → 应用管理 → 想你 → 权限，'
          '开启悬浮窗权限后重试。',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4081),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await requestPermission();
            },
            child: Text('去设置'),
          ),
        ],
      ),
    );
  }
}

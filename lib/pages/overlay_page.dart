// ============================================================
// 悬浮窗页面 OverlayPage
//
// 运行在独立 Flutter 引擎中（通过 overlayMain 入口启动）
//
// 功能：
//   1. 监听主 App 通过 shareData 发来的触发消息
//   2. 收到 'miss_you' 后播放爱心粒子动画
//   3. 动画内置震动效果
//   4. 动画完成或用户点击屏幕后自动关闭悬浮窗
//   5. 超时保护：5 秒后强制关闭（防止异常情况卡住）
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:logger/logger.dart';
import '../animations/heart_particle_animation.dart';

/// 悬浮窗页面 — 运行在独立 Flutter 引擎中
class OverlayPage extends StatefulWidget {
  const OverlayPage({super.key});

  @override
  State<OverlayPage> createState() => _OverlayPageState();
}

class _OverlayPageState extends State<OverlayPage> {
  final _log = Logger();
  StreamSubscription? _sub;
  Timer? _timeoutTimer;
  bool _showing = false;

  @override
  void initState() {
    super.initState();

    // 监听来自主 App 的数据
    _sub = FlutterOverlayWindow.overlayListener.listen((data) {
      _log.i('overlay received: $data, type: ${data.runtimeType}');
      
      // 处理不同类型的数据
      if (data is String) {
        if (data == 'miss_you' && !_showing) {
          _startAnimation();
        }
      } else if (data is Map) {
        // 如果发送的是 Map，可以在这里处理
        final type = data['type'];
        if (type == 'miss_you' && !_showing) {
          _startAnimation();
        }
      }
    });

    // 超时保护：10 秒后强制关闭悬浮窗
    // 防止因引擎启动延迟、数据丢失等异常导致悬浮窗卡住
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!_showing) {
        _log.w('timeout: no trigger received, closing overlay');
        FlutterOverlayWindow.closeOverlay();
      }
    });
  }

  /// 启动爱心动画
  void _startAnimation() {
    _timeoutTimer?.cancel();
    setState(() => _showing = true);
    _log.i('heart animation started');
  }

  /// 动画完成 — 关闭悬浮窗
  void _onAnimationComplete() {
    _log.i('heart animation completed, closing overlay');
    FlutterOverlayWindow.closeOverlay();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      // 透明背景，让动画自己绘制半透明蒙层
      color: Colors.transparent,
      child: GestureDetector(
        // 点击屏幕任意位置关闭悬浮窗
        onTap: () {
          _log.i('user tapped, closing overlay');
          FlutterOverlayWindow.closeOverlay();
        },
        child: _showing
            ? HeartAnimationWidget(
                // 爱心粒子动画组件
                // 内置震动 + 粒子爆发 + 呼吸缩放 + 淡入淡出
                duration: const Duration(milliseconds: 4000),
                particleCount: 60,
                enableVibration: true,
                onComplete: _onAnimationComplete,
              )
            : Container(color: Colors.transparent),
      ),
    );
  }
}

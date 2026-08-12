// ============================================================
// App 前后台状态检测
//
// 使用 WidgetsBindingObserver 监听 App 生命周期：
//   - resumed:   App 在前台，可见可交互
//   - inactive:  App 失去焦点（如来电、多任务切换中间态）
//   - paused:    App 在后台，不可见
//   - detached:  App 仍在运行但分离（罕见）
//
// 判定前台：resumed
// 判定后台：inactive / paused / detached
// ============================================================

import 'package:flutter/widgets.dart';

class AppLifecycleManager with WidgetsBindingObserver {
  AppLifecycleManager._();
  static final AppLifecycleManager instance = AppLifecycleManager._();

  AppLifecycleState _state = AppLifecycleState.resumed;

  /// App 是否在前台
  bool get isForeground => _state == AppLifecycleState.resumed;

  /// App 是否在后台
  bool get isBackground => !isForeground;

  /// 当前生命周期状态
  AppLifecycleState get state => _state;

  /// 开始监听
  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state = state;
  }
}

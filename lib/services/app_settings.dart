import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局应用设置 Provider
///
/// 管理用户可配置项：
/// - 爱心颜色（hex 字符串，如 "#ff69b4"）
/// - 震动开关
/// - WebSocket 地址
class AppSettings extends ChangeNotifier {
  static const _kHeartColor = 'heart_color';
  static const _kVibration = 'vibration_enabled';
  static const _kWsUrl = 'ws_url';

  String _heartColor = '#ff69b4';
  bool _vibrationEnabled = true;
  String _wsUrl = '';

  String get heartColor => _heartColor;
  bool get vibrationEnabled => _vibrationEnabled;
  String get wsUrl => _wsUrl;

  /// 将 hex 字符串转为 Color
  Color get heartColorValue {
    final hex = _heartColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  /// 从本地存储加载设置
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _heartColor = prefs.getString(_kHeartColor) ?? '#ff69b4';
    _vibrationEnabled = prefs.getBool(_kVibration) ?? true;
    _wsUrl = prefs.getString(_kWsUrl) ?? '';
    notifyListeners();
  }

  /// 设置爱心颜色
  Future<void> setHeartColor(String hex) async {
    _heartColor = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHeartColor, hex);
    notifyListeners();
  }

  /// 设置震动开关
  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVibration, enabled);
    notifyListeners();
  }

  /// 设置 WebSocket 地址
  Future<void> setWsUrl(String url) async {
    _wsUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWsUrl, url);
    notifyListeners();
  }
}

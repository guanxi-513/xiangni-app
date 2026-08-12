import 'package:shared_preferences/shared_preferences.dart';

/// 本地存储服务 — 保存 WebSocket 地址、配对码
class StorageService {
  static const _keyWsUrl = 'ws_url';
  static const _keyPairCode = 'pair_code';

  /// 获取 WebSocket 地址
  static Future<String> getWsUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWsUrl) ?? '';
  }

  /// 保存 WebSocket 地址
  static Future<void> setWsUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWsUrl, url);
  }

  /// 获取配对码
  static Future<String> getPairCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPairCode) ?? '';
  }

  /// 保存配对码
  static Future<void> setPairCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPairCode, code);
  }
}

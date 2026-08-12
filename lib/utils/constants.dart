/// 全局常量配置
class AppConstants {
  AppConstants._();

  /// WebSocket 服务器地址
  /// 本地调试时改为局域网 IP，例如 ws://192.168.1.100:8080
  /// 远程访问时改为 SakuraFrp 隧道地址
  static const String defaultWsUrl = 'ws://10.tcp.cpolar.top:12017';

  /// 应用名称
  static const String appName = '想你';

  /// 动画持续时间
  static const int animationDurationMs = 4000;

  /// 震动模式（等待，震动，等待，震动...）
  static const List<int> vibrationPattern = [0, 300, 100, 500, 100, 300];
}

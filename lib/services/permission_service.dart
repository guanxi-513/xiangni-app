// ============================================================
// 权限管理服务
//
// 功能：
//   1. 检测悬浮窗、通知、电池优化权限
//   2. 跳转系统设置页面引导开启权限
//   3. 检测设备制造商，显示品牌特有引导文案
//   4. 统一检测函数，返回权限状态结果
//
// 国产手机特殊权限说明：
//   小米/华为/OPPO/vivo 需要手动开启：
//   - 自启动权限
//   - 后台活动（后台弹出界面）
//   - 电池无限制（允许后台运行）
// ============================================================

import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:logger/logger.dart';

/// 权限状态结果
class PermissionStatusResult {
  final bool hasOverlay;           // 悬浮窗权限
  final bool hasNotification;      // 通知权限
  final bool hasBatteryOpt;        // 忽略电池优化
  final String? manufacturer;      // 设备制造商
  final bool needsOemGuidance;     // 是否需要国产ROM引导

  const PermissionStatusResult({
    required this.hasOverlay,
    required this.hasNotification,
    required this.hasBatteryOpt,
    this.manufacturer,
    this.needsOemGuidance = false,
  });

  /// 是否所有关键权限都已开启（含电池优化豁免，后台保活必需）
  bool get isAllGranted => hasOverlay && hasNotification && hasBatteryOpt;

  /// 是否缺少悬浮窗权限
  bool get missingOverlay => !hasOverlay;

  /// 是否缺少通知权限
  bool get missingNotification => !hasNotification;

  /// 是否缺少电池优化豁免
  bool get missingBatteryOpt => !hasBatteryOpt;
}

/// 设备制造商枚举
enum DeviceManufacturer {
  xiaomi,      // 小米
  huawei,      // 华为
  honor,       // 荣耀
  oppo,        // OPPO
  vivo,        // vivo
  oneplus,     // 一加
  meizu,       // 魅族
  samsung,     // 三星
  unknown,     // 未知
}

/// 权限服务
class PermissionService {
  static final _log = Logger();
  static final _deviceInfo = DeviceInfoPlugin();

  // ──────────────────────────────────────────────
  // 权限状态检测
  // ──────────────────────────────────────────────

  /// 检测悬浮窗权限状态
  static Future<bool> checkOverlay() async {
    try {
      final status = await perm.Permission.systemAlertWindow.status;
      return status.isGranted;
    } catch (e) {
      _log.e('checkOverlay error: $e');
      return false;
    }
  }

  /// 检测通知权限状态（Android 13+ 才有效）
  static Future<bool> checkNotification() async {
    try {
      final status = await perm.Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      _log.e('checkNotification error: $e');
      return false;
    }
  }

  /// 检测是否忽略电池优化
  static Future<bool> checkBatteryOptimization() async {
    try {
      final status = await perm.Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (e) {
      _log.e('checkBatteryOptimization error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────
  // 请求权限
  // ──────────────────────────────────────────────

  /// 请求悬浮窗权限
  static Future<bool> requestOverlay() async {
    try {
      final status = await perm.Permission.systemAlertWindow.request();
      _log.i('overlay permission: $status');
      return status.isGranted;
    } catch (e) {
      _log.e('requestOverlay error: $e');
      return false;
    }
  }

  /// 请求通知权限
  static Future<bool> requestNotification() async {
    try {
      final status = await perm.Permission.notification.request();
      _log.i('notification permission: $status');
      return status.isGranted;
    } catch (e) {
      _log.e('requestNotification error: $e');
      return false;
    }
  }

  /// 请求忽略电池优化
  ///
  /// 跳转系统电池优化设置页面，引导用户将 App 加入白名单。
  /// 这是保活的关键步骤 — 未豁免的 App 在 Doze 模式下会被限制网络和后台活动。
  static Future<bool> requestBatteryOptimization() async {
    try {
      final status = await perm.Permission.ignoreBatteryOptimizations.request();
      _log.i('battery optimization permission: $status');
      return status.isGranted;
    } catch (e) {
      _log.e('requestBatteryOptimization error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────
  // 跳转系统设置页面
  // ──────────────────────────────────────────────

  /// 打开应用设置页面（通用）
  static Future<void> openAppSettings() async {
    await perm.openAppSettings();
  }

  /// 打开悬浮窗权限设置页面
  /// 
  /// 悬浮窗权限无法通过代码直接授予，必须跳转系统设置手动开启
  static Future<void> openOverlaySettings() async {
    _log.i('opening overlay settings...');
    await perm.openAppSettings();
  }

  /// 打开通知权限设置页面
  static Future<void> openNotificationSettings() async {
    _log.i('opening notification settings...');
    await perm.openAppSettings();
  }

  /// 打开电池优化设置页面
  static Future<void> openBatteryOptimizationSettings() async {
    _log.i('opening battery optimization settings...');
    await perm.openAppSettings();
  }

  // ──────────────────────────────────────────────
  // 设备检测
  // ──────────────────────────────────────────────

  /// 检测设备制造商
  static Future<DeviceManufacturer> detectManufacturer() async {
    try {
      final androidInfo = await _deviceInfo.androidInfo;
      final manufacturer = androidInfo.manufacturer.toLowerCase();
      final brand = androidInfo.brand.toLowerCase();

      _log.i('device manufacturer: $manufacturer, brand: $brand');

      if (manufacturer.contains('xiaomi') || brand.contains('xiaomi') || brand.contains('redmi')) {
        return DeviceManufacturer.xiaomi;
      } else if (manufacturer.contains('huawei') || brand.contains('huawei')) {
        return DeviceManufacturer.huawei;
      } else if (manufacturer.contains('honor') || brand.contains('honor')) {
        return DeviceManufacturer.honor;
      } else if (manufacturer.contains('oppo') || brand.contains('oppo') || brand.contains('realme')) {
        return DeviceManufacturer.oppo;
      } else if (manufacturer.contains('vivo') || brand.contains('vivo') || brand.contains('iqoo')) {
        return DeviceManufacturer.vivo;
      } else if (manufacturer.contains('oneplus') || brand.contains('oneplus')) {
        return DeviceManufacturer.oneplus;
      } else if (manufacturer.contains('meizu') || brand.contains('meizu')) {
        return DeviceManufacturer.meizu;
      } else if (manufacturer.contains('samsung') || brand.contains('samsung')) {
        return DeviceManufacturer.samsung;
      }

      return DeviceManufacturer.unknown;
    } catch (e) {
      _log.e('detectManufacturer error: $e');
      return DeviceManufacturer.unknown;
    }
  }

  /// 是否为需要特殊引导的国产ROM
  static bool isChineseOem(DeviceManufacturer manufacturer) {
    return [
      DeviceManufacturer.xiaomi,
      DeviceManufacturer.huawei,
      DeviceManufacturer.honor,
      DeviceManufacturer.oppo,
      DeviceManufacturer.vivo,
      DeviceManufacturer.oneplus,
      DeviceManufacturer.meizu,
    ].contains(manufacturer);
  }

  /// 获取制造商中文名称
  static String getManufacturerName(DeviceManufacturer manufacturer) {
    switch (manufacturer) {
      case DeviceManufacturer.xiaomi:
        return '小米/红米';
      case DeviceManufacturer.huawei:
        return '华为';
      case DeviceManufacturer.honor:
        return '荣耀';
      case DeviceManufacturer.oppo:
        return 'OPPO/真我';
      case DeviceManufacturer.vivo:
        return 'vivo/iQOO';
      case DeviceManufacturer.oneplus:
        return '一加';
      case DeviceManufacturer.meizu:
        return '魅族';
      case DeviceManufacturer.samsung:
        return '三星';
      default:
        return '其他';
    }
  }

  // ──────────────────────────────────────────────
  // 国产ROM引导文案
  // ──────────────────────────────────────────────

  /// 获取国产ROM后台限制引导步骤
  static List<String> getOemGuidanceSteps(DeviceManufacturer manufacturer) {
    switch (manufacturer) {
      case DeviceManufacturer.xiaomi:
        return [
          '1. 打开【设置】→【应用设置】→【应用管理】→【想你】',
          '2. 点击【自启动】，开启允许自启动',
          '3. 点击【省电策略】，选择【无限制】',
          '4. 点击【后台弹出界面】，允许后台弹出',
          '5. 点击【显示在其他应用上层】，允许显示',
        ];
      case DeviceManufacturer.huawei:
      case DeviceManufacturer.honor:
        return [
          '1. 打开【手机管家】→【应用启动管理】',
          '2. 找到【想你】，开启【自动启动】和【关联启动】',
          '3. 打开【设置】→【电池和充电】→【启动管理】',
          '4. 找到【想你】，关闭【自动管理】，选择【允许后台活动】',
          '5. 在【手机管家】→【权限管理】中开启悬浮窗权限',
        ];
      case DeviceManufacturer.oppo:
        return [
          '1. 打开【设置】→【电池】→【应用耗电管理】',
          '2. 找到【想你】，开启【允许完全后台行为】',
          '3. 打开【设置】→【应用权限管理】→【想你】',
          '4. 开启【自启动】和【后台弹出界面】',
          '5. 在【安全中心】→【权限隐私】中开启悬浮窗',
        ];
      case DeviceManufacturer.vivo:
        return [
          '1. 打开【i管家】→【应用管理】→【自启动】',
          '2. 开启【想你】的自启动权限',
          '3. 打开【设置】→【电池】→【后台耗电管理】',
          '4. 找到【想你】，选择【允许后台高耗电】',
          '5. 在【i管家】→【权限管理】中开启悬浮窗',
        ];
      case DeviceManufacturer.oneplus:
        return [
          '1. 打开【设置】→【电池】→【应用耗电管理】',
          '2. 找到【想你】，开启【允许自启动】和【允许后台运行】',
          '3. 在【设置】→【权限管理】中开启悬浮窗权限',
        ];
      case DeviceManufacturer.meizu:
        return [
          '1. 打开【手机管家】→【权限管理】→【后台管理】',
          '2. 找到【想你】，开启【后台运行】和【自启动】',
          '3. 在【手机管家】→【耗电管理】中关闭省电限制',
          '4. 在【设置】→【应用管理】中开启悬浮窗权限',
        ];
      default:
        return [
          '1. 打开【设置】→【应用管理】→【想你】',
          '2. 开启【自启动】、【后台运行】、【悬浮窗】等权限',
          '3. 在【电池设置】中关闭对本应用的省电限制',
        ];
    }
  }

  // ──────────────────────────────────────────────
  // 统一检测函数
  // ──────────────────────────────────────────────

  /// 统一检测所有权限状态
  ///
  /// 返回 [PermissionStatusResult] 对象，包含：
  /// - hasOverlay: 悬浮窗权限
  /// - hasNotification: 通知权限
  /// - hasBatteryOpt: 电池优化豁免
  /// - manufacturer: 设备制造商
  /// - needsOemGuidance: 是否需要国产ROM引导
  static Future<PermissionStatusResult> checkAllPermissions() async {
    final hasOverlay = await checkOverlay();
    final hasNotification = await checkNotification();
    final hasBatteryOpt = await checkBatteryOptimization();
    final manufacturer = await detectManufacturer();

    return PermissionStatusResult(
      hasOverlay: hasOverlay,
      hasNotification: hasNotification,
      hasBatteryOpt: hasBatteryOpt,
      manufacturer: getManufacturerName(manufacturer),
      needsOemGuidance: isChineseOem(manufacturer),
    );
  }

  /// App启动时自动校验权限
  ///
  /// 调用 [checkAllPermissions] 并返回结果
  /// 如果有关键权限缺失，UI层应根据结果显示引导对话框
  static Future<PermissionStatusResult> autoCheckOnStart() async {
    _log.i('=== Auto check permissions on start ===');
    final result = await checkAllPermissions();

    _log.i('overlay: ${result.hasOverlay}');
    _log.i('notification: ${result.hasNotification}');
    _log.i('batteryOpt: ${result.hasBatteryOpt}');
    _log.i('manufacturer: ${result.manufacturer}');
    _log.i('needsOemGuidance: ${result.needsOemGuidance}');

    return result;
  }

  // ──────────────────────────────────────────────
  // 保活引导文案
  // ──────────────────────────────────────────────

  /// 获取保活限制说明文案
  ///
  /// 返回一段文字，告知用户后台保活的限制和解决方案。
  /// 适用于在设置页面或权限引导对话框中展示。
  static String getKeepAliveDisclaimer() {
    return '为保证及时收到「想你」消息，已开启后台保活服务。\n\n'
        '⚠️ 注意：\n'
        '• 国产深度定制系统（小米/华为/OPPO/vivo）会主动查杀后台进程，'
        '无法做到永久常驻。\n'
        '• 如果长时间未收到消息，可能是 App 被系统杀死，'
        '请重新打开 App 即可自动恢复连接。\n'
        '• 建议在系统设置中将本应用加入「自启动白名单」和「电池白名单」。';
  }

  /// 请求所有保活相关权限
  ///
  /// 依次请求：通知 → 电池优化 → 悬浮窗
  /// 返回 true 表示全部通过
  static Future<bool> requestAllKeepAlivePermissions() async {
    _log.i('requesting all keep-alive permissions...');

    final hasNotification = await requestNotification();
    _log.i('notification: $hasNotification');

    final hasBattery = await requestBatteryOptimization();
    _log.i('battery optimization: $hasBattery');

    final hasOverlay = await requestOverlay();
    _log.i('overlay: $hasOverlay');

    return hasNotification && hasBattery && hasOverlay;
  }
}

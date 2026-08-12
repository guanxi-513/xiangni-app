// ============================================================
// 权限引导对话框
//
// 功能：
//   1. 显示缺失的权限列表
//   2. 跳转系统设置页面
//   3. 显示国产ROM品牌特有的引导步骤
//   4. 支持重新检测权限状态
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/permission_service.dart';

/// 权限引导对话框
///
/// 在 App 启动时检测权限状态，如有缺失则显示此对话框引导用户开启
class PermissionGuideDialog extends StatefulWidget {
  final PermissionStatusResult status;
  final VoidCallback? onDismiss;
  final VoidCallback? onAllGranted;

  const PermissionGuideDialog({
    super.key,
    required this.status,
    this.onDismiss,
    this.onAllGranted,
  });

  @override
  State<PermissionGuideDialog> createState() => _PermissionGuideDialogState();
}

class _PermissionGuideDialogState extends State<PermissionGuideDialog> {
  late PermissionStatusResult _currentStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
  }

  /// 获取当前设备制造商（用于显示品牌引导文案）
  DeviceManufacturer? _getManufacturer() {
    if (_currentStatus.manufacturer == null) return null;

    for (final m in DeviceManufacturer.values) {
      if (PermissionService.getManufacturerName(m) == _currentStatus.manufacturer) {
        return m;
      }
    }
    return null;
  }

  /// 重新检测权限状态
  Future<void> _recheck() async {
    setState(() => _isLoading = true);
    final newStatus = await PermissionService.checkAllPermissions();
    setState(() {
      _currentStatus = newStatus;
      _isLoading = false;
    });

    if (newStatus.isAllGranted) {
      widget.onAllGranted?.call();
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// 打开悬浮窗权限设置
  Future<void> _openOverlaySettings() async {
    await PermissionService.openOverlaySettings();
  }

  /// 打开通知权限设置
  Future<void> _openNotificationSettings() async {
    await PermissionService.openNotificationSettings();
  }

  @override
  Widget build(BuildContext context) {
    final manufacturer = _getManufacturer();
    final showOemGuidance = _currentStatus.needsOemGuidance && manufacturer != null;

    return Dialog(
      backgroundColor: Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 标题 ──
            _buildHeader(),

            Flexible(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 20),
                shrinkWrap: true,
                children: [
                  // ── 权限状态列表 ──
                  _buildPermissionStatusList(),

                  // ── 国产ROM引导 ──
                  if (showOemGuidance) ...[
                    ..._buildOemGuidanceSection(),
                  ],

                  SizedBox(height: 20),

                  // ── 操作按钮 ──
                  _buildActions(),
                ],
              ),
            ),

            // ── 底部按钮 ──
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  /// 标题区域
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white10),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFFFF4081).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_outlined, color: Color(0xFFFF4081), size: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '权限设置',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '开启必要权限以保证正常使用',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 权限状态列表
  Widget _buildPermissionStatusList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          '必要权限',
          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 12),
        _buildPermissionItem(
          icon: Icons.layers,
          title: '悬浮窗权限',
          subtitle: '用于在其他应用之上显示爱心动画\n点击后请在系统设置中手动开启',
          isGranted: _currentStatus.hasOverlay,
          onTap: _openOverlaySettings,
        ),
        SizedBox(height: 8),
        _buildPermissionItem(
          icon: Icons.notifications,
          title: '通知权限',
          subtitle: '用于接收消息提醒',
          isGranted: _currentStatus.hasNotification,
          onTap: _openNotificationSettings,
        ),
        SizedBox(height: 8),
        _buildPermissionItem(
          icon: Icons.battery_charging_full,
          title: '忽略电池优化',
          subtitle: '防止系统杀后台导致动画丢失',
          isGranted: _currentStatus.hasBatteryOpt,
          onTap: PermissionService.openBatteryOptimizationSettings,
        ),
      ],
    );
  }

  /// 单个权限项
  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isGranted
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isGranted ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            isGranted ? Icons.check_circle : Icons.info_outline,
                            color: isGranted ? Colors.green : Colors.orange,
                            size: 14,
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white38,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建国产ROM引导区域（包装方法以解决类型推断问题）
  List<Widget> _buildOemGuidanceSection() {
    final manufacturer = _getManufacturer();
    if (manufacturer == null) return [];
    return [
      SizedBox(height: 20),
      _buildOemGuidance(manufacturer),
    ];
  }

  /// 国产ROM引导
  Widget _buildOemGuidance(DeviceManufacturer manufacturer) {
    final steps = PermissionService.getOemGuidanceSteps(manufacturer);
    final name = PermissionService.getManufacturerName(manufacturer);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFF9800).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFFF9800).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: Color(0xFFFF9800), size: 20),
              SizedBox(width: 8),
              Text(
                '$name 手机额外设置',
                style: TextStyle(
                  color: Color(0xFFFF9800),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '为确保后台稳定运行，请按以下步骤手动开启权限：',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: EdgeInsets.only(right: 10, top: 2),
                    decoration: BoxDecoration(
                      color: Color(0xFFFF9800),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      step.replaceFirst('${index + 1}. ', ''),
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 操作按钮区域
  Widget _buildActions() {
    return Text(
      '点击上方权限项跳转系统设置开启，开启后点击下方「重新检测」按钮',
      style: TextStyle(color: Colors.white38, fontSize: 12),
      textAlign: TextAlign.center,
    );
  }

  /// 底部按钮栏
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white10),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : () {
                widget.onDismiss?.call();
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white24),
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('稍后再说'),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _recheck,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF4081),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('重新检测'),
            ),
          ),
        ],
      ),
    );
  }
}

const _kPermissionGuideShown = 'permission_guide_shown';
const _kPermissionStatusCache = 'permission_status_cache';

/// 显示权限引导对话框的帮助函数
Future<void> showPermissionGuide(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final status = await PermissionService.autoCheckOnStart();

  if (!context.mounted) return;

  // 检查权限状态是否有变化（与上次缓存不同）
  final cacheKey = '${status.hasOverlay}_${status.hasNotification}_${status.hasBatteryOpt}_${status.needsOemGuidance}';
  final lastCache = prefs.getString(_kPermissionStatusCache);
  final statusChanged = cacheKey != lastCache;

  // 权限有缺失 或 需要 OEM 引导 且 (首次显示 或 状态有变化)
  final needsShow = (!status.isAllGranted || status.needsOemGuidance) &&
      (!prefs.containsKey(_kPermissionGuideShown) || statusChanged);

  if (needsShow) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionGuideDialog(
        status: status,
        onDismiss: () {
          // 用户点击稍后再说，记录标记
          prefs.setBool(_kPermissionGuideShown, true);
          prefs.setString(_kPermissionStatusCache, cacheKey);
        },
        onAllGranted: () {
          // 所有权限已开启，清除标记
          prefs.remove(_kPermissionGuideShown);
          prefs.remove(_kPermissionStatusCache);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('所有权限已开启 ✅')),
          );
        },
      ),
    );
  }
}

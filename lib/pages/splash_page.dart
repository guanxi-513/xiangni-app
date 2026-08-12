// ============================================================
// 启动 & 权限引导页
//
// 功能：
//   1. App 打开时自动检测权限（悬浮窗/通知/电池优化）
//   2. 权限缺失时显示引导对话框
//   3. 自动连接已保存的 WebSocket 地址
//   4. 根据连接/配对状态自动跳转到配对页或主页
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/permission_service.dart';
import '../services/app_settings.dart';
import '../services/websocket_service.dart';
import '../utils/constants.dart';
import '../widgets/permission_guide_dialog.dart';
import 'pairing_page.dart';
import 'home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final Animation<double> _fadeAnim;
  bool _checking = true;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnim = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn);
    _logoCtrl.forward();

    // 延迟一帧确保 Provider 就绪
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApp();
    });
  }

  /// 初始化流程：加载设置 → 检测权限 → 自动连接
  Future<void> _initApp() async {
    // 1. 加载本地设置
    if (!mounted) return;
    final settings = context.read<AppSettings>();
    final ws = context.read<WebSocketService>();
    await settings.load();
    await ws.loadSavedIds();

    // 2. 检测权限
    final status = await PermissionService.autoCheckOnStart();

    if (!mounted) return;

    // 3. 权限缺失或需要 OEM 引导 → 显示对话框
    if (!status.isAllGranted || status.needsOemGuidance) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PermissionGuideDialog(
          status: status,
          onDismiss: () {
            // 用户点击稍后再说，继续进入 App
            _autoConnectAndNavigate();
          },
          onAllGranted: () {
            Navigator.pop(context);
            _autoConnectAndNavigate();
          },
        ),
      );
    } else {
      // 权限齐全，直接连接
      _autoConnectAndNavigate();
    }
  }

  /// 自动连接 WebSocket 并跳转
  ///
  /// 强绑定逻辑：
  /// - 如果本地有已保存的对方配对码 → 直接进主页（服务端会自动恢复配对）
  /// - 如果没有 → 进配对页（首次使用）
  void _autoConnectAndNavigate() {
    final settings = context.read<AppSettings>();
    final ws = context.read<WebSocketService>();

    // 使用已保存的地址或默认地址
    final url = settings.wsUrl.isEmpty
        ? AppConstants.defaultWsUrl
        : settings.wsUrl;

    ws.connect(url);

    // 延迟跳转，让连接状态更新
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _checking = false);

      // 强绑定：有配对记录 → 直接进主页，服务端自动恢复配对
      final hasPartner = ws.partnerPairCode.isNotEmpty;
      final destination = hasPartner ? const HomePage() : const PairingPage();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );

      // ══════════════════════════════════════════════
      //  处理 App 被杀死后通过通知冷启动的场景：
      //  NotificationService.initialize() 时已把 payload 存到 pendingMissYouColor，
      //  导航完成、UI 就绪后检查并触发爱心动画
      // ══════════════════════════════════════════════
      Future.delayed(const Duration(milliseconds: 1200), () {
        ws.checkPendingMissYou();
      });
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo 爱心 ──
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0xFFFF6B9D), Color(0xFFFF1744)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFF4081).withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(Icons.favorite, color: Colors.white, size: 48),
                  ),
                ),
                const SizedBox(height: 24),
                // ── App 名称 ──
                Text(
                  '想 你',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 12,
                  ),
                ),
                const SizedBox(height: 40),
                // ── 加载指示器 ──
                if (_checking)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFF4081).withValues(alpha: 0.6),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  _checking ? '正在检查权限...' : '准备就绪',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

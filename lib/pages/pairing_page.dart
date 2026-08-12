// ============================================================
// 配对页面
//
// 功能：
//   1. 生成 6 位配对码，保存到本地
//   2. 输入对方配对码，建立两台设备绑定关系
//   3. 配对成功后自动跳转到主页
//   4. 显示实时连接状态
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/websocket_service.dart';
import 'home_page.dart';

class PairingPage extends StatefulWidget {
  const PairingPage({super.key});

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final _pairInputCtrl = TextEditingController();
  WebSocketService? _wsRef;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // 监听配对状态，配对成功自动跳转主页
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wsRef = context.read<WebSocketService>();
      _wsRef?.addListener(_onStatusChanged);
      // 如果进来时已经配对，立即跳转
      if ((_wsRef?.isPaired ?? false) && !_navigated) {
        _navigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          }
        });
      }
    });
  }

  void _onStatusChanged() {
    // 先判断 mounted，避免 State 已销毁却访问 context
    if (!mounted || _navigated) return;
    final ws = _wsRef ?? context.read<WebSocketService>();
    if (ws.isPaired) {
      _navigated = true;
      // 跳主页（用直接构造，避免命名路由的上下文时机问题）
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    }
  }

  void _generatePairCode() {
    final code = (100000 + Random().nextInt(900000)).toString();
    context.read<WebSocketService>().registerCode(code);
    setState(() {});
  }

  void _pairWith() {
    final code = _pairInputCtrl.text.trim();
    if (code.length != 6) return;
    context.read<WebSocketService>().pairWith(code);
    // 清空输入
    _pairInputCtrl.clear();
  }

  @override
  void dispose() {
    // 安全移除监听
    try {
      _wsRef?.removeListener(_onStatusChanged);
    } catch (_) {}
    _pairInputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: SafeArea(
          child: Consumer<WebSocketService>(
            builder: (context, ws, _) {
              return Column(
                children: [
                  _buildAppBar(ws),
                  Expanded(
                    child: ws.isPaired
                        ? _buildPairedSuccess(ws)
                        : _buildPairingContent(ws),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 顶部导航栏
  Widget _buildAppBar(WebSocketService ws) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios, color: Colors.white70, size: 22),
          ),
          const SizedBox(width: 8),
          Text(
            '配对',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w300,
              letterSpacing: 4,
            ),
          ),
          const Spacer(),
          // 连接状态指示
          _buildStatusDot(ws),
          const SizedBox(width: 12),
          // 设置按钮
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (ctx) => const SettingsSheet(),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.settings, color: Colors.white70, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  /// 连接状态小圆点
  Widget _buildStatusDot(WebSocketService ws) {
    final (color, text) = switch (ws.status) {
      ConnectStatus.disconnected => (Colors.grey, '未连接'),
      ConnectStatus.connecting => (Colors.orange, '连接中'),
      ConnectStatus.connected => (Colors.blue, '已连接'),
      ConnectStatus.paired => (Color(0xFFFF4081), '已配对'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  /// 配对主体内容
  Widget _buildPairingContent(WebSocketService ws) {
    final connected = ws.isConnected;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // ── 爱心图标 ──
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFF4081).withValues(alpha: 0.15),
            ),
            child: Icon(Icons.favorite, color: Color(0xFFFF6B9D), size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            '绑定你们的两台手机',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            connected ? '在两台设备上分别操作以下步骤' : '正在连接服务器...',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 32),

          // ── 步骤 1：生成配对码 ──
          _buildStepCard(
            step: '1',
            title: '我的配对码',
            child: ws.pairCode.isEmpty
                ? ElevatedButton(
                    onPressed: connected ? _generatePairCode : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4081),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text('生成配对码'),
                  )
                : _buildPairCodeDisplay(ws.pairCode),
          ),

          const SizedBox(height: 24),

          // ── 步骤 2：输入对方配对码 ──
          _buildStepCard(
            step: '2',
            title: '输入对方配对码',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pairInputCtrl,
                    style: const TextStyle(
                      color: Colors.white,
                      letterSpacing: 8,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '• • • • • •',
                      hintStyle: TextStyle(
                        color: Colors.white24,
                        letterSpacing: 8,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF4081),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: connected ? _pairWith : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: connected
                          ? const LinearGradient(
                              colors: [Color(0xFFFF6B9D), Color(0xFFFF1744)],
                            )
                          : null,
                      color: connected ? null : Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '绑定',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── 提示文字 ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.white38, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '两台手机都需要安装本 App 并连接同一服务器。\n'
                    'A 手机生成配对码，B 手机输入该码完成绑定。',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 步骤卡片
  Widget _buildStepCard({
    required String step,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B9D), Color(0xFFFF1744)],
                  ),
                ),
                child: Center(
                  child: Text(
                    step,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(child: child),
        ],
      ),
    );
  }

  /// 配对码展示
  Widget _buildPairCodeDisplay(String code) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          decoration: BoxDecoration(
            color: Color(0xFFFF4081).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFFFF4081).withValues(alpha: 0.3)),
          ),
          child: Text(
            code,
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.content_copy, color: Colors.white38, size: 14),
            const SizedBox(width: 4),
            Text(
              '将此号码告诉对方',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  /// 配对成功展示
  Widget _buildPairedSuccess(WebSocketService ws) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 成功动画
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 600),
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
                    color: Color(0xFFFF4081).withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(Icons.favorite, color: Colors.white, size: 50),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '配对成功',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w300,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '你们已绑定 ❤',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4081),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text('进入主页'),
          ),
        ],
      ),
    );
  }
}

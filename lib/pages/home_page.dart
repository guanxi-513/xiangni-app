// ============================================================
// 主页
//
// 功能：
//   1. 超大圆形【想你】按钮，带脉冲动画
//   2. 设置面板：自定义爱心颜色、开关震动、服务器地址
//   3. 连接状态实时显示
//   4. 断开连接回到配对页
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/websocket_service.dart';
import '../services/app_settings.dart';
import '../services/overlay_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../widgets/miss_you_button.dart';
import '../animations/heart_particle_animation.dart';
import 'animation_test_page.dart';
import 'pairing_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _sending = false;
  bool _hasOverlayPermission = true;
  // 主 App 内降级动画（当悬浮窗显示失败或 App 在前台时显示的覆盖层）
  Color? _inAppAnimColor;
  bool _showInAppAnimation = false;
  StreamSubscription? _missYouSub;

  // ── 文字聊天 ──
  final List<ChatMessage> _messages = [];
  StreamSubscription? _textMsgSub;
  final ScrollController _chatScrollCtrl = ScrollController();
  final TextEditingController _inputCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    // 监听 missYouStream，overlay 失败时主 App 降级为全屏动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ws = context.read<WebSocketService>();
      // 1. 加载已有的最近消息（已按 timestamp 排序 + 去重）
      if (ws.recentMessages.isNotEmpty) {
        setState(() {
          _messages
            ..clear()
            ..addAll(ws.recentMessages);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
      // 2. 订阅新消息 → 保持列表排序，避免旧消息乱插入
      _textMsgSub = ws.textMessageStream.listen((msg) {
        if (!mounted) return;
        setState(() {
          // 先去重：如果 _messages 已包含同一条就跳过
          final exist = _messages.any((m) => m.dedupKey == msg.dedupKey);
          if (!exist) _messages.add(msg);
          // 按 timestamp 升序（保证乱序到达时仍按时间顺序显示，时间同步问题解决！）
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      });
      _missYouSub = ws.missYouStream.listen((color) {
        if (!mounted) return;
        _logMissYouInApp(color);
        setState(() {
          _inAppAnimColor = color;
          _showInAppAnimation = true;
        });
      });
    });
  }

  @override
  void dispose() {
    _missYouSub?.cancel();
    _missYouSub = null;
    _textMsgSub?.cancel();
    _textMsgSub = null;
    _chatScrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  /// 滚到聊天列表底部
  void _scrollToBottom() {
    if (!_chatScrollCtrl.hasClients) return;
    final max = _chatScrollCtrl.position.maxScrollExtent;
    _chatScrollCtrl.animateTo(
      max,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _logMissYouInApp(Color color) {
    // 仅在 overlay 失败时走此路径，用户仍能看到动画
  }

  /// 检查关键权限状态
  void _checkPermissions() async {
    final hasOverlay = await OverlayService.hasPermission();
    if (mounted) {
      setState(() => _hasOverlayPermission = hasOverlay);
    }
  }

  void _sendMissYou() async {
    if (_sending) return;

    // 权限检查：悬浮窗权限缺失时提示用户
    if (!_hasOverlayPermission) {
      _showPermissionWarning();
      return;
    }

    setState(() => _sending = true);

    final ws = context.read<WebSocketService>();
    final settings = context.read<AppSettings>();

    // 连接状态检查
    if (!ws.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('正在连接服务器，请稍候...'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
      setState(() => _sending = false);
      return;
    }

    // 配对状态检查
    if (!ws.isPaired) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('尚未配对，请先完成配对'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
      setState(() => _sending = false);
      return;
    }

    final success = ws.sendMissYou(color: settings.heartColor);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '已发送想你~' : '发送失败，请检查连接'),
          duration: const Duration(seconds: 2),
          backgroundColor: success ? const Color(0xFFFF4081) : Colors.orange,
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _sending = false);
  }

  /// 显示权限缺失警告
  void _showPermissionWarning() {
    showDialog(
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
          '需要「悬浮窗」权限才能在对方手机显示爱心动画。\n\n'
          '请前往系统设置开启权限后重试。',
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
              await OverlayService.requestPermission();
              // 用户返回后重新检查
              _checkPermissions();
            },
            child: Text('去设置'),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const SettingsSheet(),
    );
  }

  /// 解除绑定确认对话框
  void _showUnbindConfirm(WebSocketService ws) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.link_off, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text('解除绑定', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          '解除后将不再接收对方的「想你」消息。\n\n'
          '如需重新绑定，需要重新输入配对码。',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ws.unbind();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/pairing',
                  (route) => false,
                );
              }
            },
            child: Text('确认解除'),
          ),
        ],
      ),
    );
  }

  /// 主 App 降级动画结束回调
  void _onInAppAnimComplete() {
    if (mounted) {
      setState(() => _showInAppAnimation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Consumer2<WebSocketService, AppSettings>(
                builder: (context, ws, settings, _) {
                  return Column(
                    children: [
                      _buildAppBar(ws),
                      Expanded(child: _buildContent(ws, settings)),
                    ],
                  );
                },
              ),
              // 降级动画覆盖层（当悬浮窗权限缺失时，也能看到爱心动画）
              if (_showInAppAnimation && _inAppAnimColor != null)
                Positioned.fill(
                  child: HeartAnimationWidget(
                    key: ValueKey(
                      'appanim_${_inAppAnimColor!.toARGB32()}_${DateTime.now().millisecondsSinceEpoch}',
                    ),
                    centerHeartColors: [
                      _inAppAnimColor!,
                      _inAppAnimColor!.withValues(alpha: 1),
                    ],
                    particleColors: [
                      _inAppAnimColor!,
                      Colors.white,
                      _inAppAnimColor!.withRed(255),
                      const Color(0xFFFFB6C1),
                    ],
                    enableVibration: true,
                    onComplete: _onInAppAnimComplete,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部导航
  Widget _buildAppBar(WebSocketService ws) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // 设置按钮
          GestureDetector(
            onTap: _showSettingsSheet,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.settings, color: Colors.white70, size: 22),
            ),
          ),
          const Spacer(),
          // 状态指示
          _buildStatusChip(ws),
          const Spacer(),
          // 动画预览
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnimationTestPage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border,
                color: Colors.white70,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 状态指示器
  Widget _buildStatusChip(WebSocketService ws) {
    final (color, text) = switch (ws.status) {
      ConnectStatus.disconnected => (Colors.grey, '未连接'),
      ConnectStatus.connecting => (Colors.orange, '连接中'),
      ConnectStatus.connected => (Colors.blue, '待配对'),
      ConnectStatus.paired => (const Color(0xFFFF4081), '已配对'),
    };

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/pairing'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: color, size: 8),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  /// 主体内容
  Widget _buildContent(WebSocketService ws, AppSettings settings) {
    // 连接中或已连接但未配对 → 显示友好界面 + 去配对入口，避免黑屏
    if (!ws.isPaired) {
      return _buildNotPairedView(ws);
    }

    return Column(
      children: [
        // ── 上半：想你按钮区（主角，视觉重心） ──
        Expanded(
          flex: 5,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // ── 超大想你按钮 ──
                MissYouButton(
                  onPressed: _sendMissYou,
                  enabled: !_sending,
                  color: settings.heartColorValue,
                ),

                const SizedBox(height: 24),

                // ── 提示文字 ──
                Text(
                  _sending ? '发送中...' : '点击发送「想你」',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                    letterSpacing: 2,
                  ),
                ),

                const Spacer(flex: 1),

                // ── 底部操作 ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/pairing'),
                      icon: Icon(Icons.link, color: Colors.white38, size: 18),
                      label: Text(
                        '配对码',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showUnbindConfirm(ws),
                      icon: Icon(Icons.link_off, color: Colors.white38, size: 18),
                      label: Text(
                        '解除绑定',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),

        // ── 下半：聊天消息面板 ──
        _buildChatPanel(ws),
      ],
    );
  }

  // ══════════════════════════════════════════════
  //  聊天 UI
  // ══════════════════════════════════════════════

  /// 聊天面板：消息列表 + 输入框
  Widget _buildChatPanel(WebSocketService ws) {
    return Container(
      height: 240,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          // ── 头部标题 ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4081).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: const Color(0xFFFF6B9D),
                ),
                const SizedBox(width: 6),
                Text(
                  '悄悄话',
                  style: TextStyle(
                    color: const Color(0xFFFF6B9D),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (_messages.isNotEmpty)
                  Text(
                    '${_messages.length} 条消息',
                    style: TextStyle(color: Colors.white30, fontSize: 11),
                  ),
              ],
            ),
          ),
          // ── 消息列表 ──
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyChatTip()
                : ListView.builder(
                    controller: _chatScrollCtrl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, idx) {
                      final msg = _messages[idx];
                      return _buildChatBubble(msg);
                    },
                  ),
          ),
          // ── 输入框 ──
          _buildInputBar(ws),
        ],
      ),
    );
  }

  /// 空状态提示
  Widget _buildEmptyChatTip() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.message_outlined, color: Colors.white12, size: 28),
          const SizedBox(height: 6),
          Text(
            '还没有消息，打个招呼吧 ~',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 单条聊天气泡
  Widget _buildChatBubble(ChatMessage msg) {
    final isMine = msg.isMine;
    final bg = isMine
        ? const Color(0xFFFF4081).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.08);
    final fg = isMine ? Colors.white : Colors.white;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleAlign = isMine ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: bubbleAlign,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: align,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                msg.content,
                style: TextStyle(color: fg, fontSize: 14),
                softWrap: true,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(msg.timestamp),
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  /// 输入框 + 发送按钮
  Widget _buildInputBar(WebSocketService ws) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              style: TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 1,
              maxLength: 200,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendTextMessage(ws),
              decoration: InputDecoration(
                isDense: true,
                hintText: '给 TA 发句话...',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                counterText: '',
                fillColor: Colors.white.withValues(alpha: 0.04),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: const Color(0xFFFF4081).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendTextMessage(ws),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF4081), Color(0xFFFF6B9D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4081).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 发送文字消息
  void _sendTextMessage(WebSocketService ws) {
    final text = _inputCtrl.text;
    if (text.trim().isEmpty) return;
    final ok = ws.sendTextMessage(text);
    if (ok) {
      _inputCtrl.clear();
      FocusScope.of(context).unfocus();
    }
  }

  /// 时间戳 → HH:mm 格式化
  static String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 未配对视图
  Widget _buildNotPairedView(WebSocketService ws) {
    // 强绑定模式：有对方配对码但未配对 → 等待对方上线
    final isWaitingForPartner =
        ws.partnerPairCode.isNotEmpty && ws.status != ConnectStatus.paired;

    final (statusColor, statusText) = switch (ws.status) {
      ConnectStatus.disconnected => (Colors.grey, '未连接服务器'),
      ConnectStatus.connecting => (Colors.orange, '正在连接服务器...'),
      ConnectStatus.connected =>
        isWaitingForPartner
            ? (Colors.blue, '等待对方上线...')
            : (Colors.blue, '已连接，请先配对'),
      ConnectStatus.paired => (const Color(0xFFFF4081), '已配对'),
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 连接状态指示（避免黑屏，页面始终有内容）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: statusColor, size: 10),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Icon(
            isWaitingForPartner ? Icons.hourglass_top : Icons.link_off,
            size: 56,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            isWaitingForPartner ? '等待对方上线' : '尚未配对',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            isWaitingForPartner ? '对方打开 App 后将自动恢复连接' : '请先完成配对后再使用',
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // 返回配对页（用 push 避免主页/配对页切换黑屏）
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PairingPage()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4081),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: const Icon(Icons.link, size: 18),
            label: const Text('去配对'),
          ),

          // 权限缺失提示
          if (!_hasOverlayPermission) ...[
            const SizedBox(height: 32),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '悬浮窗权限未开启，可能无法看到爱心动画',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showPermissionWarning(),
                    child: const Text(
                      '开启',
                      style: TextStyle(
                        color: Color(0xFFFF4081),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// 设置面板（BottomSheet）
// ============================================================

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late TextEditingController _wsUrlCtrl;
  bool _hasNotificationPerm = true;
  bool _hasOverlayPerm = true;

  // 预设颜色
  static const _presetColors = [
    {'name': '浪漫粉', 'hex': '#ff69b4'},
    {'name': '热烈红', 'hex': '#ff1744'},
    {'name': '玫红', 'hex': '#ff4081'},
    {'name': '梦幻紫', 'hex': '#9c27b0'},
    {'name': '天蓝', 'hex': '#2196f3'},
    {'name': '橙色', 'hex': '#ff9800'},
    {'name': '薄荷', 'hex': '#4caf50'},
    {'name': '白色', 'hex': 'ffffff'},
  ];

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppSettings>();
    _wsUrlCtrl = TextEditingController(text: settings.wsUrl);
    _refreshPermStatus();
  }

  @override
  void dispose() {
    _wsUrlCtrl.dispose();
    super.dispose();
  }

  /// 刷新权限状态
  Future<void> _refreshPermStatus() async {
    final notif = await NotificationService.hasPermission();
    final overlay = await OverlayService.hasPermission();
    if (mounted) {
      setState(() {
        _hasNotificationPerm = notif;
        _hasOverlayPerm = overlay;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖拽指示器
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 标题
          Text(
            '设置',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w300,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 24),

          // ── 爱心颜色 ──
          _buildSectionTitle('爱心颜色'),
          const SizedBox(height: 12),
          Consumer<AppSettings>(
            builder: (context, settings, _) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _presetColors.map((preset) {
                  final hex = preset['hex']!;
                  final color = Color(
                    int.parse('FF${hex.replaceAll('#', '')}', radix: 16),
                  );
                  final selected = settings.heartColor == hex;
                  return GestureDetector(
                    onTap: () => settings.setHeartColor(hex),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: selected
                          ? Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 28),

          // ── 震动开关 ──
          Consumer<AppSettings>(
            builder: (context, settings, _) {
              return _buildSwitchRow(
                icon: Icons.vibration,
                title: '震动反馈',
                subtitle: '收到爱心时手机震动',
                value: settings.vibrationEnabled,
                onChanged: settings.setVibrationEnabled,
              );
            },
          ),

          const SizedBox(height: 20),

          // ── 权限快捷检查 ──
          _buildSectionTitle('权限状态'),
          const SizedBox(height: 12),
          _buildPermRow(
            icon: Icons.notifications,
            title: '通知权限',
            subtitle: _hasNotificationPerm ? '已开启' : '未开启，后台收不到消息提醒',
            ok: _hasNotificationPerm,
            onTap: () async {
              if (_hasNotificationPerm) return;
              await PermissionService.requestNotification();
              _refreshPermStatus();
            },
          ),
          const SizedBox(height: 8),
          _buildPermRow(
            icon: Icons.layers,
            title: '悬浮窗权限',
            subtitle: _hasOverlayPerm ? '已开启' : '未开启，无法弹出爱心动画',
            ok: _hasOverlayPerm,
            onTap: () async {
              if (_hasOverlayPerm) return;
              await OverlayService.requestPermission();
              _refreshPermStatus();
            },
          ),

          const SizedBox(height: 24),

          // ── 服务器地址 ──
          _buildSectionTitle('服务器地址'),
          const SizedBox(height: 8),
          TextField(
            controller: _wsUrlCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ws://IP:端口',
              hintStyle: TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFFF4081)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 保存按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final url = _wsUrlCtrl.text.trim();
                final settings = context.read<AppSettings>();
                final oldUrl = settings.wsUrl;
                settings.setWsUrl(url);

                // 服务器地址变更 → 自动重连
                if (url != oldUrl && url.isNotEmpty) {
                  final ws = context.read<WebSocketService>();
                  ws.disconnect();
                  ws.connect(url);
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(url != oldUrl ? '设置已保存，正在重新连接...' : '设置已保存'),
                    backgroundColor: Color(0xFFFF4081),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4081),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('保存设置'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFFFF6B9D), size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFFFF4081),
          ),
        ],
      ),
    );
  }

  /// 权限状态行（点击可跳转开启）
  Widget _buildPermRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool ok,
    required VoidCallback onTap,
  }) {
    final bgColor = ok
        ? Colors.green.withValues(alpha: 0.08)
        : Colors.orange.withValues(alpha: 0.08);
    final borderColor = ok
        ? Colors.green.withValues(alpha: 0.2)
        : Colors.orange.withValues(alpha: 0.2);
    final accent = ok ? Colors.green : Colors.orange;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          ok ? Icons.check_circle : Icons.warning_amber,
                          color: accent,
                          size: 14,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!ok)
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white38,
                  size: 14,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// WebSocket 网络服务
//
// 核心功能：
//  1. 连接成功 → 立即发送 register（如有 pairCode），再触发 pair 恢复
//  2. missYouStream — 主 App 监听后可降级为页面动画
//  3. 前后台分流：
//     - 前台收到 miss_you → 直接弹悬浮窗
//     - 后台收到 miss_you → 弹高优先级本地通知，用户点击后唤醒 App 弹爱心
//  4. 强绑定：miss_you 按对方配对码路由，不依赖易变的 deviceId
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'overlay_service.dart';
import 'foreground_service_util.dart';
import 'app_lifecycle_manager.dart';
import 'notification_service.dart';

/// 连接状态
enum ConnectStatus {
  disconnected, // 未连接
  connecting, // 连接中
  connected, // 已连接，等待配对
  paired, // 已配对
}

/// 收到的消息体
class WsMessage {
  final String type;
  final Map<String, dynamic> data;

  WsMessage(this.type, this.data);

  factory WsMessage.fromJson(Map<String, dynamic> json) {
    return WsMessage(json['type'] as String, json);
  }
}

/// 聊天文字消息（UI 层展示用）
class ChatMessage {
  final String content;
  final bool isMine;       // true = 我发的，false = 对方发的
  final int timestamp;
  final bool sentOk;       // 发送方 ack 确认

  const ChatMessage({
    required this.content,
    required this.isMine,
    required this.timestamp,
    this.sentOk = true,
  });

  // ── JSON 序列化（用于持久化） ──
  Map<String, dynamic> toJson() => {
    'content': content,
    'isMine': isMine,
    'timestamp': timestamp,
    'sentOk': sentOk,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    content: json['content'] as String? ?? '',
    isMine: json['isMine'] as bool? ?? false,
    timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    sentOk: json['sentOk'] as bool? ?? true,
  );

  /// 去重 key：同一人 + 同一时间 + 同一内容 = 同一条
  String get dedupKey => '${isMine ? 'M' : 'T'}|$timestamp|${content.hashCode}';
}

/// WebSocket 服务
class WebSocketService extends ChangeNotifier {
  final _log = Logger();

  /// 静态实例引用，供通知回调等外部场景访问
  static WebSocketService? instance;

  /// 全局 NavigatorKey — 由 main.dart 注入
  /// 用于点击通知后在无 context 的情况下跳转到主页
  GlobalKey<NavigatorState>? navigatorKey;

  // ── 内部状态 ──
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  WebSocketService() {
    instance = this;
  }

  ConnectStatus _status = ConnectStatus.disconnected;
  String _deviceId = '';
  String _partnerId = '';
  String _pairCode = '';
  String _partnerPairCode = ''; // 对方的配对码（用于恢复配对）
  String _wsUrl = '';

  // ── 自动重连 ──
  bool _manualDisconnect = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const int _maxReconnectAttempts = 9999; // 始终尝试重连
  static const Duration _baseReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);

  // ── 心跳检测 ──
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  DateTime? _lastMessageTime;

  // ── 消息广播 ──
  final _msgController = StreamController<WsMessage>.broadcast();
  Stream<WsMessage> get messageStream => _msgController.stream;

  // ── 想你触发广播（给主 App 用，overlay 失败时降级弹出页面动画）──
  final _missYouCtrl = StreamController<Color>.broadcast();
  Stream<Color> get missYouStream => _missYouCtrl.stream;

  // ── 文字消息广播（给主 App 聊天 UI 展示）──
  final _textMsgCtrl = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get textMessageStream => _textMsgCtrl.stream;
  // 内存保留最近 N 条（防止用户晚进入主页看不到聊天记录）
  final List<ChatMessage> recentMessages = [];
  static const int _maxRecentMessages = 100;

  // ── 本地存储 key ──
  static const _kDeviceId = 'ws_device_id';
  static const _kPartnerId = 'ws_partner_id';
  static const _kPairCode = 'ws_pair_code';
  static const _kPartnerCode = 'ws_partner_code';
  static const _kChatMessages = 'ws_chat_messages';

  // ══════════════════════════════════════════════
  //  Getters
  // ══════════════════════════════════════════════

  ConnectStatus get status => _status;
  String get deviceId => _deviceId;
  String get partnerId => _partnerId;
  String get pairCode => _pairCode;
  String get partnerPairCode => _partnerPairCode;
  String get wsUrl => _wsUrl;

  bool get isConnected =>
      _status == ConnectStatus.connected || _status == ConnectStatus.paired;
  bool get isPaired => _status == ConnectStatus.paired;

  // ══════════════════════════════════════════════
  //  本地存储
  // ══════════════════════════════════════════════

  /// 从本地存储加载已保存的 ID / 配对码 / 聊天记录
  Future<void> loadSavedIds() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_kDeviceId) ?? '';
    _partnerId = prefs.getString(_kPartnerId) ?? '';
    _pairCode = prefs.getString(_kPairCode) ?? '';
    _partnerPairCode = prefs.getString(_kPartnerCode) ?? '';

    // 加载聊天记录（如有）
    final chatRaw = prefs.getString(_kChatMessages);
    if (chatRaw != null && chatRaw.isNotEmpty) {
      try {
        final list = jsonDecode(chatRaw) as List<dynamic>;
        recentMessages
          ..clear()
          ..addAll(list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)));
        // 加载后排序 + 裁剪
        _sortAndTrimMessages();
        _log.i('loaded ${recentMessages.length} chat messages from storage');
      } catch (e) {
        _log.w('load chat messages failed: $e');
      }
    }

    _log.i(
      'loaded: device=$_deviceId, partner=$_partnerId, '
      'pairCode=$_pairCode, partnerCode=$_partnerPairCode',
    );
  }

  Future<void> _saveDeviceId(String id) async {
    _deviceId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDeviceId, id);
    _log.i('saved deviceId=$id');
  }

  Future<void> _savePartnerId(String id) async {
    _partnerId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPartnerId, id);
    _log.i('saved partnerId=$id');
  }

  Future<void> _savePairCode(String code) async {
    _pairCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPairCode, code);
    _log.i('saved pairCode=$code');
  }

  Future<void> _savePartnerCode(String code) async {
    _partnerPairCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPartnerCode, code);
    _log.i('saved partnerCode=$code');
  }

  /// 清除本地所有配对信息（断开/重配对时调用）
  Future<void> clearSavedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDeviceId);
    await prefs.remove(_kPartnerId);
    await prefs.remove(_kPartnerCode);
    _deviceId = '';
    _partnerId = '';
    _partnerPairCode = '';
    _log.i('cleared saved ids (pairCode retained for local ref: $_pairCode)');
  }

  // ══════════════════════════════════════════════
  //  连接 / 断开
  // ══════════════════════════════════════════════

  Future<void> connect(String url) async {
    if (_status == ConnectStatus.connecting) {
      _log.w('already connecting, skip');
      return;
    }

    _wsUrl = url;
    _manualDisconnect = false;
    _reconnectAttempts = 0;
    _setStatus(ConnectStatus.connecting);

    _log.i('connecting to $url ...');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _sub = _channel!.stream.listen(
        _onData,
        onError: (e) => _onError('stream error: $e'),
        onDone: _onDone,
      );
      _startHeartbeat();
      _log.i('channel created, heartbeat started');
    } catch (e, stack) {
      _log.e('connect failed: $e\n$stack');
      _scheduleReconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _lastMessageTime = DateTime.now();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_lastMessageTime == null) return;
      final elapsed = DateTime.now().difference(_lastMessageTime!);
      _log.d('heartbeat: last msg ${elapsed.inSeconds}s ago');
      if (elapsed > const Duration(seconds: 60)) {
        _log.w('heartbeat timeout (${elapsed.inSeconds}s), forcing reconnect');
        _heartbeatTimer?.cancel();
        _forceReconnect();
      } else {
        try {
          _send({'type': 'ping'});
        } catch (e) {
          _log.e('heartbeat send failed: $e');
        }
      }
    });
  }

  void _forceReconnect() {
    _log.w('force reconnect');
    try {
      _sub?.cancel();
      _sub = null;
      _channel?.sink.close();
      _channel = null;
    } catch (e) {
      _log.e('force reconnect cleanup error: $e');
    }
    _scheduleReconnect();
  }

  /// 手动断开
  void disconnect() {
    _log.i('manual disconnect');
    _manualDisconnect = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    // 手动断开时清空当前会话临时配对状态（不清理 pairCode）
    _partnerId = '';
    _partnerPairCode = '';
    ForegroundServiceUtil.stopService();
    _setStatus(ConnectStatus.disconnected);
  }

  // ══════════════════════════════════════════════
  //  自动重连（指数退避）
  // ══════════════════════════════════════════════

  void _scheduleReconnect() {
    if (_manualDisconnect) {
      _log.i('manual disconnect, skip reconnect');
      return;
    }
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log.w('max reconnect attempts reached, still continuing anyway');
    }
    if (_wsUrl.isEmpty) {
      _log.w('no wsUrl, skip reconnect');
      return;
    }

    _reconnectAttempts++;
    final delay =
        _baseReconnectDelay * (1 << ((_reconnectAttempts - 1).clamp(0, 5)));
    final clampedDelay = delay > _maxReconnectDelay
        ? _maxReconnectDelay
        : delay;
    _log.w(
      'reconnect #$_reconnectAttempts in ${clampedDelay.inSeconds}s '
      '(stored: pairCode=$_pairCode partnerCode=$_partnerPairCode)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(clampedDelay, () async {
      _setStatus(ConnectStatus.connecting);
      try {
        _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
        _sub = _channel!.stream.listen(
          _onData,
          onError: (e) => _onError('reconnect stream error: $e'),
          onDone: _onDone,
        );
        _startHeartbeat();
        _log.i('reconnect channel created');
      } catch (e) {
        _log.e('reconnect failed: $e');
        _scheduleReconnect();
      }
    });
  }

  // ══════════════════════════════════════════════
  //  消息收发
  // ══════════════════════════════════════════════

  void _send(Map<String, dynamic> msg) {
    if (_channel == null) {
      _log.w('channel is null, cannot send: ${msg['type']}');
      return;
    }
    final jsonStr = jsonEncode(msg);
    _log.d('send: $jsonStr');
    _channel!.sink.add(jsonStr);
  }

  void _onData(dynamic raw) {
    _lastMessageTime = DateTime.now();
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final msg = WsMessage.fromJson(json);
      final rawStr = json.toString();
      final short = rawStr.length > 200 ? rawStr.substring(0, 200) : rawStr;
      _log.i('recv: type=${msg.type}, data=$short');

      switch (msg.type) {
        case 'connected':
          final newDeviceId = json['deviceId'] as String? ?? '';
          if (newDeviceId.isNotEmpty) _saveDeviceId(newDeviceId);
          _reconnectAttempts = 0;
          _log.i(
            'connected: deviceId=$newDeviceId, '
            'pairCode=$_pairCode, partnerCode=$_partnerPairCode',
          );

          // 1) 有本机配对码 → 先注册
          if (_pairCode.isNotEmpty) {
            _log.i('  → auto re-register code=$_pairCode');
            _send({'type': 'register', 'code': _pairCode});
          }

          // 2) 注册成功之后，若有对方配对码 → 500ms 后再发起 pair（给 register 留时间）
          if (_pairCode.isNotEmpty && _partnerPairCode.isNotEmpty) {
            final partnerCode = _partnerPairCode;
            _log.i(
              '  → auto re-pair to partnerCode=$partnerCode (scheduled in 500ms)',
            );
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_status == ConnectStatus.connected ||
                  _status == ConnectStatus.connecting) {
                _log.i('executing scheduled pair with $partnerCode');
                pairWith(partnerCode, skipSave: true);
              }
            });
          }
          _setStatus(ConnectStatus.connected);
          break;

        case 'paired':
          final newPartnerId = json['partnerId'] as String? ?? '';
          final newPartnerCode = json['partnerCode'] as String? ?? '';
          _log.i(
            '★ paired! partnerId=$newPartnerId, partnerCode=$newPartnerCode',
          );
          if (newPartnerId.isNotEmpty) _savePartnerId(newPartnerId);
          if (newPartnerCode.isNotEmpty) _savePartnerCode(newPartnerCode);
          _setStatus(ConnectStatus.paired);
          ForegroundServiceUtil.startService();
          break;

        case 'unbound':
          _log.i('★ unbound successfully');
          _partnerId = '';
          _setStatus(ConnectStatus.connected);
          break;

        case 'pair_error':
          _log.w('pair error: ${json['message']}');
          // 不自动改变 status，等待用户在 UI 重试
          break;

        case 'miss_you':
          final senderId = json['senderId'] as String? ?? 'unknown';
          final color = json['color'] as String? ?? '#ff69b4';
          _log.i('★ received miss_you from=$senderId, color=$color');
          _msgController.add(msg);
          final colorObj = _parseColor(color);
          _triggerHeart(colorObj);
          break;

        case 'text_message':
          final senderId = json['senderId'] as String? ?? 'unknown';
          final content = json['content'] as String? ?? '';
          final ts = json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
          _log.i('★ received text_message from=$senderId, len=${content.length}');
          _msgController.add(msg);
          if (content.isNotEmpty) {
            _triggerTextMessage(content, ts);
          }
          break;

        case 'text_message_ack':
          final ts = json['timestamp'] as int? ?? 0;
          _log.d('text_message_ack received, ts=$ts');
          // 目前仅打日志，后续可以做发送中→成功的状态更新
          break;

        case 'partner_disconnected':
          _log.w('partner disconnected');
          _partnerId = '';
          _setStatus(ConnectStatus.connected);
          break;

        case 'pong':
          _log.d('heartbeat: pong received');
          break;

        case 'error':
          _log.w('server error: ${json['message']}');
          break;

        default:
          _log.w('unknown message type: ${msg.type}');
      }
    } catch (e, stack) {
      _log.e('parse error: $e\nraw: $raw\nstack: $stack');
    }
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    try {
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      } else if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFFFF4081);
  }

  void _onError(String msg) {
    _log.e('ws error: $msg');
    _scheduleReconnect();
  }

  void _onDone() {
    _log.w('connection closed, wasPaired=$_isPairedBeforeClose');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _sub?.cancel();
    _sub = null;
    _channel = null;
    _setStatus(ConnectStatus.disconnected);
    _scheduleReconnect();
  }

  bool get _isPairedBeforeClose => _status == ConnectStatus.paired;

  // ══════════════════════════════════════════════
  //  配对操作
  // ══════════════════════════════════════════════

  /// 注册本机配对码
  void registerCode(String code) {
    _pairCode = code;
    _savePairCode(code);
    _send({'type': 'register', 'code': code});
    _log.i('register code=$code');
  }

  /// 绑定对方配对码
  ///
  /// [skipSave] 内部恢复配对时使用，不重复写入本地
  void pairWith(String code, {bool skipSave = false}) {
    if (!skipSave) {
      _partnerPairCode = code;
      _savePartnerCode(code);
    }
    _send({'type': 'pair', 'code': code});
    _log.i('pair with partnerCode=$code');
  }

  // ══════════════════════════════════════════════
  //  发送「想你」
  // ══════════════════════════════════════════════

  bool sendMissYou({String color = '#ff69b4'}) {
    if (!isPaired) {
      _log.w('not paired, cannot send miss_you');
      return false;
    }

    // 强绑定模式：优先用对方配对码路由（不依赖易变的 deviceId）
    if (_partnerPairCode.isEmpty) {
      _log.w('missing partnerCode, cannot route miss_you');
      return false;
    }

    _send({
      'type': 'miss_you',
      'senderId': _deviceId,
      'targetCode': _partnerPairCode,
      'color': color,
    });
    _log.i('miss_you sent: device=$_deviceId → partnerCode=$_partnerPairCode');
    return true;
  }

  // ══════════════════════════════════════════════
  //  解除绑定
  // ══════════════════════════════════════════════

  /// 解除与当前配对方的绑定关系
  ///
  /// 通知服务端清除持久绑定记录，双方都解除。
  /// 清除本地保存的配对信息。
  Future<void> unbind() async {
    _log.i('unbinding...');
    _send({'type': 'unbind'});

    // 清除本地配对信息（保留 pairCode 供下次使用）
    _partnerId = '';
    _partnerPairCode = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPartnerId);
    await prefs.remove(_kPartnerCode);

    ForegroundServiceUtil.stopService();
    _setStatus(ConnectStatus.connected);
  }

  // ══════════════════════════════════════════════
  //  爱心动画触发（前后台分流）
  // ══════════════════════════════════════════════

  /// 收到 miss_you 后，根据 App 前后台状态选择触发方式
  ///
  /// - 前台（resumed）：直接弹悬浮窗，失败则降级为页面动画
  /// - 后台（paused/inactive）：弹高优先级本地通知，
  ///   用户点击通知唤醒 App 后再弹爱心
  void _triggerHeart(Color color) async {
    final isForeground = AppLifecycleManager.instance.isForeground;
    _log.i('triggerHeart: color=$color, isForeground=$isForeground');

    if (isForeground) {
      // ── 情况 A：App 在前台 → 直接弹悬浮窗 ──
      await _tryOverlay(color);
    } else {
      // ── 情况 B：App 在后台 → 弹本地通知 ──
      _log.i('App in background, showing notification');
      final colorHex = _colorToHex(color);
      await NotificationService.showMissYouNotification(colorHex);
    }
  }

  /// 尝试弹悬浮窗，失败则降级为页面动画
  Future<void> _tryOverlay(Color color) async {
    _log.i('trying overlay with color=$color');
    bool ok = false;
    try {
      ok = await OverlayService.showLoveWindow();
      _log.i('overlay result: $ok');
    } catch (e, stack) {
      _log.e('overlay exception: $e\n$stack');
      ok = false;
    }

    if (!ok) {
      // 降级：通过 missYouStream 广播给首页显示全屏动画
      _log.w('overlay failed, broadcasting missYouStream for in-app fallback');
      _missYouCtrl.add(color);
    }
  }

  // ══════════════════════════════════════════════
  //  文字消息：前后台分流 + 同步 + 持久化
  // ══════════════════════════════════════════════

  /// 保存聊天记录到本地存储
  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(recentMessages.map((e) => e.toJson()).toList());
      await prefs.setString(_kChatMessages, data);
    } catch (e) {
      _log.w('save chat messages failed: $e');
    }
  }

  /// 按 timestamp 升序排序 + 去重 + 裁剪到 _maxRecentMessages 条
  void _sortAndTrimMessages() {
    // 1) 去重（基于 dedupKey）
    final seen = <String>{};
    final deduped = <ChatMessage>[];
    for (final m in recentMessages) {
      if (seen.add(m.dedupKey)) {
        deduped.add(m);
      }
    }
    recentMessages
      ..clear()
      ..addAll(deduped);
    // 2) 按时间戳升序（旧 → 新）
    recentMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    // 3) 裁剪（最旧的在前面，超上限就删前面）
    if (recentMessages.length > _maxRecentMessages) {
      recentMessages.removeRange(0, recentMessages.length - _maxRecentMessages);
    }
  }

  /// 追加消息：去重 + 排序 + 裁剪 + 持久化 + 广播给 UI
  void _appendMessage(ChatMessage msg) {
    // 去重检查：已存在相同消息则忽略（避免重放/重复通知）
    final existed = recentMessages.any((m) => m.dedupKey == msg.dedupKey);
    if (existed) {
      _log.d('skip duplicate msg: ${msg.dedupKey}');
      return;
    }

    recentMessages.add(msg);
    _sortAndTrimMessages();
    // 异步保存，不阻塞 UI
    _saveMessages();
    _textMsgCtrl.add(msg);
  }

  /// 收到 text_message 后根据前后台状态选择处理方式
  ///
  /// - 前台（resumed）：直接 appendMessage（聊天区自动显示）
  /// - 后台（paused/inactive）：showTextNotification → 高优先级本地通知，
  ///   用户点击通知 → 唤醒 App → 跳主页 → appendMessage
  void _triggerTextMessage(String content, int timestamp) async {
    final isForeground = AppLifecycleManager.instance.isForeground;
    _log.i('triggerTextMessage: len=${content.length}, isForeground=$isForeground');

    if (isForeground) {
      // 情况 A：App 在前台 → 直接加到聊天记录
      _appendMessage(ChatMessage(
        content: content,
        isMine: false,
        timestamp: timestamp,
      ));
    } else {
      // 情况 B：App 在后台 → 弹本地通知（payload 前缀 "text:"）
      _log.i('App in background, showing text notification');
      await NotificationService.showTextNotification(content);
    }
  }

  /// 通知 payload 前缀 → 区分消息类型
  static const String _prefixHeart = '#';        // "#ff69b4" → 爱心
  static const String _prefixText  = 'text:';    // "text:你好呀" → 文字消息

  /// 判断 payload 是否为文字消息
  static bool isTextPayload(String payload) => payload.startsWith(_prefixText);

  /// 判断 payload 是否为爱心消息
  static bool isHeartPayload(String payload) => payload.startsWith(_prefixHeart);

  /// 发送一条文字消息给配对方
  ///
  /// 返回 true 表示消息已下发（是否真正到达需等 ack）
  bool sendTextMessage(String content) {
    final trimmed = content.trim();
    if (!isPaired) {
      _log.w('not paired, cannot send text_message');
      return false;
    }
    if (trimmed.isEmpty) {
      _log.w('empty text, skip send');
      return false;
    }
    if (_partnerPairCode.isEmpty) {
      _log.w('missing partnerCode, cannot route text_message');
      return false;
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    _send({
      'type': 'text_message',
      'senderId': _deviceId,
      'targetCode': _partnerPairCode,
      'content': trimmed,
      'timestamp': ts,
    });

    // 立刻本地追加显示（乐观 UI，之后 ack 确认）
    _appendMessage(ChatMessage(
      content: trimmed,
      isMine: true,
      timestamp: ts,
      sentOk: true,
    ));

    _log.i('text_message sent: len=${trimmed.length}, target=$_partnerPairCode');
    return true;
  }

  /// 确保路由跳转到主页（HomePage）
  ///
  /// 用于点击通知后，无论当前在哪个页面（配对页/启动页），
  /// 都先跳转到主页，保证降级动画（inApp fallback）有宿主页面显示。
  /// 幂等：如果已经在主页或路由堆栈已包含主页则不重复压入。
  Future<void> _ensureNavigateToHome() async {
    final navKey = navigatorKey;
    if (navKey == null) {
      _log.w('navigatorKey not injected, skip navigate to home');
      return;
    }
    final navigator = navKey.currentState;
    if (navigator == null) {
      _log.w('navigatorState is null, skip navigate');
      return;
    }

    // 如果当前没有任何路由（App 刚启动 Splash 阶段），先等一下再跳
    // 通过 pushNamedAndRemoveUntil 确保跳到主页并清理历史
    try {
      navigator.pushNamedAndRemoveUntil('/home', (route) => false);
      _log.i('navigated to /home for notification trigger');
      // 等一帧让主页完成挂载
      await Future.delayed(const Duration(milliseconds: 400));
    } catch (e) {
      _log.e('navigate to home error: $e');
    }
  }

  /// 通知点击后调度 — 根据 payload 前缀分发到爱心 / 文字消息
  ///
  /// 由 NotificationService.onNotificationTap 回调调用（main.dart 绑定）。
  /// payload 格式：
  ///   "#ff69b4"       → 爱心颜色
  ///   "text:你好呀"   → 文字消息内容
  Future<void> dispatchNotificationPayload(String payload) async {
    _log.i('dispatchNotificationPayload: $payload');
    if (isTextPayload(payload)) {
      final content = payload.substring(_prefixText.length);
      await triggerTextFromNotification(content);
    } else if (isHeartPayload(payload)) {
      await triggerFromNotification(payload);
    } else {
      _log.w('unknown payload format, skip: $payload');
    }
  }

  /// 通知点击 → 爱心动画
  /// 流程：
  ///   1. 确保跳转到主页（让降级动画有宿主）
  ///   2. 等待 UI 就绪
  ///   3. 尝试弹悬浮窗，失败走降级动画
  Future<void> triggerFromNotification(String colorHex) async {
    _log.i('triggerFromNotification: color=$colorHex');
    final color = _parseColor(colorHex);

    // 1. 先跳转主页 — 保证悬浮窗失败时，降级全屏动画有宿主页面显示
    await _ensureNavigateToHome();

    // 2. 额外等待，确保 UI 树已完全挂载
    await Future.delayed(const Duration(milliseconds: 300));

    // 3. 尝试悬浮窗，失败走 inApp fallback
    await _tryOverlay(color);
  }

  /// 通知点击 → 文字消息
  /// 流程：
  ///   1. 跳主页
  ///   2. appendMessage 到聊天列表（用户打开主页就能看到）
  Future<void> triggerTextFromNotification(String content) async {
    _log.i('triggerTextFromNotification: len=${content.length}');
    await _ensureNavigateToHome();
    await Future.delayed(const Duration(milliseconds: 300));
    _appendMessage(ChatMessage(
      content: content,
      isMine: false,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// 让 UI 层主动触发一次降级动画（供 overlay_page 调用或调试）
  void sendTriggerInApp(Color color) {
    _missYouCtrl.add(color);
  }

  /// 检查是否有待处理的通知 payload（App 被杀死后通过通知启动）
  ///
  /// 时机：SplashPage 初始化完成、导航到主路由之后调用。
  /// 根据 payload 前缀自动分发到爱心或文字消息处理。
  void checkPendingMissYou() {
    final pending = NotificationService.pendingMissYouColor;
    if (pending != null) {
      _log.i('found pending payload: $pending (cold-start from notification)');
      NotificationService.pendingMissYouColor = null;
      // 延迟执行，确保 WebSocket 和主页 UI 已完全初始化
      Future.delayed(const Duration(seconds: 2), () {
        dispatchNotificationPayload(pending);
      });
    }
  }

  /// Color 转 hex 字符串
  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  // ══════════════════════════════════════════════
  //  内部工具
  // ══════════════════════════════════════════════

  void _setStatus(ConnectStatus newStatus) {
    if (_status == newStatus) return;
    _log.i('status: $_status → $newStatus');
    _status = newStatus;
    notifyListeners();
  }

  @override
  void dispose() {
    _manualDisconnect = true;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _msgController.close();
    _missYouCtrl.close();
    _textMsgCtrl.close();
    super.dispose();
  }
}

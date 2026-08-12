import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/websocket_service.dart';
import 'services/overlay_service.dart';
import 'services/notification_service.dart';
import 'services/app_lifecycle_manager.dart';
import 'services/app_settings.dart';
import 'pages/splash_page.dart';
import 'pages/pairing_page.dart';
import 'pages/home_page.dart';
import 'pages/overlay_page.dart';

/// 主 App 入口
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 锁定竖屏
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 设置状态栏透明
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 1. 初始化悬浮窗引擎（检查权限状态，不显示悬浮窗）
  await OverlayService.initialize();

  // 2. 初始化本地通知服务（创建高优先级渠道、检测冷启动 payload）
  await NotificationService.initialize();

  // 3. 启动 App 前后台生命周期监听（WidgetsBindingObserver）
  AppLifecycleManager.instance.start();

  runApp(const MissYouApp());
}

/// 悬浮窗入口 — flutter_overlay_window 需要独立 entry-point
@pragma('vm:entry-point')
void overlayMain() {
  runApp(const OverlayApp());
}

/// 全局 Navigator Key — 让服务层（如 WebSocketService）
/// 在没有 BuildContext 的情况下也能执行路由跳转
/// （用于点击通知后确保跳转到主页）
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// 主应用
class MissYouApp extends StatefulWidget {
  const MissYouApp({super.key});

  @override
  State<MissYouApp> createState() => _MissYouAppState();
}

class _MissYouAppState extends State<MissYouApp> {
  late WebSocketService _wsService;

  @override
  void initState() {
    super.initState();
    // 预先创建 WebSocketService 实例，用于绑定通知回调
    _wsService = WebSocketService();
    // 注入全局 navigatorKey，供通知点击后路由跳转使用
    _wsService.navigatorKey = appNavigatorKey;

    // ══════════════════════════════════════════════
    //  绑定通知点击回调：
    //  - "#ff69b4"     → 爱心悬浮窗
    //  - "text:你好呀" → 文字消息
    // ══════════════════════════════════════════════
    NotificationService.onNotificationTap = (String payload) {
      _wsService.dispatchNotificationPayload(payload);
    };
  }

  @override
  void dispose() {
    NotificationService.onNotificationTap = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettings()),
        // 使用已创建的实例，保证通知回调和 Provider 内是同一个对象
        ChangeNotifierProvider<WebSocketService>.value(value: _wsService),
      ],
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        title: '想你',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF4081),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0F0F1A),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
          ),
          fontFamily: null,
          useMaterial3: true,
        ),
        // 启动页作为首页，后续通过命名路由导航
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashPage(),
          '/pairing': (context) => const PairingPage(),
          '/home': (context) => const HomePage(),
        },
      ),
    );
  }
}

/// 悬浮窗应用
class OverlayApp extends StatelessWidget {
  const OverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF4081),
        ),
      ),
      home: const OverlayPage(),
    );
  }
}

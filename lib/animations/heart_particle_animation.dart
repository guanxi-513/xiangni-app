// ============================================================
// 爱心粒子动画组件（支持 50 种预设）
//
// 核心变化：
//   1. 新增 presets 参数，不传时自动从 heartAnimationPresets 随机
//   2. 粒子支持 8 种形状、物理扩展（摆动、拖尾、脉冲）
//   3. 中心大爱心 7 种模式（呼吸/心跳/3D旋转/脉冲环/碎裂/绽放/无）
//   4. 背景 4 种风格（渐变/星空/烟雾/闪耀）
//   5. 50 种发射模式全部对应实现
//
// 悬浮窗嵌入说明：
//   在 overlay_page.dart 中直接使用此 Widget，
//   onComplete 回调中调用 FlutterOverlayWindow.closeOverlay()
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'heart_animation_presets.dart';

part 'heart_particle_painter.dart';
part 'heart_particle_emitter.dart';

// ──────────────────────────────────────────────
// 粒子模型（增强版）
// ──────────────────────────────────────────────

class HeartParticle {
  double x, y;                   // 当前位置
  double vx, vy;                 // 速度向量
  double size;                   // 大小
  double rotation;               // 当前旋转角度
  double rotationSpeed;          // 旋转速度（弧度/秒）
  Color color;                   // 颜色
  double life;                   // 剩余生命 1.0→0.0
  double maxLife;                // 总寿命秒
  final ParticleShape shape;     // 粒子形状
  final double originalX;        // 初始位置（供轨迹/震动模式偏移）
  final double originalY;
  final double bornTime;         // 出生时刻（0.0~1.0 动画时间）
  double age;                    // 当前年龄（秒）
  double swingAmp;               // 摆动幅度（0 不摆动）
  double swingFreq;              // 摆动频率
  double dragCoeff;              // 空气阻力系数
  double gravity;                // 重力系数
  final Map<String, double> extra; // 各模式附加数据
  // 拖尾：存最近 N 个位置用于霓虹轨迹
  final List<Offset> trail = [];
  static const int kTrailLength = 6;

  HeartParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.life,
    required this.maxLife,
    required this.shape,
    required this.bornTime,
    required this.gravity,
    required this.dragCoeff,
    this.swingAmp = 0,
    this.swingFreq = 0,
    this.extra = const {},
    this.age = 0,
  })  : originalX = x,
        originalY = y;

  /// 每帧更新
  void update(double dt, double animTime) {
    age += dt;
    // 基础物理
    vx *= pow(dragCoeff, dt * 60).toDouble();
    vy *= pow(dragCoeff, dt * 60).toDouble();
    vy += gravity * dt;
    x += vx * dt;
    y += vy * dt;
    rotation += rotationSpeed * dt;
    life -= dt / maxLife;

    // 摆动（沿速度垂直方向叠加正弦位移）
    if (swingAmp > 0) {
      final phaseVal = extra['phase'] as num? ?? 0;
      final s = sin((age * swingFreq + phaseVal) * pi * 2);
      final perpX = vy;
      final perpY = -vx;
      final len = sqrt(perpX * perpX + perpY * perpY) + 1e-6;
      x += perpX / len * swingAmp * s * dt * 60;
      y += perpY / len * swingAmp * s * dt * 60;
    }

    // 保存拖尾点
    trail.insert(0, Offset(x, y));
    if (trail.length > kTrailLength) trail.removeLast();
  }

  bool get isDead => life <= 0;
}

// ──────────────────────────────────────────────
// 动画 Widget（支持预设）
// ──────────────────────────────────────────────

class HeartAnimationWidget extends StatefulWidget {
  // ── 基础参数 ──
  final Duration duration;
  final bool enableVibration;
  final List<int>? vibrationPattern;
  final VoidCallback? onComplete;

  // ── 预设参数：优先取 preset，没传随机 ──
  final HeartAnimationPreset? preset;
  final int? preferPresetIndex; // 偏好预设序号（0~49），没传才随机
  final ValueChanged<int>? onPresetPicked; // 调试用：通知用了哪个预设

  // ── 向后兼容的覆盖参数（会覆盖预设值） ──
  /// 覆盖预设的中心大爱心渐变色（2 色：上、下）
  final List<Color>? centerHeartColors;
  /// 覆盖预设的粒子调色板（任意长度）
  final List<Color>? particleColors;
  /// 覆盖预设的粒子数量
  final int? particleCount;

  const HeartAnimationWidget({
    super.key,
    this.duration = const Duration(milliseconds: 4500),
    this.enableVibration = true,
    this.vibrationPattern,
    this.onComplete,
    this.preset,
    this.preferPresetIndex,
    this.onPresetPicked,
    // 向后兼容参数
    this.centerHeartColors,
    this.particleColors,
    this.particleCount,
  });

  @override
  State<HeartAnimationWidget> createState() => _HeartAnimationWidgetState();
}

class _HeartAnimationWidgetState extends State<HeartAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final List<HeartParticle> _particles = [];
  final _random = Random();
  late HeartAnimationPreset _preset;
  late final List<Color> _particleColorPool;
  // 星空/闪耀场用随机星点（缓存避免重绘抖动）
  final List<_StarPoint> _bgStars = [];
  // 脉冲环（centerMode = pulseRing 时）
  final List<_PulseRing> _pulseRings = [];

  @override
  void initState() {
    super.initState();

    // 1. 选择预设
    var basePreset = widget.preset ??
        (widget.preferPresetIndex != null
            ? presetByIndex(widget.preferPresetIndex!)
            : pickRandomPreset());
    widget.onPresetPicked?.call(heartAnimationPresets.indexOf(basePreset));

    // 2. 应用覆盖参数（particleCount / centerColors / palette）
    final overrideCenter = widget.centerHeartColors ??
        (widget.particleColors != null && widget.particleColors!.length >= 2
            ? [widget.particleColors!.first, widget.particleColors!.last]
            : null);
    final overridePalette = widget.particleColors;
    final overrideCount = widget.particleCount;

    if (overrideCenter != null || overridePalette != null || overrideCount != null) {
      basePreset = HeartAnimationPreset(
        name: basePreset.name,
        emitter: basePreset.emitter,
        particleShape: basePreset.particleShape,
        particleCount: overrideCount ?? basePreset.particleCount,
        palette: overridePalette ?? basePreset.palette,
        centerColors: overrideCenter ?? basePreset.centerColors,
        gravity: basePreset.gravity,
        lifeMin: basePreset.lifeMin,
        lifeMax: basePreset.lifeMax,
        sizeMin: basePreset.sizeMin,
        sizeMax: basePreset.sizeMax,
        speedMin: basePreset.speedMin,
        speedMax: basePreset.speedMax,
        centerMode: basePreset.centerMode,
        bg: basePreset.bg,
        customText: basePreset.customText,
        vibrationPattern: basePreset.vibrationPattern,
        dragCoeff: basePreset.dragCoeff,
        extra: basePreset.extra,
      );
    }
    _preset = basePreset;

    // 3. 调色板扩展成更大的池（每个颜色按权重复制几份）
    _particleColorPool = [];
    for (final c in _preset.palette) {
      _particleColorPool
        ..add(c)
        ..add(c)
        ..add(c);
    }
    _particleColorPool.shuffle(_random);

    // 3. 生成背景星星（Star/Nebula 类背景）
    _generateBgStars();

    // 4. 启动动画控制器
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addListener(_tick)
     ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onComplete?.call();
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _spawnAllParticles();
      _ctrl.forward();
      if (widget.enableVibration) _vibrate();
    });
  }

  void _generateBgStars() {
    switch (_preset.bg) {
      case BgStyle.starry:
      case BgStyle.sparkleField:
        final count = _preset.bg == BgStyle.starry ? 120 : 90;
        for (int i = 0; i < count; i++) {
          _bgStars.add(_StarPoint(
            x: _random.nextDouble(),
            y: _random.nextDouble(),
            size: 0.3 + _random.nextDouble() * 1.8,
            phase: _random.nextDouble() * pi * 2,
            speed: 0.5 + _random.nextDouble() * 2.5,
            brightness: 0.2 + _random.nextDouble() * 0.8,
          ));
        }
        break;
      case BgStyle.smokeCloud:
        for (int i = 0; i < 10; i++) {
          _bgStars.add(_StarPoint(
            x: _random.nextDouble(),
            y: _random.nextDouble(),
            size: 60 + _random.nextDouble() * 120,
            phase: _random.nextDouble() * pi * 2,
            speed: 0.3 + _random.nextDouble() * 0.6,
            brightness: 0.15 + _random.nextDouble() * 0.2,
            smoke: true,
          ));
        }
        break;
      default:
        break;
    }
  }

  /// 按当前预设的发射模式生成所有粒子
  void _spawnAllParticles() {
    final em = ParticleEmitter(
      random: _random,
      preset: _preset,
      palette: _particleColorPool,
      screenSize: MediaQuery.of(context).size,
    );
    final particles = em.emit();
    _particles.addAll(particles);
  }

  /// 震动
  void _vibrate() async {
    final has = await Vibration.hasVibrator();
    if (has == true) {
      final pattern =
          widget.vibrationPattern ??
          _preset.vibrationPattern ??
          const [0, 250, 80, 350, 100, 250];
      try {
        Vibration.vibrate(pattern: pattern);
      } catch (_) {}
    }
  }

  /// 每帧更新
  void _tick() {
    final t = _ctrl.value;
    final dt = 1 / 60;

    // 粒子
    for (final p in _particles) {
      // 如果还没到出生时间（延迟发射），跳过
      if (t < p.bornTime) continue;
      p.update(dt, t);
    }
    _particles.removeWhere((p) => p.isDead);

    // 脉冲环（中心脉冲模式）
    if (_preset.centerMode == CenterHeartMode.pulseRing) {
      // 0~0.6 秒内发射 4 个环
      final ringInterval = 1 / 6;
      final expectedRings = (t / ringInterval).floor();
      while (_pulseRings.length < expectedRings && _pulseRings.length < 5) {
        _pulseRings.add(_PulseRing(startT: _pulseRings.length * ringInterval));
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final fadeIn = (t / 0.15).clamp(0.0, 1.0);
        final fadeOut = t < 0.82 ? 1.0 : (1.0 - (t - 0.82) / 0.18).clamp(0.0, 1.0);

        return CustomPaint(
          painter: HeartParticlePainter(
            particles: _particles,
            animTime: t,
            fadeIn: fadeIn,
            fadeOut: fadeOut,
            preset: _preset,
            bgStars: _bgStars,
            pulseRings: _pulseRings,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

// ── 小结构：背景星点/烟雾 ─────────────────

class _StarPoint {
  final double x; // 0~1 相对位置
  final double y;
  final double size;
  final double phase;
  final double speed;
  final double brightness;
  final bool smoke;
  _StarPoint({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.speed,
    required this.brightness,
    this.smoke = false,
  });
}

// ── 脉冲环 ─────────────────

class _PulseRing {
  final double startT;
  _PulseRing({required this.startT});
}

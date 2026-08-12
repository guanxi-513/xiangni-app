part of 'heart_particle_animation.dart';

// ──────────────────────────────────────────────
// 粒子发射器（50 种模式）
//
// 每种模式定义：
//   - 粒子出生位置（中心/顶部/底部/环形/螺旋/心形轨迹采样点…）
//   - 粒子速度方向 + 大小范围
//   - 摆动幅度、拖尾、旋转速度等装饰参数
//   - 出生时间（是否延迟分阶段）
// ──────────────────────────────────────────────

class ParticleEmitter {
  final Random random;
  final HeartAnimationPreset preset;
  final List<Color> palette;
  final Size screenSize;

  ParticleEmitter({
    required this.random,
    required this.preset,
    required this.palette,
    required this.screenSize,
  });

  late final double _cx = screenSize.width / 2;
  late final double _cy = screenSize.height / 2;
  late final double _w = screenSize.width;
  late final double _h = screenSize.height;

  List<HeartParticle> emit() {
    final n = preset.particleCount;
    switch (preset.emitter) {
      case EmitterPattern.classicBurst:
        return _classicBurst(n);
      case EmitterPattern.spiralThrow:
        return _spiralThrow(n, preset.extra['spiralArms'] ?? 3, preset.extra['spiralTurns'] ?? 2.5);
      case EmitterPattern.ringFlash:
        return _ringFlash(n, (preset.extra['rings'] ?? 3).toInt(), preset.extra['ringGap'] ?? 0.35);
      case EmitterPattern.heartOrbit:
        return _heartOrbit(n);
      case EmitterPattern.loveFountain:
        return _loveFountain(n);
      case EmitterPattern.fireworkBurst:
        return _fireworkBurst(n);
      case EmitterPattern.meteorShower:
        return _meteorShower(n, preset.extra['trail'] ?? 0);
      case EmitterPattern.lanternRise:
        return _lanternRise(n);
      case EmitterPattern.crossBurst:
        return _crossBurst(n);
      case EmitterPattern.vortexSwallow:
        return _vortexSwallow(n, preset.extra['vortexTime'] ?? 0.5);
      case EmitterPattern.sineWave:
        return _sineWave(n);
      case EmitterPattern.starShape:
        return _starShape(n);
      case EmitterPattern.radialBeam:
        return _radialBeam(n, (preset.extra['beam'] ?? 24).toInt());
      case EmitterPattern.rippleRings:
        return _rippleRings(n, (preset.extra['rings'] ?? 4).toInt(), preset.extra['ringGap'] ?? 0.3);
      case EmitterPattern.twinHearts:
        return _twinHearts(n);
      case EmitterPattern.sakuraFall:
        return _sakuraFall(n);
      case EmitterPattern.galaxySpiral:
        return _galaxySpiral(n, (preset.extra['galaxyArms'] ?? 4).toInt());
      case EmitterPattern.bubbleBlow:
        return _bubbleBlow(n);
      case EmitterPattern.pulseHeartWave:
        return _pulseHeartWave(n, (preset.extra['waves'] ?? 4).toInt(), preset.extra['waveGap'] ?? 0.4);
      case EmitterPattern.laserLines:
        return _laserLines(n);
      case EmitterPattern.smokePuff:
        return _smokePuff(n);
      case EmitterPattern.sparkBranches:
        return _sparkBranches(n);
      case EmitterPattern.stardustDrifting:
        return _stardustDrifting(n);
      case EmitterPattern.petalFloating:
        return _petalFloating(n);
      case EmitterPattern.featherDrift:
        return _featherDrift(n);
      case EmitterPattern.dnaHelix:
        return _dnaHelix(n);
      case EmitterPattern.umbrellaOpen:
        return _umbrellaOpen(n);
      case EmitterPattern.roseNebula:
        return _roseNebula(n);
      case EmitterPattern.dandelionSeed:
        return _dandelionSeed(n);
      case EmitterPattern.diamondShatter:
        return _diamondShatter(n);
      case EmitterPattern.hourglass:
        return _hourglass(n);
      case EmitterPattern.blackHole:
        return _blackHole(n, preset.extra['blackHolePhase'] ?? 0.35);
      case EmitterPattern.clockDial:
        return _clockDial(n);
      case EmitterPattern.ferrisWheel:
        return _ferrisWheel(n);
      case EmitterPattern.pinwheelSpin:
        return _pinwheelSpin(n);
      case EmitterPattern.bubbleBathRise:
        return _bubbleBathRise(n);
      case EmitterPattern.waterDropSplash:
        return _waterDropSplash(n);
      case EmitterPattern.ribbonDance:
        return _ribbonDance(n);
      case EmitterPattern.diamondRain:
        return _diamondRain(n);
      case EmitterPattern.neonGlowTrail:
        return _neonGlowTrail(n, preset.extra['trail'] ?? 0);
      case EmitterPattern.pixelHeartGrid:
        return _pixelHeartGrid(n);
      case EmitterPattern.confettiParty:
        return _confettiParty(n);
      case EmitterPattern.stackLoveHearts:
        return _stackLoveHearts(n);
      case EmitterPattern.quantumPulse:
        return _quantumPulse(n);
      case EmitterPattern.rainbowBurst:
        return _rainbowBurst(n);
      case EmitterPattern.shockwaveDisc:
        return _shockwaveDisc(n, (preset.extra['discs'] ?? 5).toInt());
      case EmitterPattern.fireflyGlow:
        return _fireflyGlow(n);
      case EmitterPattern.roseBloom:
        return _roseBloom(n);
      case EmitterPattern.crystalShine:
        return _crystalShine(n);
      case EmitterPattern.grandFinale:
        return _grandFinale(n);
    }
  }

  // ── 工具：随机范围 ─────────────
  double _rnd(double min, double max) => min + random.nextDouble() * (max - min);
  Color _pickColor() => palette[random.nextInt(palette.length)];
  double _pickSpeed() => _rnd(preset.speedMin, preset.speedMax);
  double _pickSize() => _rnd(preset.sizeMin, preset.sizeMax);
  double _pickLife() => _rnd(preset.lifeMin, preset.lifeMax);
  double _pickRotation() => _rnd(0, pi * 2);
  double _pickRotSpeed() => _rnd(-2.5, 2.5);

  HeartParticle _mk({
    required double x,
    required double y,
    required double vx,
    required double vy,
    double? size,
    double? life,
    double? rot,
    double? rotSpeed,
    Color? color,
    ParticleShape? shape,
    double bornTime = 0,
    double swingAmp = 0,
    double swingFreq = 0,
    Map<String, double> extra = const {},
  }) {
    final spdScale = 1;
    return HeartParticle(
      x: x,
      y: y,
      vx: vx * spdScale,
      vy: vy * spdScale,
      size: size ?? _pickSize(),
      rotation: rot ?? _pickRotation(),
      rotationSpeed: rotSpeed ?? _pickRotSpeed(),
      color: color ?? _pickColor(),
      life: 1.0,
      maxLife: life ?? _pickLife(),
      shape: shape ?? preset.particleShape,
      bornTime: bornTime,
      gravity: preset.gravity,
      dragCoeff: preset.dragCoeff,
      swingAmp: swingAmp,
      swingFreq: swingFreq,
      extra: extra,
      age: 0,
    );
  }

  // ═══════════════════════════════════════════════
  //  1~50 发射模式（按顺序）
  // ═══════════════════════════════════════════════

  // 1 经典爆发：中心均匀全向扩散 + 少量底部上升
  List<HeartParticle> _classicBurst(int n) {
    final out = <HeartParticle>[];
    final burstN = (n * 0.75).toInt();
    for (int i = 0; i < burstN; i++) {
      final angle = _rnd(0, pi * 2);
      final s = _pickSpeed();
      out.add(_mk(
        x: _cx,
        y: _cy,
        vx: cos(angle) * s,
        vy: sin(angle) * s - 50,
      ));
    }
    // 少量上升
    for (int i = 0; i < n - burstN; i++) {
      out.add(_mk(
        x: _cx + _rnd(-_w * 0.3, _w * 0.3),
        y: _h + 20,
        vx: _rnd(-60, 60),
        vy: -_rnd(80, 180),
      ));
    }
    return out;
  }

  // 2 螺旋抛射：阿基米德螺旋
  List<HeartParticle> _spiralThrow(int n, double arms, double turns) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final p = i / n;
      final arm = (i % arms.toInt()) / arms;
      final theta = arm * pi * 2 + p * turns * pi * 2;
      final r = 20 + p * 120;
      final s = _pickSpeed();
      final tx = _cx + cos(theta) * r;
      final ty = _cy + sin(theta) * r;
      out.add(_mk(
        x: _cx,
        y: _cy,
        vx: (tx - _cx) * s / 160,
        vy: (ty - _cy) * s / 160 - 40,
      ));
    }
    return out;
  }

  // 3 环形扩散：多圈按时间间隔爆发
  List<HeartParticle> _ringFlash(int n, int rings, double ringGap) {
    final out = <HeartParticle>[];
    final perRing = n ~/ rings;
    for (int r = 0; r < rings; r++) {
      final born = r * ringGap;
      for (int i = 0; i < perRing; i++) {
        final angle = (i + (r.isOdd ? 0.5 / perRing : 0)) / perRing * pi * 2;
        final s = _pickSpeed();
        out.add(_mk(
          x: _cx,
          y: _cy,
          vx: cos(angle) * s,
          vy: sin(angle) * s,
          bornTime: born,
        ));
      }
    }
    return out;
  }

  // 4 心形轨道：在心形轮廓上采样出生位置，沿法向发射
  List<HeartParticle> _heartOrbit(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final t = i / n * pi * 2;
      // 心形参数方程
      final x = 16 * pow(sin(t), 3).toDouble();
      final y = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t));
      final scale = 10.0;
      final px = _cx + x * scale;
      final py = _cy + y * scale - 50;
      final nx = x; // 法向近似：向外
      final ny = -y;
      final norm = sqrt(nx * nx + ny * ny) + 1e-6;
      final s = _pickSpeed();
      out.add(_mk(
        x: px,
        y: py,
        vx: nx / norm * s,
        vy: ny / norm * s,
        bornTime: (i / n) * 0.5, // 0.5 秒内逐步出现在心形各点
      ));
    }
    return out;
  }

  // 5 喷泉：从中心底部向上喷射，抛物线
  List<HeartParticle> _loveFountain(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final angle = -pi / 2 + _rnd(-0.7, 0.7); // 向上扇形
      final s = _pickSpeed();
      final born = _rnd(0, 0.4);
      out.add(_mk(
        x: _cx + _rnd(-10, 10),
        y: _cy + 150,
        vx: cos(angle) * s,
        vy: sin(angle) * s,
        bornTime: born,
      ));
    }
    return out;
  }

  // 6 烟花：先升再爆炸（用 bornTime 分两段：0~0.4 上升，0.4 爆炸）
  List<HeartParticle> _fireworkBurst(int n) {
    final out = <HeartParticle>[];
    final rockets = 8;
    // 8 个上升轨迹
    for (int r = 0; r < rockets; r++) {
      final x = _cx + _rnd(-_w * 0.3, _w * 0.3);
      final angle = -pi / 2 + _rnd(-0.2, 0.2);
      final s = _rnd(260, 380);
      // 上升弹体（爆炸点用这几个点）
      out.add(_mk(
        x: x,
        y: _h + 20,
        vx: cos(angle) * s * 0.3,
        vy: sin(angle) * s,
        bornTime: r * 0.04,
        life: _rnd(0.3, 0.5),
        size: 14,
      ));
      // 爆炸粒子（延迟出生）
      final burstX = x + cos(angle) * s * 0.3 * 0.4;
      final burstY = _h + 20 + sin(angle) * s * 0.4 - preset.gravity * 0.5 * 0.16;
      final perRocket = (n - rockets) ~/ rockets;
      for (int i = 0; i < perRocket; i++) {
        final a = _rnd(0, pi * 2);
        final ss = _rnd(preset.speedMin * 0.6, preset.speedMax * 0.9);
        out.add(_mk(
          x: burstX,
          y: burstY,
          vx: cos(a) * ss,
          vy: sin(a) * ss,
          bornTime: 0.35 + r * 0.05,
        ));
      }
    }
    return out;
  }

  // 7 流星雨：从左上进入，朝右下高速下落
  List<HeartParticle> _meteorShower(int n, double trail) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      // 出生点：屏幕顶部和左侧之外
      final startX = _rnd(-_w * 0.2, _w * 1.0);
      final startY = _rnd(-_h * 0.6, -10);
      final dx = _w * 0.6;
      final dy = _h * 1.3;
      final norm = sqrt(dx * dx + dy * dy);
      final s = _pickSpeed();
      out.add(_mk(
        x: startX,
        y: startY,
        vx: dx / norm * s,
        vy: dy / norm * s,
        bornTime: _rnd(0, 0.7),
        extra: {'trail': trail},
      ));
    }
    return out;
  }

  // 8 许愿灯：从下方各处缓慢上升，带摆动
  List<HeartParticle> _lanternRise(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      out.add(_mk(
        x: _rnd(_w * 0.1, _w * 0.9),
        y: _h + 20,
        vx: _rnd(-15, 15),
        vy: -_pickSpeed(),
        bornTime: _rnd(0, 0.8),
        swingAmp: 1.5,
        swingFreq: 0.8,
        extra: {'phase': _rnd(0, 1)},
      ));
    }
    return out;
  }

  // 9 十字四向
  List<HeartParticle> _crossBurst(int n) {
    final out = <HeartParticle>[];
    const dirs = [
      [1.0, 0.0], [-1.0, 0.0], [0.0, 1.0], [0.0, -1.0],
    ];
    for (int i = 0; i < n; i++) {
      final d = dirs[i % 4];
      final spread = _rnd(-0.15, 0.15);
      final dx = d[0] + spread * d[1];
      final dy = d[1] + spread * d[0];
      final s = _pickSpeed();
      out.add(_mk(
        x: _cx,
        y: _cy,
        vx: dx * s,
        vy: dy * s,
      ));
    }
    return out;
  }

  // 10 漩涡：先被中心吸入一段时间，再爆发
  List<HeartParticle> _vortexSwallow(int n, double vortexT) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      // 起始位置在屏幕各边缘，绕中心角度
      final r = _rnd(_w * 0.15, _w * 0.5);
      final a0 = _rnd(0, pi * 2);
      final sx = _cx + cos(a0) * r;
      final sy = _cy + sin(a0) * r;
      // 速度：先吸到中心，之后爆炸（vortexT 时间内吸入，通过负速度指向中心）
      final dx = _cx - sx;
      final dy = _cy - sy;
      final dd = sqrt(dx * dx + dy * dy) + 1e-6;
      final suckSpeed = dd / vortexT; // 以 suckSpeed 速度刚好 0.x 秒到达中心
      final s = _pickSpeed();
      final ang2 = a0 + _rnd(-0.5, 0.5);
      // 用 born 来避免爆炸前就消失：粒子生命足够长，在 update 里粒子会按速度走
      // 这里直接给「爆发」模式：朝径向爆，bornTime = vortexT - 0.05
      out.add(_mk(
        x: _cx,
        y: _cy,
        vx: cos(ang2) * s,
        vy: sin(ang2) * s,
        bornTime: vortexT + i / n * 0.1,
        extra: {'suckX': sx, 'suckY': sy, 'suckSpeed': suckSpeed},
      ));
    }
    return out;
  }

  // 11 正弦波浪：沿某方向飞，摆动正弦
  List<HeartParticle> _sineWave(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final dir = _rnd(0, pi * 2);
      final s = _pickSpeed();
      out.add(_mk(
        x: _cx + _rnd(-50, 50),
        y: _cy + _rnd(-50, 50),
        vx: cos(dir) * s,
        vy: sin(dir) * s,
        swingAmp: 2.5,
        swingFreq: _rnd(1, 2.5),
        extra: {'phase': _rnd(0, 1)},
        bornTime: _rnd(0, 0.4),
      ));
    }
    return out;
  }

  // 12 五角星：5 个方向
  List<HeartParticle> _starShape(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      // 五角
      final k = i % 5;
      final baseAng = -pi / 2 + k * 2 * pi / 5;
      final spread = _rnd(-0.3, 0.3);
      final a = baseAng + spread;
      final s = _pickSpeed();
      out.add(_mk(
        x: _cx,
        y: _cy,
        vx: cos(a) * s,
        vy: sin(a) * s,
      ));
    }
    return out;
  }

  // 13 放射激光线：N 条，等角度均分
  List<HeartParticle> _radialBeam(int n, int beams) {
    final out = <HeartParticle>[];
    final perBeam = n ~/ beams;
    for (int b = 0; b < beams; b++) {
      final a = b / beams * pi * 2 + _rnd(-0.01, 0.01);
      for (int i = 0; i < perBeam; i++) {
        final s = preset.speedMax + _rnd(-50, 0);
        // 加不同 bornTime 做光束拖尾
        out.add(_mk(
          x: _cx,
          y: _cy,
          vx: cos(a) * s,
          vy: sin(a) * s,
          bornTime: i / perBeam * 0.15,
          life: _rnd(0.8, 1.5),
          size: _rnd(4, 10),
        ));
      }
    }
    return out;
  }

  // 14 涟漪：多层同心环粒子
  List<HeartParticle> _rippleRings(int n, int rings, double ringGap) {
    final out = <HeartParticle>[];
    final perRing = n ~/ rings;
    for (int r = 0; r < rings; r++) {
      final born = r * ringGap;
      // 每环 2 圈速度（稍差错开）
      for (int i = 0; i < perRing; i++) {
        final angle = i / perRing * pi * 2 + (r.isOdd ? pi / perRing : 0);
        final s = preset.speedMin + (preset.speedMax - preset.speedMin) * (1 - r / rings);
        out.add(_mk(
          x: _cx,
          y: _cy,
          vx: cos(angle) * s,
          vy: sin(angle) * s,
          bornTime: born,
        ));
      }
    }
    return out;
  }

  // 15 双心：两团粒子分别朝左右心形轨迹汇聚再扩散
  List<HeartParticle> _twinHearts(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final isLeft = i.isOdd;
      final center = isLeft ? -1.0 : 1.0;
      final t = i / n * pi * 2;
      final xh = 16 * pow(sin(t), 3).toDouble();
      final yh = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t));
      const scale = 6.0;
      final tx = _cx + center * 80 + xh * scale * center;
      final ty = _cy - 50 + yh * scale;
      final s = _pickSpeed() * 0.7;
      final dx = tx - _cx;
      final dy = ty - _cy;
      final len = sqrt(dx * dx + dy * dy) + 1e-6;
      out.add(_mk(
        x: _cx,
        y: _cy,
        vx: dx / len * s,
        vy: dy / len * s,
        bornTime: _rnd(0, 0.5),
        swingAmp: 0.8,
        swingFreq: 1,
      ));
    }
    return out;
  }

  // 16 樱花飘落：从顶部各点出生，水平摆动 + 下落
  List<HeartParticle> _sakuraFall(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      out.add(_mk(
        x: _rnd(-20, _w + 20),
        y: _rnd(-100, -10),
        vx: _rnd(-50, 50),
        vy: _rnd(50, 120),
        bornTime: _rnd(0, 0.6),
        swingAmp: 2,
        swingFreq: _rnd(0.6, 1.5),
        extra: {'phase': _rnd(0, 1)},
        rotSpeed: _rnd(-2, 2),
      ));
    }
    return out;
  }

  // 17 银河旋臂：4 条旋臂螺旋转出
  List<HeartParticle> _galaxySpiral(int n, int arms) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final p = i / n;
      final arm = i % arms;
      final phase = p * 1.8 * pi;
      final armAng = arm / arms * pi * 2;
      final r = 10 + p * (_w * 0.38);
      final theta = armAng + phase;
      final tx = _cx + cos(theta) * r;
      final ty = _cy + sin(theta) * r;
      final s = preset.speedMin + p * (preset.speedMax - preset.speedMin);
      // 速度方向：略微切向
      final ang = theta + pi / 2 * 0.35;
      out.add(_mk(
        x: _cx,
        y: _cy,
        vx: cos(ang) * s * 0.35,
        vy: sin(ang) * s * 0.35,
        bornTime: p * 0.5,
        life: _rnd(3, 5),
      ));
      // 让实际位置到 tx/ty 靠「出生点就在目标附近」
      final last = out.last;
      last.x = tx;
      last.y = ty;
    }
    return out;
  }

  // 18 吹泡泡：底部生成，上升，大小不一
  List<HeartParticle> _bubbleBlow(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      out.add(_mk(
        x: _rnd(_w * 0.2, _w * 0.8),
        y: _h + 20,
        vx: _rnd(-20, 20),
        vy: -_rnd(preset.speedMin, preset.speedMax),
        bornTime: _rnd(0, 0.8),
      ));
    }
    return out;
  }

  // 19 脉冲心波：按心形轮廓多轮依次延迟
  List<HeartParticle> _pulseHeartWave(int n, int waves, double waveGap) {
    final out = <HeartParticle>[];
    final perWave = n ~/ waves;
    for (int w = 0; w < waves; w++) {
      final born = w * waveGap;
      final scale = 7.0 + w * 2.5;
      for (int i = 0; i < perWave; i++) {
        final t = i / perWave * pi * 2;
        final x = 16 * pow(sin(t), 3).toDouble();
        final y = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t));
        final px = _cx + x * scale;
        final py = _cy - 50 + y * scale;
        final outX = x;
        final outY = -y;
        final nn = sqrt(outX * outX + outY * outY) + 1e-6;
        final s = preset.speedMin + w * 50;
        out.add(_mk(
          x: px,
          y: py,
          vx: outX / nn * s,
          vy: outY / nn * s,
          bornTime: born,
        ));
      }
    }
    return out;
  }

  // 20 激光十字：8 根直线
  List<HeartParticle> _laserLines(int n) {
    final out = <HeartParticle>[];
    const dirs = [
      [1.0, 0.0], [-1.0, 0.0], [0.0, 1.0], [0.0, -1.0],
      [0.707, 0.707], [-0.707, 0.707], [0.707, -0.707], [-0.707, -0.707],
    ];
    const beams = 8;
    final perBeam = n ~/ beams;
    for (int b = 0; b < beams; b++) {
      final d = dirs[b];
      for (int i = 0; i < perBeam; i++) {
        out.add(_mk(
          x: _cx,
          y: _cy,
          vx: d[0] * preset.speedMax,
          vy: d[1] * preset.speedMax,
          bornTime: i / perBeam * 0.1,
          life: _rnd(0.6, 1.2),
        ));
      }
    }
    return out;
  }

  // 21 香烟烟雾：底部出，缓慢扩散+变大
  List<HeartParticle> _smokePuff(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      out.add(_mk(
        x: _cx + _rnd(-20, 20),
        y: _cy + 120,
        vx: _rnd(-20, 20),
        vy: -_rnd(30, 70),
        bornTime: _rnd(0, 0.7),
        life: _rnd(3.5, 5.5),
        size: _rnd(40, 90),
      ));
    }
    return out;
  }

  // 22 闪电分形：从中心向各方向随机分形分支
  List<HeartParticle> _sparkBranches(int n) {
    final out = <HeartParticle>[];
    final branches = 6;
    final perBranch = n ~/ branches;
    for (int b = 0; b < branches; b++) {
      double x = _cx, y = _cy;
      final ang = b / branches * pi * 2 + _rnd(-0.2, 0.2);
      double dx = cos(ang);
      double dy = sin(ang);
      for (int i = 0; i < perBranch; i++) {
        final s = _pickSpeed();
        dx += _rnd(-0.3, 0.3);
        dy += _rnd(-0.3, 0.3);
        final nrm = sqrt(dx * dx + dy * dy);
        dx /= nrm;
        dy /= nrm;
        out.add(_mk(
          x: x,
          y: y,
          vx: dx * s,
          vy: dy * s,
          bornTime: i / perBranch * 0.3,
          life: _rnd(0.6, 1.1),
        ));
        x += dx * s * 0.08;
        y += dy * s * 0.08;
      }
    }
    return out;
  }

  // 23 星尘漂浮：屏幕全范围出生，缓慢向随机方向
  List<HeartParticle> _stardustDrifting(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final ang = _rnd(0, pi * 2);
      final s = _pickSpeed();
      out.add(_mk(
        x: _rnd(0, _w),
        y: _rnd(0, _h),
        vx: cos(ang) * s,
        vy: sin(ang) * s,
        bornTime: _rnd(0, 0.8),
        life: _rnd(2.5, 4.5),
      ));
    }
    return out;
  }

  // 24 花瓣漂浮：从顶部飘落，摆动
  List<HeartParticle> _petalFloating(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      out.add(_mk(
        x: _rnd(-20, _w + 20),
        y: _rnd(-120, -20),
        vx: _rnd(-40, 40),
        vy: _rnd(40, 90),
        bornTime: _rnd(0, 0.7),
        swingAmp: 2,
        swingFreq: _rnd(0.6, 1.4),
        extra: {'phase': _rnd(0, 1)},
        rotSpeed: _rnd(-3, 3),
      ));
    }
    return out;
  }

  // 25 羽毛飘动：更慢、更大幅度摆动
  List<HeartParticle> _featherDrift(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      out.add(_mk(
        x: _rnd(0, _w),
        y: _rnd(-120, -20),
        vx: _rnd(-30, 30),
        vy: _rnd(30, 70),
        bornTime: _rnd(0, 0.8),
        swingAmp: 4,
        swingFreq: _rnd(0.4, 0.8),
        extra: {'phase': _rnd(0, 1)},
        rotSpeed: _rnd(-1, 1),
      ));
    }
    return out;
  }

  // 26 DNA 双螺旋：垂直方向上升，两组相位差 180°
  List<HeartParticle> _dnaHelix(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final phase = i / n;
      final strand = i % 2;
      final y = _h * 0.9 - phase * _h * 1.0;
      const helixW = 55.0;
      final theta = phase * pi * 4 + strand * pi;
      final x = _cx + (strand == 0 ? -1 : 1) * cos(theta) * helixW;
      final s = _pickSpeed();
      out.add(_mk(
        x: x,
        y: y,
        vx: sin(theta) * s * 0.3,
        vy: -s * 0.6,
        bornTime: phase * 0.8,
        rotSpeed: _rnd(-0.5, 0.5),
      ));
    }
    return out;
  }

  // 27 螺旋伞：扇形排列从中心打开（伞状）
  List<HeartParticle> _umbrellaOpen(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      // 角度限制在 -160° 到 -20°（上半圆）
      final a = (-pi * 140 / 180) + i / n * pi * 120 / 180;
      final s = _pickSpeed();
      out.add(_mk(
        x: _cx,
        y: _cy + 60,
        vx: cos(a) * s,
        vy: sin(a) * s,
        bornTime: _rnd(0, 0.2),
        life: _rnd(2, 3.5),
      ));
    }
    return out;
  }

  // 28 玫瑰星云：极坐标 r = cos(kθ) 玫瑰线采样 + 大小层
  List<HeartParticle> _roseNebula(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final layer = i / n;
      final t = _rnd(0, pi * 2);
      const k = 4; // 4 叶玫瑰
      final rr = cos(k * t).abs();
      final maxR = _w * 0.42;
      final r = rr * maxR * (0.3 + layer * 0.9);
      final px = _cx + cos(t) * r;
      final py = _cy + sin(t) * r;
      final s = preset.speedMin * 0.25 + layer * preset.speedMax * 0.25;
      final vAng = t + _rnd(-0.2, 0.2);
      out.add(_mk(
        x: px,
        y: py,
        vx: cos(vAng) * s,
        vy: sin(vAng) * s,
        bornTime: _rnd(0, 0.6),
        life: _rnd(2.5, 5),
      ));
    }
    return out;
  }

  // 29 蒲公英种子：从中心扩散，速度很小，旋转慢
  List<HeartParticle> _dandelionSeed(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final a = _rnd(0, pi * 2);
      final s = _pickSpeed();
      out.add(_mk(
        x: _cx,
        y: _cy,
        vx: cos(a) * s,
        vy: sin(a) * s - 30,
        bornTime: _rnd(0, 0.6),
        swingAmp: 2,
        swingFreq: 0.6,
        extra: {'phase': _rnd(0, 1)},
      ));
    }
    return out;
  }

  // 30 钻石碎裂：从中心 8 方向爆炸，钻石形状
  List<HeartParticle> _diamondShatter(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final a = _rnd(0, pi * 2);
      final s = _pickSpeed();
      out.add(_mk(
        x: _cx,
        y: _cy,
        vx: cos(a) * s,
        vy: sin(a) * s,
      ));
    }
    return out;
  }

  // 31 沙漏：上下两半对称朝向中心交叉
  List<HeartParticle> _hourglass(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      if (i.isEven) {
        // 上面一半：从上方向中心收束
        final x = _rnd(_w * 0.25, _w * 0.75);
        final y = _rnd(0, _h * 0.2);
        final dx = _cx - x;
        final dy = _cy - y;
        final d = sqrt(dx * dx + dy * dy);
        final s = _pickSpeed();
        out.add(_mk(
          x: x,
          y: y,
          vx: dx / d * s,
          vy: dy / d * s,
          bornTime: _rnd(0, 0.2),
        ));
      } else {
        // 下面一半：从下方向中心收束
        final x = _rnd(_w * 0.25, _w * 0.75);
        final y = _rnd(_h * 0.8, _h);
        final dx = _cx - x;
        final dy = _cy - y;
        final d = sqrt(dx * dx + dy * dy);
        final s = _pickSpeed();
        out.add(_mk(
          x: x,
          y: y,
          vx: dx / d * s,
          vy: dy / d * s,
          bornTime: _rnd(0, 0.2),
        ));
      }
    }
    return out;
  }

  // 32 黑洞：先生成边缘粒子旋转吸附，延迟后大爆炸
  List<HeartParticle> _blackHole(int n, double bhT) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final p = i / n;
      final r = _rnd(_w * 0.15, _w * 0.48);
      final a0 = _rnd(0, pi * 2);
      final tx = _cx + cos(a0) * r;
      final ty = _cy + sin(a0) * r;
      // 爆炸方向
      final a = a0 + _rnd(-0.3, 0.3);
      final s = _rnd(preset.speedMax * 0.6, preset.speedMax);
      out.add(_mk(
        x: tx,
        y: ty,
        vx: cos(a) * s,
        vy: sin(a) * s,
        bornTime: bhT + p * 0.25,
        life: _rnd(2, 3.5),
        swingAmp: 1.5,
        swingFreq: 1,
      ));
    }
    return out;
  }

  // 33 时钟 12 方向
  List<HeartParticle> _clockDial(int n) {
    final out = <HeartParticle>[];
    final perDir = n ~/ 12;
    for (int d = 0; d < 12; d++) {
      final a = -pi / 2 + d * pi / 6;
      for (int i = 0; i < perDir; i++) {
        final s = _pickSpeed();
        out.add(_mk(
          x: _cx,
          y: _cy,
          vx: cos(a) * s,
          vy: sin(a) * s,
          bornTime: i / perDir * 0.2,
        ));
      }
    }
    return out;
  }

  // 34 摩天轮：圆周飞行，按角度分布，有半径变化
  List<HeartParticle> _ferrisWheel(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final p = i / n;
      final ang = p * pi * 2;
      final r0 = 140.0 + sin(p * pi * 6) * 30;
      final px = _cx + cos(ang) * r0;
      final py = _cy - 30 + sin(ang) * r0;
      // 切向速度 + 小径向
      const vAng = 1.8;
      final vx = -sin(ang) * r0 * vAng;
      final vy = cos(ang) * r0 * vAng;
      out.add(_mk(
        x: px,
        y: py,
        vx: vx * 0.04,
        vy: vy * 0.04,
        bornTime: 0,
        life: _rnd(3.5, 5),
      ));
    }
    return out;
  }

  // 35 风车：4 个扇叶，快速旋转抛出
  List<HeartParticle> _pinwheelSpin(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final p = i / n;
      final blade = i % 4;
      final a = blade * pi / 2 + p * pi * 6; // 旋转 6 圈
      final r = 20 + p * 180;
      final tx = _cx + cos(a) * r;
      final ty = _cy + sin(a) * r;
      final dx = tx - _cx;
      final dy = ty - _cy;
      final dd = sqrt(dx * dx + dy * dy) + 1e-6;
      final s = preset.speedMin + p * (preset.speedMax - preset.speedMin);
      out.add(_mk(
        x: _cx,
        y: _cy,
        vx: dx / dd * s,
        vy: dy / dd * s,
        bornTime: p * 0.6,
      ));
    }
    return out;
  }

  // 36 泡泡海洋上升
  List<HeartParticle> _bubbleBathRise(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      out.add(_mk(
        x: _rnd(0, _w),
        y: _h + _rnd(10, 120),
        vx: _rnd(-40, 40),
        vy: -_pickSpeed(),
        bornTime: _rnd(0, 0.8),
      ));
    }
    return out;
  }

  // 37 水滴溅起：先有一个中心下落水滴，再散开一圈小水花
  List<HeartParticle> _waterDropSplash(int n) {
    final out = <HeartParticle>[];
    // 水滴（先放 1 颗大心代表水滴在中心上方落下）
    out.add(_mk(
      x: _cx,
      y: _cy - 150,
      vx: 0,
      vy: 800,
      size: 60,
      life: 0.4,
      bornTime: 0,
    ));
    // 溅起水花粒子（从中心朝上抛）
    for (int i = 0; i < n - 1; i++) {
      final a = _rnd(-pi * 0.95, -pi * 0.05); // 朝上半圆
      final s = _pickSpeed();
      out.add(_mk(
        x: _cx,
        y: _cy + 10,
        vx: cos(a) * s,
        vy: sin(a) * s,
        bornTime: 0.38 + _rnd(0, 0.08),
      ));
    }
    return out;
  }

  // 38 彩带飞舞：从顶部各方向飞舞下落
  List<HeartParticle> _ribbonDance(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      out.add(_mk(
        x: _rnd(-20, _w + 20),
        y: _rnd(-120, -20),
        vx: _rnd(-150, 150),
        vy: _rnd(80, 180),
        bornTime: _rnd(0, 0.7),
        rotSpeed: _rnd(-6, 6),
        swingAmp: 3,
        swingFreq: _rnd(0.5, 1.2),
        extra: {'phase': _rnd(0, 1)},
      ));
    }
    return out;
  }

  // 39 钻石雨：从上往下落
  List<HeartParticle> _diamondRain(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      out.add(_mk(
        x: _rnd(0, _w),
        y: _rnd(-200, -20),
        vx: _rnd(-30, 30),
        vy: _pickSpeed(),
        bornTime: _rnd(0, 0.7),
        rotSpeed: _rnd(-3, 3),
      ));
    }
    return out;
  }

  // 40 霓虹轨迹：从中心向各个方向，带拖尾
  List<HeartParticle> _neonGlowTrail(int n, double trail) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final a = _rnd(0, pi * 2);
      final s = _pickSpeed();
      out.add(_mk(
        x: _cx + _rnd(-30, 30),
        y: _cy + _rnd(-30, 30),
        vx: cos(a) * s,
        vy: sin(a) * s,
        bornTime: _rnd(0, 0.3),
        extra: {'trail': trail},
        life: _rnd(1.5, 2.8),
      ));
    }
    return out;
  }

  // 41 像素点阵：在心形像素点阵采样像素，再爆散
  List<HeartParticle> _pixelHeartGrid(int n) {
    final out = <HeartParticle>[];
    int produced = 0;
    const grid = 22;
    // (心形像素点阵采用参数化绘制，不需要 scale 常量)
    // 生成心形区域的像素
    final pixels = <List<double>>[];
    for (int gy = -grid; gy <= grid; gy++) {
      for (int gx = -grid; gx <= grid; gx++) {
        // 心形隐式方程：(x^2 + y^2 - 1)^3 - x^2 * y^3 <= 0
        final x = gx / grid * 1.4;
        final y = -gy / grid * 1.4;
        final f = pow(x * x + y * y - 1, 3) - x * x * pow(y, 3);
        if (f <= 0) pixels.add([gx.toDouble(), gy.toDouble()]);
      }
    }
    pixels.shuffle(random);
    final cell = 10.0;
    for (int i = 0; i < n && produced < pixels.length; i++, produced++) {
      final p = pixels[i % pixels.length];
      final gx = p[0];
      final gy = p[1];
      final px = _cx + gx * cell;
      final py = _cy - 30 + gy * cell;
      // 方向：向外
      final dx = gx;
      final dy = -gy;
      final d = sqrt(dx * dx + dy * dy) + 1e-6;
      final s = _rnd(80, 260);
      out.add(_mk(
        x: px,
        y: py,
        vx: dx / d * s,
        vy: dy / d * s,
        bornTime: _rnd(0, 0.3),
        size: _rnd(8, 14),
      ));
    }
    return out;
  }

  // 42 彩屑派对：从上方彩屑撒下，旋转+大角度抛射
  List<HeartParticle> _confettiParty(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      out.add(_mk(
        x: _rnd(-50, _w + 50),
        y: _rnd(-250, -20),
        vx: _rnd(-200, 200),
        vy: _rnd(100, 350),
        bornTime: _rnd(0, 0.5),
        rotSpeed: _rnd(-10, 10),
      ));
    }
    return out;
  }

  // 43 叠心升起：多个大小爱心上下叠缓慢上升
  List<HeartParticle> _stackLoveHearts(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      final p = i / n;
      out.add(_mk(
        x: _cx + _rnd(-30, 30),
        y: _h + 20 + p * 200,
        vx: _rnd(-15, 15),
        vy: -_rnd(preset.speedMin, preset.speedMax),
        bornTime: _rnd(0, 0.6),
        size: 20 + p * 60,
        life: _rnd(3, 5),
        rotSpeed: _rnd(-0.8, 0.8),
      ));
    }
    return out;
  }

  // 44 量子跃迁：屏幕各处随机出现小粒子，缓慢合并然后散
  List<HeartParticle> _quantumPulse(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      // 起始全屏幕各处
      final sx = _rnd(0, _w);
      final sy = _rnd(0, _h);
      // 目标方向：朝中心偏移，然后向外
      final toCx = _cx - sx;
      final toCy = _cy - sy;
      final d = sqrt(toCx * toCx + toCy * toCy) + 1e-6;
      final s = _pickSpeed();
      out.add(_mk(
        x: sx,
        y: sy,
        vx: toCx / d * s * 0.3,
        vy: toCy / d * s * 0.3,
        bornTime: _rnd(0, 0.4),
        life: _rnd(2.5, 4),
        rotSpeed: _rnd(-2, 2),
      ));
    }
    return out;
  }

  // 45 彩虹爆发：按角度等分颜色扇形
  List<HeartParticle> _rainbowBurst(int n) {
    final out = <HeartParticle>[];
    final colors = preset.palette;
    for (int i = 0; i < n; i++) {
      final p = i / n;
      final angle = p * pi * 2;
      final colorIdx = (p * colors.length).floor() % colors.length;
      final s = _pickSpeed();
      out.add(_mk(
        x: _cx,
        y: _cy,
        vx: cos(angle) * s,
        vy: sin(angle) * s,
        color: colors[colorIdx],
      ));
    }
    return out;
  }

  // 46 冲击波圆盘：5 层圆盘按时间间隔膨胀
  List<HeartParticle> _shockwaveDisc(int n, int discs) {
    final out = <HeartParticle>[];
    final perDisc = n ~/ discs;
    for (int d = 0; d < discs; d++) {
      final born = d * 0.1;
      final speed = preset.speedMin + (preset.speedMax - preset.speedMin) * (1 - d / discs);
      for (int i = 0; i < perDisc; i++) {
        final a = i / perDisc * pi * 2;
        out.add(_mk(
          x: _cx,
          y: _cy,
          vx: cos(a) * speed,
          vy: sin(a) * speed,
          bornTime: born,
          life: _rnd(1, 2),
        ));
      }
    }
    return out;
  }

  // 47 萤火虫：小光点各处缓慢上升+闪烁
  List<HeartParticle> _fireflyGlow(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      out.add(_mk(
        x: _rnd(0, _w),
        y: _rnd(_h * 0.3, _h * 1.0),
        vx: _rnd(-30, 30),
        vy: -_rnd(20, 80),
        bornTime: _rnd(0, 0.8),
        life: _rnd(3, 5),
        swingAmp: 2,
        swingFreq: 0.8,
        extra: {'phase': _rnd(0, 1)},
        size: _rnd(preset.sizeMin, preset.sizeMax),
      ));
    }
    return out;
  }

  // 48 玫瑰绽放：多层花瓣展开
  List<HeartParticle> _roseBloom(int n) {
    final out = <HeartParticle>[];
    final layers = 6;
    final perLayer = n ~/ layers;
    for (int L = 0; L < layers; L++) {
      final born = L * 0.07;
      final r = 40.0 + L * 28;
      final count = perLayer;
      final twist = L * 0.3;
      for (int i = 0; i < count; i++) {
        final p = i / count;
        final a = twist + p * pi * 2;
        final s = _rnd(preset.speedMin * 0.2, preset.speedMax * 0.4);
        final tx = _cx + cos(a) * r;
        final ty = _cy - 30 + sin(a) * r * 0.8;
        out.add(_mk(
          x: _cx,
          y: _cy - 30,
          vx: (tx - _cx) * s / r,
          vy: (ty - (_cy - 30)) * s / (r * 0.8 + 1e-6),
          bornTime: born,
          life: _rnd(2.5, 4.5),
        ));
      }
    }
    return out;
  }

  // 49 水晶闪耀：各处位置水晶缓慢浮动再扩散
  List<HeartParticle> _crystalShine(int n) {
    final out = <HeartParticle>[];
    for (int i = 0; i < n; i++) {
      // 初始在中心附近各层
      final a = _rnd(0, pi * 2);
      final r = _rnd(20, 200);
      final px = _cx + cos(a) * r;
      final py = _cy + sin(a) * r * 0.8;
      final s = _pickSpeed() * 0.6;
      out.add(_mk(
        x: px,
        y: py,
        vx: cos(a) * s,
        vy: sin(a) * s,
        bornTime: _rnd(0, 0.6),
        life: _rnd(2, 4),
        rotSpeed: _rnd(-2, 2),
      ));
    }
    return out;
  }

  // 50 终章：爆发 + 上升 + 星尘 + 心形轮廓 混合
  List<HeartParticle> _grandFinale(int n) {
    final out = <HeartParticle>[];
    // A. 爆发粒子 35%
    final aN = (n * 0.35).toInt();
    for (int i = 0; i < aN; i++) {
      final a = _rnd(0, pi * 2);
      final s = _pickSpeed();
      out.add(_mk(
        x: _cx,
        y: _cy,
        vx: cos(a) * s,
        vy: sin(a) * s,
        bornTime: 0,
      ));
    }
    // B. 心形轮廓粒子 25%
    final bN = (n * 0.25).toInt();
    for (int i = 0; i < bN; i++) {
      final t = i / bN * pi * 2;
      final x = 16 * pow(sin(t), 3).toDouble();
      final y = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t));
      const scale = 10.0;
      final px = _cx + x * scale;
      final py = _cy - 50 + y * scale;
      final outX = x;
      final outY = -y;
      final nn = sqrt(outX * outX + outY * outY) + 1e-6;
      final s = _rnd(100, 250);
      out.add(_mk(
        x: px,
        y: py,
        vx: outX / nn * s,
        vy: outY / nn * s,
        bornTime: _rnd(0.15, 0.5),
      ));
    }
    // C. 许愿灯上升 20%
    final cN = (n * 0.20).toInt();
    for (int i = 0; i < cN; i++) {
      out.add(_mk(
        x: _rnd(_w * 0.1, _w * 0.9),
        y: _h + 20,
        vx: _rnd(-25, 25),
        vy: -_rnd(60, 150),
        bornTime: _rnd(0.1, 0.6),
        swingAmp: 2,
        swingFreq: 1,
        extra: {'phase': _rnd(0, 1)},
      ));
    }
    // D. 星尘 20%
    final dN = n - aN - bN - cN;
    for (int i = 0; i < dN; i++) {
      final ang = _rnd(0, pi * 2);
      final s = _rnd(40, 180);
      out.add(_mk(
        x: _rnd(0, _w),
        y: _rnd(0, _h),
        vx: cos(ang) * s,
        vy: sin(ang) * s,
        bornTime: _rnd(0.2, 0.8),
        life: _rnd(2.5, 4.5),
        extra: {'trail': 0.3},
      ));
    }
    return out;
  }
}

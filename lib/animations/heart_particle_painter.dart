part of 'heart_particle_animation.dart';

// ──────────────────────────────────────────────
// 爱心路径工具
// ──────────────────────────────────────────────

Path heartPath(double cx, double cy, double size) {
  final s = size;
  return Path()
    ..moveTo(cx, cy + s * 0.35)
    ..cubicTo(cx - s * 0.5, cy - s * 0.1, cx - s, cy + s * 0.1, cx - s * 0.5, cy + s * 0.5)
    ..cubicTo(cx - s * 0.3, cy + s * 0.75, cx, cy + s * 0.9, cx, cy + s)
    ..cubicTo(cx, cy + s * 0.9, cx + s * 0.3, cy + s * 0.75, cx + s * 0.5, cy + s * 0.5)
    ..cubicTo(cx + s, cy + s * 0.1, cx + s * 0.5, cy - s * 0.1, cx, cy + s * 0.35)
    ..close();
}

/// 五角星
Path starPath(double cx, double cy, double radius) {
  final path = Path();
  const n = 5;
  for (int i = 0; i < n * 2; i++) {
    final r = (i.isEven) ? radius : radius * 0.42;
    final a = -pi / 2 + i * pi / n;
    final x = cx + cos(a) * r;
    final y = cy + sin(a) * r;
    if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
  }
  path.close();
  return path;
}

/// 菱形（钻石）
Path diamondPath(double cx, double cy, double size) {
  return Path()
    ..moveTo(cx, cy - size)
    ..lineTo(cx + size * 0.6, cy)
    ..lineTo(cx, cy + size)
    ..lineTo(cx - size * 0.6, cy)
    ..close();
}

/// 花瓣（梨形）
Path petalPath(double cx, double cy, double size) {
  final s = size;
  return Path()
    ..moveTo(cx, cy + s)
    ..cubicTo(cx - s * 0.8, cy + s * 0.3, cx - s * 0.5, cy - s * 0.6, cx, cy - s)
    ..cubicTo(cx + s * 0.5, cy - s * 0.6, cx + s * 0.8, cy + s * 0.3, cx, cy + s)
    ..close();
}

/// 丝带
Path ribbonPath(double cx, double cy, double w, double h) {
  final r = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
    const Radius.circular(3),
  );
  return Path()..addRRect(r);
}

// ──────────────────────────────────────────────
// 爱心粒子动画画笔（增强版）
// ──────────────────────────────────────────────

class HeartParticlePainter extends CustomPainter {
  final List<HeartParticle> particles;
  final double animTime;
  final double fadeIn;
  final double fadeOut;
  final HeartAnimationPreset preset;
  final List<_StarPoint> bgStars;
  final List<_PulseRing> pulseRings;

  HeartParticlePainter({
    required this.particles,
    required this.animTime,
    required this.fadeIn,
    required this.fadeOut,
    required this.preset,
    required this.bgStars,
    required this.pulseRings,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final opacity = fadeIn * fadeOut;

    // ── 1. 背景 ──
    _drawBackground(canvas, size, opacity, cx, cy);

    // ── 2. 中心大爱心 ──（在粒子下面，粒子更耀眼）
    final centerOpacity = opacity;
    _drawCenterHeart(canvas, cx, cy, size, centerOpacity);

    // ── 3. 脉冲环 ──
    _drawPulseRings(canvas, cx, cy, opacity);

    // ── 4. 粒子 ──
    for (final p in particles) {
      if (p.life <= 0) continue;
      if (animTime < p.bornTime) continue;
      _drawSingleParticle(canvas, p, opacity);
    }

    // ── 5. 文字 ──
    final text = preset.customText ?? '想  你';
    if (text.isNotEmpty && fadeIn > 0.3) {
      _drawText(canvas, text, cx, cy, opacity);
    }
  }

  // ─── 背景 ───────────────────────
  void _drawBackground(Canvas canvas, Size size, double opacity, double cx, double cy) {
    switch (preset.bg) {
      case BgStyle.solidGradient:
      case BgStyle.starry:
      case BgStyle.sparkleField:
        final bgPaint = Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            colors: [
              Color(0x66000000).withValues(alpha: opacity * 0.3),
              Color(0xCC000000).withValues(alpha: opacity * 0.85),
            ],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: size.width));
        canvas.drawRect(Offset.zero & size, bgPaint);
        break;
      case BgStyle.smokeCloud:
        final bgPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0x801A0018).withValues(alpha: opacity * 0.7),
              const Color(0xC02B0033).withValues(alpha: opacity * 0.9),
            ],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: size.width));
        canvas.drawRect(Offset.zero & size, bgPaint);
        break;
    }

    // ── 星点 / 烟雾 / 闪耀场 ──
    final t = animTime;
    for (final s in bgStars) {
      final x = size.width * s.x;
      final y = size.height * s.y;
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * pi * 2 * s.speed + s.phase));
      final a = opacity * s.brightness * twinkle;
      if (s.smoke) {
        // 烟雾：柔光圆
        final smokePaint = Paint()
          ..shader = RadialGradient(
            colors: [
              preset.centerColors[0].withValues(alpha: a),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: Offset(x, y), radius: s.size));
        canvas.drawCircle(Offset(x, y), s.size, smokePaint);
      } else {
        canvas.drawCircle(
          Offset(x, y),
          s.size,
          Paint()..color = Colors.white.withValues(alpha: a.clamp(0, 1)),
        );
        // 闪耀场加十字光晕
        if (preset.bg == BgStyle.sparkleField) {
          final ray = Paint()
            ..color = Colors.white.withValues(alpha: (a * 0.6).clamp(0, 1));
          canvas.drawLine(Offset(x - s.size * 3, y), Offset(x + s.size * 3, y), ray);
          canvas.drawLine(Offset(x, y - s.size * 3), Offset(x, y + s.size * 3), ray);
        }
      }
    }
  }

  // ─── 中心大爱心 ───────────────────────
  void _drawCenterHeart(Canvas canvas, double cx, double cy, Size size, double opacity) {
    if (preset.centerMode == CenterHeartMode.none) return;
    final t = animTime;

    // 根据模式计算 scale / rotate3dOffset / 碎裂因子
    double scale;
    double rotateY = 0;
    double rotateZ = 0;
    double shatterAlpha = 1.0;

    switch (preset.centerMode) {
      case CenterHeartMode.breathe:
        if (t < 0.2) {
          final p = t / 0.2;
          scale = p * (1.0 + 0.15 * sin(p * pi));
        } else {
          scale = 1.0 + 0.08 * sin((t - 0.2) * pi * 7);
        }
        break;
      case CenterHeartMode.heartbeat:
        // 咚-哒：两次心跳节奏
        double hb(double phase) {
          // phase 0~1 → 每 0.4 秒一次心跳
          final loop = (phase / 0.4) % 1;
          return 1.0 + 0.12 * exp(-pow(loop - 0.2, 2) / 0.015);
        }

        scale = t < 0.2
            ? t / 0.2 * (1.0 + 0.2 * sin(t / 0.2 * pi))
            : hb(t - 0.2);
        break;
      case CenterHeartMode.rotate3d:
        scale = 0.95 + 0.06 * sin(t * pi * 4);
        rotateY = sin(t * pi * 2) * 0.8;
        rotateZ = sin(t * pi * 1) * 0.1;
        break;
      case CenterHeartMode.pulseRing:
        scale = 1.0 + 0.05 * sin(t * pi * 6);
        break;
      case CenterHeartMode.shatterBurst:
        // 0.3 前正常显示，0.3~0.5 爆炸破碎
        if (t < 0.3) {
          final p = t / 0.3;
          scale = 0.9 + 0.2 * sin(p * pi);
        } else if (t < 0.5) {
          final p = (t - 0.3) / 0.2;
          scale = 1.0 + p * 3.5;
          shatterAlpha = 1 - p;
        } else {
          scale = 0;
          shatterAlpha = 0;
        }
        break;
      case CenterHeartMode.roseUnfold:
        // 花瓣绽放：先缩后放大
        if (t < 0.35) {
          final p = t / 0.35;
          scale = 0.6 + 0.4 * (1 - cos(p * pi)) / 2 * 1.2;
        } else {
          scale = 1.0 + 0.07 * sin((t - 0.35) * pi * 5);
        }
        rotateZ = sin(t * pi) * 0.08;
        break;
      case CenterHeartMode.none:
        scale = 0;
        break;
    }

    if (scale <= 0.01 || shatterAlpha <= 0.01) return;

    final centerScale = scale;
    final heartSize = 110.0 * centerScale;
    final heartCy = cy - heartSize * 0.35;

    // 3D rotate：压一下 x 方向，模拟旋转
    final xSqueeze = 0.55 + 0.45 * (0.5 + 0.5 * cos(rotateY));

    // 光晕
    final glowR = 160.0 * centerScale;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          preset.centerColors[0]
              .withValues(alpha: opacity * shatterAlpha * 0.5),
          preset.centerColors[0]
              .withValues(alpha: opacity * shatterAlpha * 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, heartCy + heartSize * 0.35), radius: glowR));
    canvas.drawCircle(Offset(cx, heartCy + heartSize * 0.35), glowR, glowPaint);

    canvas.save();
    canvas.translate(cx, heartCy + heartSize * 0.35);
    canvas.rotate(rotateZ);
    canvas.scale(xSqueeze, 1);
    canvas.translate(-cx, -(heartCy + heartSize * 0.35));

    final path = heartPath(cx, heartCy, heartSize);
    final heartPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          preset.centerColors[0].withValues(alpha: opacity * shatterAlpha),
          preset.centerColors[1].withValues(alpha: opacity * shatterAlpha),
        ],
      ).createShader(path.getBounds());
    canvas.drawPath(path, heartPaint);

    // 高光
    final hlPath = heartPath(cx - heartSize * 0.22, heartCy - heartSize * 0.12, heartSize * 0.28);
    final hlPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.32 * opacity * shatterAlpha);
    canvas.drawPath(hlPath, hlPaint);

    // 轮廓（绽放模式）
    if (preset.centerMode == CenterHeartMode.roseUnfold) {
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.3 * opacity * shatterAlpha);
      canvas.drawPath(path, border);
    }

    canvas.restore();
  }

  // ─── 脉冲环 ─────────────────────
  void _drawPulseRings(Canvas canvas, double cx, double cy, double opacity) {
    for (final r in pulseRings) {
      final life = ((animTime - r.startT) / 0.5).clamp(0.0, 1.0);
      final radius = 40.0 + life * 320;
      final alpha = opacity * (1 - life);
      // 外发光环
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..shader = RadialGradient(
          colors: [
            preset.centerColors[0].withValues(alpha: 0),
            preset.centerColors[0].withValues(alpha: alpha * 0.7),
            Colors.transparent,
          ],
          stops: const [0.8, 0.95, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
      canvas.drawCircle(Offset(cx, cy), radius, ring);
    }
  }

  // ─── 粒子形状绘制 ─────────────────
  void _drawSingleParticle(Canvas canvas, HeartParticle p, double opacity) {
    final alpha = (p.life * 255 * opacity).clamp(0.0, 255.0) / 255.0;
    final color = p.color.withValues(alpha: alpha);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 霓虹轨迹拖尾
    if (p.trail.length > 1 && (p.extra['trail'] ?? 0) > 0.1) {
      final trailAlpha = (p.extra['trail'] ?? 0.5) * alpha;
      for (int i = 0; i < p.trail.length - 1; i++) {
        final a = p.trail[i];
        final b = p.trail[i + 1];
        final ta = trailAlpha * (1 - i / p.trail.length);
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = p.color.withValues(alpha: ta)
            ..strokeWidth = p.size * 0.25 * (1 - i / p.trail.length)
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.2),
        );
      }
    }

    canvas.save();
    canvas.translate(p.x, p.y);
    canvas.rotate(p.rotation);
    final s = p.size;

    switch (p.shape) {
      case ParticleShape.heart:
        canvas.drawPath(heartPath(0, -s * 0.5, s), paint);
        break;
      case ParticleShape.circle:
        canvas.drawCircle(Offset(0, 0), s * 0.5, paint
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.0));
        break;
      case ParticleShape.star:
        canvas.drawPath(starPath(0, 0, s * 0.6), paint);
        break;
      case ParticleShape.square:
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: s, height: s),
          paint,
        );
        break;
      case ParticleShape.diamond:
        // 钻石：菱形 + 渐变光泽
        final dp = diamondPath(0, 0, s * 0.6);
        final grad = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            p.color.withValues(alpha: 1),
            p.color.withValues(alpha: 0.4),
            p.color.withValues(alpha: 1),
          ],
        );
        paint.shader = grad.createShader(dp.getBounds());
        canvas.drawPath(dp, paint);
        break;
      case ParticleShape.petal:
        canvas.drawPath(petalPath(0, 0, s * 0.6), paint);
        break;
      case ParticleShape.ribbon:
        canvas.drawPath(ribbonPath(0, 0, s * 1.4, s * 0.28), paint);
        break;
      case ParticleShape.sparkle:
        // 光晕圆 + 十字光芒
        final glow = Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 1), Colors.transparent],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: s * 0.5));
        canvas.drawCircle(Offset.zero, s * 0.5, glow);
        final ray = Paint()
          ..color = color
          ..strokeCap = StrokeCap.round
          ..strokeWidth = max(1, s * 0.08);
        canvas.drawLine(Offset(-s, 0), Offset(s, 0), ray);
        canvas.drawLine(Offset(0, -s), Offset(0, s), ray);
        canvas.drawLine(Offset(-s * 0.7, -s * 0.7), Offset(s * 0.7, s * 0.7), ray);
        canvas.drawLine(Offset(-s * 0.7, s * 0.7), Offset(s * 0.7, -s * 0.7), ray);
        break;
    }
    canvas.restore();
  }

  // ─── 文字 ───────────────────────
  void _drawText(Canvas canvas, String text, double cx, double cy, double opacity) {
    final textOpacity = ((fadeIn - 0.3) / 0.7 * opacity).clamp(0.0, 1.0);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: textOpacity),
          fontSize: 42,
          fontWeight: FontWeight.w300,
          letterSpacing: 8,
          shadows: [
            Shadow(
              blurRadius: 10,
              color: preset.centerColors[0].withValues(alpha: textOpacity * 0.6),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + 120));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

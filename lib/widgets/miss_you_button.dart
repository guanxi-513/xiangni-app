import 'package:flutter/material.dart';

/// 「想你」按钮 — 带脉冲动画的爱心按钮
class MissYouButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool enabled;
  final Color? color;

  const MissYouButton({
    super.key,
    this.onPressed,
    this.enabled = true,
    this.color,
  });

  @override
  State<MissYouButton> createState() => _MissYouButtonState();
}

class _MissYouButtonState extends State<MissYouButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 颜色：优先使用传入的颜色，否则使用默认粉色
    final baseColor = widget.color ?? const Color(0xFFFF6B9D);
    final darkColor = HSLColor.fromColor(baseColor)
        .withLightness(
          (HSLColor.fromColor(baseColor).lightness - 0.2)
              .clamp(0.0, 1.0),
        )
        .toColor();

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        if (widget.enabled) widget.onPressed?.call();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseCtrl, _pressCtrl]),
        builder: (context, child) {
          final pulseScale = 1.0 + 0.05 * _pulseCtrl.value;
          final totalScale = pulseScale * _scale.value;
          return Transform.scale(
            scale: widget.enabled ? totalScale : 0.9,
            child: child,
          );
        },
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: widget.enabled
                  ? [baseColor, darkColor]
                  : [Colors.grey, Colors.grey.shade400],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.enabled
                    ? baseColor.withValues(alpha: 0.5)
                    : Colors.transparent,
                blurRadius: 30 + 10 * _pulseCtrl.value,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite,
                color: Colors.white,
                size: 64,
              ),
              SizedBox(height: 8),
              Text(
                '想你',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

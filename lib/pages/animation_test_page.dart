// ============================================================
// 爱心动画预览测试页面
//
// 功能：
//   - 一键预览爱心粒子动画
//   - 支持切换颜色主题、调整粒子数量和动画时长
//   - 动画播放时全屏覆盖，结束后自动消失
//
// 路由：Navigator.push(context, MaterialPageRoute(builder: (_) => AnimationTestPage()))
// ============================================================

import 'package:flutter/material.dart';
import '../animations/heart_particle_animation.dart';

/// 颜色主题预设
class _ColorPreset {
  final String name;
  final List<Color> particleColors;
  final List<Color> centerColors;
  final IconData icon;

  const _ColorPreset({
    required this.name,
    required this.particleColors,
    required this.centerColors,
    required this.icon,
  });
}

class AnimationTestPage extends StatefulWidget {
  const AnimationTestPage({super.key});

  @override
  State<AnimationTestPage> createState() => _AnimationTestPageState();
}

class _AnimationTestPageState extends State<AnimationTestPage> {
  bool _playing = false;
  int _particleCount = 60;
  double _durationSec = 4.0;
  int _presetIndex = 0;

  // ── 颜色主题 ──
  static const _presets = [
    _ColorPreset(
      name: '浪漫粉红',
      particleColors: [
        Color(0xFFFF6B9D), Color(0xFFFF4757), Color(0xFFFF4081),
        Color(0xFFFFFFFF), Color(0xFFFFB6C1),
      ],
      centerColors: [Color(0xFFFF6B9D), Color(0xFFFF1744)],
      icon: Icons.favorite,
    ),
    _ColorPreset(
      name: '梦幻紫',
      particleColors: [
        Color(0xFFE040FB), Color(0xFFD500F9), Color(0xFFAA00FF),
        Color(0xFFFFFFFF), Color(0xFFCE93D8),
      ],
      centerColors: [Color(0xFFCE93D8), Color(0xFF8E24AA)],
      icon: Icons.auto_awesome,
    ),
    _ColorPreset(
      name: '热情红',
      particleColors: [
        Color(0xFFFF1744), Color(0xFFFF5252), Color(0xFFFF8A80),
        Color(0xFFFFAB40), Color(0xFFFFFFFF),
      ],
      centerColors: [Color(0xFFFF5252), Color(0xFFD50000)],
      icon: Icons.local_fire_department,
    ),
    _ColorPreset(
      name: '星空白银',
      particleColors: [
        Color(0xFFFFFFFF), Color(0xFFE0E0E0), Color(0xFFB0BEC5),
        Color(0xFF90CAF9), Color(0xFFE1F5FE),
      ],
      centerColors: [Color(0xFFE0E0E0), Color(0xFF78909C)],
      icon: Icons.star,
    ),
  ];

  void _play() {
    setState(() => _playing = true);
  }

  void _onComplete() {
    setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final preset = _presets[_presetIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('爱心动画预览'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── 背景渐变 ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
              ),
            ),
          ),

          // ── 控制面板 ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(height: 20),

                  // 颜色主题切换
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _presets.length,
                      separatorBuilder: (_, _) => SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final p = _presets[index];
                        final selected = index == _presetIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _presetIndex = index),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? p.centerColors[0].withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? p.centerColors[0]
                                    : Colors.white24,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(p.icon,
                                    size: 16,
                                    color: selected
                                        ? p.centerColors[0]
                                        : Colors.white54),
                                SizedBox(width: 6),
                                Text(
                                  p.name,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Spacer(),

                  // ── 预览按钮 ──
                  if (!_playing) _buildPreviewButton(preset),

                  Spacer(),

                  // ── 参数调节 ──
                  if (!_playing) ...[
                    _buildSlider(
                      label: '粒子数量',
                      value: _particleCount.toDouble(),
                      min: 20,
                      max: 150,
                      divisions: 13,
                      onChanged: (v) =>
                          setState(() => _particleCount = v.round()),
                      display: '$_particleCount',
                    ),
                    SizedBox(height: 16),
                    _buildSlider(
                      label: '动画时长',
                      value: _durationSec,
                      min: 2,
                      max: 8,
                      divisions: 12,
                      onChanged: (v) =>
                          setState(() => _durationSec = v),
                      display: '${_durationSec.toStringAsFixed(1)}s',
                    ),
                    SizedBox(height: 40),
                  ],
                ],
              ),
            ),
          ),

          // ── 动画覆盖层 ──
          if (_playing)
            Positioned.fill(
              child: HeartAnimationWidget(
                key: ValueKey('anim_${DateTime.now().millisecondsSinceEpoch}'),
                duration: Duration(milliseconds: (_durationSec * 1000).round()),
                particleCount: _particleCount,
                particleColors: preset.particleColors,
                centerHeartColors: preset.centerColors,
                enableVibration: true,
                onComplete: _onComplete,
              ),
            ),
        ],
      ),
    );
  }

  /// 预览按钮
  Widget _buildPreviewButton(_ColorPreset preset) {
    return GestureDetector(
      onTap: _play,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [preset.centerColors[0], preset.centerColors[1]],
          ),
          boxShadow: [
            BoxShadow(
              color: preset.centerColors[0].withValues(alpha: 0.5),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(preset.icon, color: Colors.white, size: 56),
            SizedBox(height: 8),
            Text(
              '预览动画',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w300,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 参数滑块
  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String display,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.white70, fontSize: 14)),
            Text(display,
                style: TextStyle(
                    color: Color(0xFFFF4081),
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Color(0xFFFF4081),
            inactiveTrackColor: Colors.white12,
            thumbColor: Color(0xFFFF4081),
            overlayColor: Color(0xFFFF4081).withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

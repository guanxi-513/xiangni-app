// ============================================================
// 50 种爱心粒子动画预设库
//
// 每次收到「想你」信号 → HeartAnimationWidget 随机 pick 一个
// 预设 = 调色板 + 发射模式 + 粒子形状 + 中心心形态 + 物理参数
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';

// ── 粒子形状 ──────────────────────────────────────
enum ParticleShape {
  heart,      // 爱心（默认）
  circle,     // 圆点
  star,       // 五角星
  square,     // 方块
  diamond,    // 菱形
  petal,      // 花瓣
  ribbon,     // 丝带（扁平矩形）
  sparkle,    // 闪烁星点（带十字光晕）
}

// ── 中心大爱心动画模式 ─────────────────────────────
enum CenterHeartMode {
  breathe,       // 呼吸缩放（默认）
  heartbeat,     // 心跳节奏（咚-哒-咚-哒）
  rotate3d,      // 3D 旋转 + 翻转
  pulseRing,     // 中心不动 + 多层脉冲环扩散
  shatterBurst,  // 碎裂成粒子
  roseUnfold,    // 像玫瑰一样绽放展开
  none,          // 不显示中心大爱心（纯粒子）
}

// ── 背景风格 ──────────────────────────────────────
enum BgStyle {
  solidGradient,   // 默认深色径向渐变
  starry,          // 星空（随机星点闪烁）
  smokeCloud,      // 彩色烟雾（柔光云朵）
  sparkleField,    // 星光闪烁场
}

// ── 发射模式 ──────────────────────────────────────
// 对应 50 种不同的粒子空间分布 + 速度分布
enum EmitterPattern {
  classicBurst,      // 1 经典爆发：全方向均匀扩散
  spiralThrow,       // 2 螺旋抛射：阿基米德螺旋
  ringFlash,         // 3 环形扩散：同心圆环爆发
  heartOrbit,        // 4 心形轨道：沿心形大轮廓甩出
  loveFountain,      // 5 喷泉：底部向上喷射，抛物线回落
  fireworkBurst,     // 6 烟花二次爆炸：先升上半空，散开
  meteorShower,      // 7 流星雨：左上 45° 俯冲到右下
  lanternRise,       // 8 许愿灯：底部缓慢上升，轨迹摇曳
  crossBurst,        // 9 十字四向：上下左右 4 束
  vortexSwallow,     // 10 漩涡：先吸入，再甩出
  sineWave,          // 11 波浪正弦飞行
  starShape,         // 12 五角星形爆发
  radialBeam,        // 13 放射激光线（直线高速度）
  rippleRings,       // 14 涟漪：3 层同心环，按时间间隔扩散
  twinHearts,        // 15 双心交错旋转：左右两颗心对向飞行
  sakuraFall,        // 16 樱花飘落：从顶部自由飘落旋转
  galaxySpiral,      // 17 银河旋臂：4 条旋臂螺旋转出
  bubbleBlow,        // 18 吹泡泡：大小不一缓慢上浮，到顶破碎
  pulseHeartWave,    // 19 脉冲心波：心形轮廓冲击波
  laserLines,        // 20 激光十字：中心射出 8 道激光线
  smokePuff,         // 21 香烟烟雾：缓慢扩散体积变大淡去
  sparkBranches,     // 22 闪电树枝：随机分形分支
  stardustDrifting,  // 23 星尘漂浮：慢速随机漫步
  petalFloating,     // 24 花瓣漂浮：各种花瓣飘落
  featherDrift,      // 25 羽毛飘动：带角度飘落和摆动
  dnaHelix,          // 26 DNA 双螺旋：两条垂直旋臂旋转上升
  umbrellaOpen,      // 27 螺旋伞：中心打开成伞状
  roseNebula,        // 28 玫瑰星云：彩色圆形扩散，有层次感
  dandelionSeed,     // 29 蒲公英：小伞状结构缓慢旋转上升
  diamondShatter,    // 30 钻石碎裂：菱形碎片向四面八方飞
  hourglass,         // 31 沙漏：上下对称交叉
  blackHole,         // 32 黑洞：粒子先被吸进去然后爆炸喷发
  clockDial,         // 33 时钟表盘：12 方向发射
  ferrisWheel,       // 34 摩天轮：圆周旋转，每个粒子有半径变化
  pinwheelSpin,      // 35 风车：四叶快速旋转
  bubbleBathRise,    // 36 泡泡海洋：底部生成，随机水平漂移上升
  waterDropSplash,   // 37 水滴：中心滴，溅起一圈
  ribbonDance,       // 38 彩带飞舞：长彩带绕中心
  diamondRain,       // 39 钻石雨：顶部落下钻石
  neonGlowTrail,     // 40 霓虹轨迹：粒子带长发光拖尾
  pixelHeartGrid,    // 41 像素点阵：拼出一个心形，逐像素爆散
  confettiParty,     // 42 派对彩屑：多彩小方块旋转抛撒
  stackLoveHearts,   // 43 叠心：多个大小爱心从中心升起
  quantumPulse,      // 44 量子跃迁：粒子随机位置闪现合并
  rainbowBurst,      // 45 彩虹爆发：按颜色扇形分布
  shockwaveDisc,     // 46 冲击波：圆盘膨胀 + 多层
  fireflyGlow,       // 47 萤火虫：慢速上升闪烁出现消失
  roseBloom,         // 48 玫瑰绽放：多层同心花瓣展开
  crystalShine,      // 49 水晶闪耀：多面体粒子缓慢闪耀
  grandFinale,       // 50 终章：爆发 + 上升 + 圆环 + 星尘综合
}

// ── 预设类 ──────────────────────────────────────────

class HeartAnimationPreset {
  final String name;                   // 名称（调试用）
  final EmitterPattern emitter;
  final ParticleShape particleShape;
  final int particleCount;
  final List<Color> palette;           // 粒子调色板
  final List<Color> centerColors;      // 中心心渐变色 [顶, 底]
  final double gravity;                // 重力系数（负=上升）
  final double lifeMin, lifeMax;       // 寿命范围
  final double sizeMin, sizeMax;       // 粒子尺寸
  final double speedMin, speedMax;     // 速度范围
  final CenterHeartMode centerMode;
  final BgStyle bg;
  final String? customText;            // 自定义文字，空则用默认"想你"
  final List<int>? vibrationPattern;   // 自定义震动
  final double dragCoeff;              // 空气阻力系数（0.95~1.0）
  final Map<String, double> extra;     // 扩展参数

  const HeartAnimationPreset({
    required this.name,
    required this.emitter,
    required this.particleShape,
    required this.particleCount,
    required this.palette,
    required this.centerColors,
    this.gravity = 120,
    this.lifeMin = 1.6,
    this.lifeMax = 3.2,
    this.sizeMin = 10,
    this.sizeMax = 28,
    this.speedMin = 150,
    this.speedMax = 360,
    this.centerMode = CenterHeartMode.breathe,
    this.bg = BgStyle.solidGradient,
    this.customText,
    this.vibrationPattern,
    this.dragCoeff = 0.98,
    this.extra = const {},
  });
}

// ══════════════════════════════════════════════════
//  50 个预设实例
// ══════════════════════════════════════════════════

final List<HeartAnimationPreset> heartAnimationPresets = [
  // ── 1 经典爆发 ──
  HeartAnimationPreset(
    name: '1 经典爆发',
    emitter: EmitterPattern.classicBurst,
    particleShape: ParticleShape.heart,
    particleCount: 80,
    palette: _pinks,
    centerColors: _pinkToRed,
  ),
  // ── 2 螺旋抛射 ──
  HeartAnimationPreset(
    name: '2 螺旋抛射',
    emitter: EmitterPattern.spiralThrow,
    particleShape: ParticleShape.star,
    particleCount: 90,
    palette: _magenta,
    centerColors: _magentaDeep,
    centerMode: CenterHeartMode.rotate3d,
    extra: {'spiralArms': 3.0, 'spiralTurns': 2.5},
  ),
  // ── 3 环形扩散 ──
  HeartAnimationPreset(
    name: '3 环形闪光',
    emitter: EmitterPattern.ringFlash,
    particleShape: ParticleShape.sparkle,
    particleCount: 120,
    palette: _redHot,
    centerColors: _redDeep,
    centerMode: CenterHeartMode.pulseRing,
    speedMin: 200,
    speedMax: 500,
    gravity: 20,
    extra: {'rings': 3.0, 'ringGap': 0.35},
  ),
  // ── 4 心形轨道 ──
  HeartAnimationPreset(
    name: '4 心形轨道',
    emitter: EmitterPattern.heartOrbit,
    particleShape: ParticleShape.heart,
    particleCount: 100,
    palette: _rose,
    centerColors: _roseDeep,
    centerMode: CenterHeartMode.heartbeat,
    gravity: 0,
    speedMin: 120,
    speedMax: 250,
  ),
  // ── 5 喷泉 ──
  HeartAnimationPreset(
    name: '5 爱之喷泉',
    emitter: EmitterPattern.loveFountain,
    particleShape: ParticleShape.circle,
    particleCount: 95,
    palette: _dreamy,
    centerColors: _dreamyDeep,
    gravity: 280,
    speedMin: 280,
    speedMax: 450,
    centerMode: CenterHeartMode.roseUnfold,
  ),
  // ── 6 烟花二次爆炸 ──
  HeartAnimationPreset(
    name: '6 浪漫烟花',
    emitter: EmitterPattern.fireworkBurst,
    particleShape: ParticleShape.sparkle,
    particleCount: 140,
    palette: _rainbow,
    centerColors: _rainbowDeep,
    gravity: 200,
    bg: BgStyle.starry,
    centerMode: CenterHeartMode.shatterBurst,
    vibrationPattern: const [0, 200, 100, 200, 100, 600],
  ),
  // ── 7 流星雨 ──
  HeartAnimationPreset(
    name: '7 流星心语',
    emitter: EmitterPattern.meteorShower,
    particleShape: ParticleShape.sparkle,
    particleCount: 70,
    palette: _coolBlue,
    centerColors: _coolDeep,
    gravity: 600,
    speedMin: 500,
    speedMax: 900,
    bg: BgStyle.starry,
    centerMode: CenterHeartMode.pulseRing,
    extra: {'trail': 0.7},
  ),
  // ── 8 许愿灯 ──
  HeartAnimationPreset(
    name: '8 许愿灯',
    emitter: EmitterPattern.lanternRise,
    particleShape: ParticleShape.heart,
    particleCount: 50,
    palette: _warmOrange,
    centerColors: _warmDeep,
    gravity: -40,
    speedMin: 30,
    speedMax: 90,
    sizeMin: 20,
    sizeMax: 42,
    lifeMin: 3.5,
    lifeMax: 5,
    centerMode: CenterHeartMode.breathe,
    customText: '许个愿吧',
  ),
  // ── 9 十字四向 ──
  HeartAnimationPreset(
    name: '9 十字交汇',
    emitter: EmitterPattern.crossBurst,
    particleShape: ParticleShape.diamond,
    particleCount: 100,
    palette: _purpleMist,
    centerColors: _purpleDeep,
    centerMode: CenterHeartMode.heartbeat,
    speedMin: 200,
    speedMax: 500,
    gravity: 50,
  ),
  // ── 10 漩涡 ──
  HeartAnimationPreset(
    name: '10 漩涡吞噬',
    emitter: EmitterPattern.vortexSwallow,
    particleShape: ParticleShape.circle,
    particleCount: 120,
    palette: _galaxyPurple,
    centerColors: _galaxyPurpleDeep,
    gravity: 0,
    speedMin: 100,
    speedMax: 280,
    centerMode: CenterHeartMode.rotate3d,
    extra: {'vortexTime': 0.5},
  ),
  // ── 11 正弦波浪 ──
  HeartAnimationPreset(
    name: '11 波浪心跳',
    emitter: EmitterPattern.sineWave,
    particleShape: ParticleShape.heart,
    particleCount: 70,
    palette: _tealWave,
    centerColors: _tealDeep,
    gravity: 0,
    speedMin: 150,
    speedMax: 250,
    lifeMin: 2.5,
    lifeMax: 4,
    centerMode: CenterHeartMode.breathe,
  ),
  // ── 12 五角星爆发 ──
  HeartAnimationPreset(
    name: '12 五角星愿',
    emitter: EmitterPattern.starShape,
    particleShape: ParticleShape.star,
    particleCount: 100,
    palette: _starGold,
    centerColors: _goldDeep,
    speedMin: 180,
    speedMax: 420,
    gravity: 120,
    centerMode: CenterHeartMode.pulseRing,
  ),
  // ── 13 放射激光束 ──
  HeartAnimationPreset(
    name: '13 激光绽放',
    emitter: EmitterPattern.radialBeam,
    particleShape: ParticleShape.sparkle,
    particleCount: 160,
    palette: _neonCyan,
    centerColors: _cyanDeep,
    gravity: 0,
    speedMin: 350,
    speedMax: 700,
    lifeMin: 1.2,
    lifeMax: 2.2,
    centerMode: CenterHeartMode.heartbeat,
    bg: BgStyle.solidGradient,
    extra: {'beam': 24.0},
  ),
  // ── 14 涟漪环 ──
  HeartAnimationPreset(
    name: '14 心事涟漪',
    emitter: EmitterPattern.rippleRings,
    particleShape: ParticleShape.circle,
    particleCount: 150,
    palette: _aqua,
    centerColors: _aquaDeep,
    gravity: 0,
    speedMin: 250,
    speedMax: 450,
    centerMode: CenterHeartMode.pulseRing,
    extra: {'rings': 4.0, 'ringGap': 0.3},
  ),
  // ── 15 双心交错旋转 ──
  HeartAnimationPreset(
    name: '15 心心相印',
    emitter: EmitterPattern.twinHearts,
    particleShape: ParticleShape.heart,
    particleCount: 110,
    palette: _twinLove,
    centerColors: _pinkToRed,
    speedMin: 120,
    speedMax: 220,
    gravity: 0,
    centerMode: CenterHeartMode.roseUnfold,
    customText: '❤ 心 心 相 印 ❤',
    vibrationPattern: const [0, 200, 80, 150, 80, 150, 80, 300],
  ),
  // ── 16 樱花飘落 ──
  HeartAnimationPreset(
    name: '16 樱花物语',
    emitter: EmitterPattern.sakuraFall,
    particleShape: ParticleShape.petal,
    particleCount: 80,
    palette: _sakura,
    centerColors: _sakuraDeep,
    gravity: 80,
    speedMin: 40,
    speedMax: 120,
    sizeMin: 18,
    sizeMax: 36,
    lifeMin: 3,
    lifeMax: 5,
    centerMode: CenterHeartMode.breathe,
    customText: '樱 花 飞 舞',
    bg: BgStyle.smokeCloud,
  ),
  // ── 17 银河旋臂 ──
  HeartAnimationPreset(
    name: '17 银河之心',
    emitter: EmitterPattern.galaxySpiral,
    particleShape: ParticleShape.star,
    particleCount: 160,
    palette: _galaxy,
    centerColors: _galaxyDeep,
    gravity: 0,
    speedMin: 80,
    speedMax: 240,
    sizeMin: 6,
    sizeMax: 22,
    centerMode: CenterHeartMode.rotate3d,
    bg: BgStyle.starry,
    customText: '你是银河',
    extra: {'galaxyArms': 4.0},
  ),
  // ── 18 吹泡泡 ──
  HeartAnimationPreset(
    name: '18 泡泡时光',
    emitter: EmitterPattern.bubbleBlow,
    particleShape: ParticleShape.circle,
    particleCount: 60,
    palette: _bubbleColor,
    centerColors: _bubbleDeep,
    gravity: -60,
    speedMin: 30,
    speedMax: 120,
    sizeMin: 22,
    sizeMax: 56,
    lifeMin: 2.8,
    lifeMax: 4.5,
    centerMode: CenterHeartMode.breathe,
  ),
  // ── 19 脉冲心波 ──
  HeartAnimationPreset(
    name: '19 心动脉冲',
    emitter: EmitterPattern.pulseHeartWave,
    particleShape: ParticleShape.heart,
    particleCount: 140,
    palette: _pinks,
    centerColors: _pinkToRed,
    gravity: 0,
    centerMode: CenterHeartMode.heartbeat,
    speedMin: 150,
    speedMax: 320,
    extra: {'waves': 4.0, 'waveGap': 0.4},
  ),
  // ── 20 激光十字 ──
  HeartAnimationPreset(
    name: '20 霓虹十字',
    emitter: EmitterPattern.laserLines,
    particleShape: ParticleShape.sparkle,
    particleCount: 200,
    palette: _neonMulti,
    centerColors: _neonDeep,
    gravity: 0,
    speedMin: 500,
    speedMax: 900,
    lifeMin: 0.8,
    lifeMax: 1.6,
    centerMode: CenterHeartMode.pulseRing,
    bg: BgStyle.solidGradient,
  ),
  // ── 21 香烟烟雾 ──
  HeartAnimationPreset(
    name: '21 思绪如烟',
    emitter: EmitterPattern.smokePuff,
    particleShape: ParticleShape.circle,
    particleCount: 50,
    palette: _smoke,
    centerColors: _smokeDeep,
    gravity: -30,
    speedMin: 20,
    speedMax: 70,
    sizeMin: 40,
    sizeMax: 90,
    lifeMin: 3,
    lifeMax: 5,
    centerMode: CenterHeartMode.breathe,
    bg: BgStyle.smokeCloud,
    customText: '思 绪 如 烟',
  ),
  // ── 22 闪电分形 ──
  HeartAnimationPreset(
    name: '22 心动闪电',
    emitter: EmitterPattern.sparkBranches,
    particleShape: ParticleShape.sparkle,
    particleCount: 180,
    palette: _electric,
    centerColors: _electricDeep,
    gravity: 200,
    speedMin: 400,
    speedMax: 700,
    lifeMin: 0.6,
    lifeMax: 1.4,
    centerMode: CenterHeartMode.shatterBurst,
    vibrationPattern: const [0, 120, 50, 120, 50, 120],
  ),
  // ── 23 星尘漂浮 ──
  HeartAnimationPreset(
    name: '23 星尘漫步',
    emitter: EmitterPattern.stardustDrifting,
    particleShape: ParticleShape.sparkle,
    particleCount: 130,
    palette: _stardust,
    centerColors: _stardustDeep,
    gravity: 0,
    speedMin: 20,
    speedMax: 70,
    sizeMin: 4,
    sizeMax: 14,
    lifeMin: 2.5,
    lifeMax: 4.5,
    centerMode: CenterHeartMode.breathe,
    bg: BgStyle.starry,
  ),
  // ── 24 花瓣漂浮 ──
  HeartAnimationPreset(
    name: '24 花海飘零',
    emitter: EmitterPattern.petalFloating,
    particleShape: ParticleShape.petal,
    particleCount: 90,
    palette: _gardenColors,
    centerColors: _gardenDeep,
    gravity: 60,
    speedMin: 40,
    speedMax: 100,
    sizeMin: 18,
    sizeMax: 32,
    lifeMin: 3,
    lifeMax: 5,
    centerMode: CenterHeartMode.roseUnfold,
    customText: '花 开 有 期',
  ),
  // ── 25 羽毛飘动 ──
  HeartAnimationPreset(
    name: '25 羽毛轻舞',
    emitter: EmitterPattern.featherDrift,
    particleShape: ParticleShape.ribbon,
    particleCount: 40,
    palette: _feather,
    centerColors: _featherDeep,
    gravity: 40,
    speedMin: 20,
    speedMax: 70,
    sizeMin: 28,
    sizeMax: 52,
    lifeMin: 3.5,
    lifeMax: 5.5,
    centerMode: CenterHeartMode.breathe,
    customText: '轻 轻 想 你',
  ),
  // ── 26 DNA 双螺旋 ──
  HeartAnimationPreset(
    name: '26 心动螺旋',
    emitter: EmitterPattern.dnaHelix,
    particleShape: ParticleShape.heart,
    particleCount: 120,
    palette: _dnaColors,
    centerColors: _dnaDeep,
    gravity: -10,
    speedMin: 60,
    speedMax: 180,
    centerMode: CenterHeartMode.rotate3d,
    lifeMin: 2.5,
    lifeMax: 4,
  ),
  // ── 27 螺旋伞 ──
  HeartAnimationPreset(
    name: '27 为你撑伞',
    emitter: EmitterPattern.umbrellaOpen,
    particleShape: ParticleShape.ribbon,
    particleCount: 110,
    palette: _umbrellaColor,
    centerColors: _umbrellaDeep,
    gravity: 0,
    speedMin: 150,
    speedMax: 320,
    centerMode: CenterHeartMode.roseUnfold,
    customText: '为 你 撑 伞',
  ),
  // ── 28 玫瑰星云 ──
  HeartAnimationPreset(
    name: '28 玫瑰星云',
    emitter: EmitterPattern.roseNebula,
    particleShape: ParticleShape.circle,
    particleCount: 200,
    palette: _nebula,
    centerColors: _nebulaDeep,
    gravity: 0,
    speedMin: 40,
    speedMax: 200,
    sizeMin: 8,
    sizeMax: 32,
    centerMode: CenterHeartMode.roseUnfold,
    bg: BgStyle.starry,
    lifeMin: 2.5,
    lifeMax: 4.5,
    customText: '玫 瑰 星 云',
  ),
  // ── 29 蒲公英种子 ──
  HeartAnimationPreset(
    name: '29 随风飘散',
    emitter: EmitterPattern.dandelionSeed,
    particleShape: ParticleShape.star,
    particleCount: 70,
    palette: _dandelion,
    centerColors: _dandelionDeep,
    gravity: -20,
    speedMin: 40,
    speedMax: 120,
    sizeMin: 10,
    sizeMax: 22,
    lifeMin: 3.5,
    lifeMax: 5.5,
    centerMode: CenterHeartMode.breathe,
    customText: '随 风 想 你',
  ),
  // ── 30 钻石碎裂 ──
  HeartAnimationPreset(
    name: '30 碎裂水晶',
    emitter: EmitterPattern.diamondShatter,
    particleShape: ParticleShape.diamond,
    particleCount: 120,
    palette: _diamond,
    centerColors: _diamondDeep,
    gravity: 320,
    speedMin: 250,
    speedMax: 550,
    centerMode: CenterHeartMode.shatterBurst,
    vibrationPattern: const [0, 400, 100, 400],
  ),
  // ── 31 沙漏 ──
  HeartAnimationPreset(
    name: '31 时光沙漏',
    emitter: EmitterPattern.hourglass,
    particleShape: ParticleShape.diamond,
    particleCount: 90,
    palette: _hourglass,
    centerColors: _hourglassDeep,
    gravity: 260,
    speedMin: 120,
    speedMax: 280,
    centerMode: CenterHeartMode.heartbeat,
    customText: '时 光 里 的 你',
  ),
  // ── 32 黑洞吞噬 → 爆发 ──
  HeartAnimationPreset(
    name: '32 黑洞之恋',
    emitter: EmitterPattern.blackHole,
    particleShape: ParticleShape.star,
    particleCount: 160,
    palette: _blackhole,
    centerColors: _blackholeDeep,
    gravity: 0,
    speedMin: 80,
    speedMax: 600,
    centerMode: CenterHeartMode.shatterBurst,
    bg: BgStyle.starry,
    vibrationPattern: const [0, 200, 200, 200, 0, 600],
    extra: {'blackHolePhase': 0.35},
  ),
  // ── 33 时钟表盘 ──
  HeartAnimationPreset(
    name: '33 每时每刻',
    emitter: EmitterPattern.clockDial,
    particleShape: ParticleShape.diamond,
    particleCount: 120,
    palette: _clock,
    centerColors: _clockDeep,
    gravity: 0,
    speedMin: 250,
    speedMax: 480,
    centerMode: CenterHeartMode.heartbeat,
    customText: '每 时 每 刻',
    lifeMin: 1.8,
    lifeMax: 3,
  ),
  // ── 34 摩天轮 ──
  HeartAnimationPreset(
    name: '34 幸福摩天轮',
    emitter: EmitterPattern.ferrisWheel,
    particleShape: ParticleShape.heart,
    particleCount: 80,
    palette: _ferrisWheel,
    centerColors: _ferrisDeep,
    gravity: 0,
    speedMin: 80,
    speedMax: 180,
    sizeMin: 12,
    sizeMax: 28,
    lifeMin: 3,
    lifeMax: 4.5,
    centerMode: CenterHeartMode.rotate3d,
    customText: '幸 福 摩 天 轮',
  ),
  // ── 35 风车旋转 ──
  HeartAnimationPreset(
    name: '35 童年风车',
    emitter: EmitterPattern.pinwheelSpin,
    particleShape: ParticleShape.ribbon,
    particleCount: 120,
    palette: _pinwheel,
    centerColors: _pinwheelDeep,
    gravity: -10,
    speedMin: 200,
    speedMax: 400,
    centerMode: CenterHeartMode.rotate3d,
  ),
  // ── 36 泡泡海洋上升 ──
  HeartAnimationPreset(
    name: '36 泡泡海洋',
    emitter: EmitterPattern.bubbleBathRise,
    particleShape: ParticleShape.circle,
    particleCount: 80,
    palette: _ocean,
    centerColors: _oceanDeep,
    gravity: -50,
    speedMin: 50,
    speedMax: 140,
    sizeMin: 18,
    sizeMax: 54,
    centerMode: CenterHeartMode.breathe,
    lifeMin: 3,
    lifeMax: 5,
    customText: '气 泡 之 海',
  ),
  // ── 37 水滴溅起 ──
  HeartAnimationPreset(
    name: '37 一滴思念',
    emitter: EmitterPattern.waterDropSplash,
    particleShape: ParticleShape.circle,
    particleCount: 90,
    palette: _water,
    centerColors: _waterDeep,
    gravity: 380,
    speedMin: 150,
    speedMax: 420,
    centerMode: CenterHeartMode.shatterBurst,
    customText: '一 滴 思 念',
  ),
  // ── 38 彩带飞舞 ──
  HeartAnimationPreset(
    name: '38 彩带飞舞',
    emitter: EmitterPattern.ribbonDance,
    particleShape: ParticleShape.ribbon,
    particleCount: 70,
    palette: _ribbon,
    centerColors: _ribbonDeep,
    gravity: 180,
    speedMin: 120,
    speedMax: 260,
    sizeMin: 24,
    sizeMax: 48,
    lifeMin: 2.5,
    lifeMax: 4,
    centerMode: CenterHeartMode.breathe,
    customText: '喜 庆 之 时',
  ),
  // ── 39 钻石雨 ──
  HeartAnimationPreset(
    name: '39 钻石之雨',
    emitter: EmitterPattern.diamondRain,
    particleShape: ParticleShape.diamond,
    particleCount: 70,
    palette: _diamondRain,
    centerColors: _diamondRainDeep,
    gravity: 500,
    speedMin: 200,
    speedMax: 450,
    sizeMin: 14,
    sizeMax: 32,
    lifeMin: 2,
    lifeMax: 3.5,
    centerMode: CenterHeartMode.heartbeat,
    customText: '钻 石 之 雨',
  ),
  // ── 40 霓虹轨迹 ──
  HeartAnimationPreset(
    name: '40 霓虹轨迹',
    emitter: EmitterPattern.neonGlowTrail,
    particleShape: ParticleShape.sparkle,
    particleCount: 140,
    palette: _neonMulti,
    centerColors: _neonDeep,
    gravity: 0,
    speedMin: 250,
    speedMax: 500,
    lifeMin: 1.5,
    lifeMax: 2.8,
    centerMode: CenterHeartMode.pulseRing,
    extra: {'trail': 0.8},
  ),
  // ── 41 像素点阵爆散 ──
  HeartAnimationPreset(
    name: '41 像素心事',
    emitter: EmitterPattern.pixelHeartGrid,
    particleShape: ParticleShape.square,
    particleCount: 160,
    palette: _pixelLove,
    centerColors: _pixelDeep,
    gravity: 180,
    speedMin: 100,
    speedMax: 300,
    sizeMin: 8,
    sizeMax: 14,
    centerMode: CenterHeartMode.shatterBurst,
    customText: '像 素 心 事',
  ),
  // ── 42 派对彩屑 ──
  HeartAnimationPreset(
    name: '42 派对彩屑',
    emitter: EmitterPattern.confettiParty,
    particleShape: ParticleShape.square,
    particleCount: 180,
    palette: _confetti,
    centerColors: _confettiDeep,
    gravity: 400,
    speedMin: 180,
    speedMax: 500,
    sizeMin: 8,
    sizeMax: 22,
    lifeMin: 2.5,
    lifeMax: 4,
    centerMode: CenterHeartMode.pulseRing,
    vibrationPattern: const [0, 200, 80, 200, 80, 200],
    customText: '为 你 庆 祝',
  ),
  // ── 43 叠心升起 ──
  HeartAnimationPreset(
    name: '43 层层心动',
    emitter: EmitterPattern.stackLoveHearts,
    particleShape: ParticleShape.heart,
    particleCount: 50,
    palette: _stackHearts,
    centerColors: _stackDeep,
    gravity: -20,
    speedMin: 40,
    speedMax: 90,
    sizeMin: 18,
    sizeMax: 70,
    lifeMin: 3,
    lifeMax: 4.8,
    centerMode: CenterHeartMode.heartbeat,
  ),
  // ── 44 量子跃迁 ──
  HeartAnimationPreset(
    name: '44 量子心动',
    emitter: EmitterPattern.quantumPulse,
    particleShape: ParticleShape.sparkle,
    particleCount: 120,
    palette: _quantum,
    centerColors: _quantumDeep,
    gravity: 0,
    speedMin: 60,
    speedMax: 180,
    lifeMin: 2.2,
    lifeMax: 4,
    centerMode: CenterHeartMode.heartbeat,
    bg: BgStyle.sparkleField,
  ),
  // ── 45 彩虹爆发 ──
  HeartAnimationPreset(
    name: '45 彩虹之爱',
    emitter: EmitterPattern.rainbowBurst,
    particleShape: ParticleShape.heart,
    particleCount: 140,
    palette: _rainbow,
    centerColors: _rainbowDeep,
    speedMin: 180,
    speedMax: 420,
    gravity: 120,
    centerMode: CenterHeartMode.roseUnfold,
    customText: '彩 虹 之 爱',
  ),
  // ── 46 冲击波圆盘 ──
  HeartAnimationPreset(
    name: '46 心动冲击波',
    emitter: EmitterPattern.shockwaveDisc,
    particleShape: ParticleShape.circle,
    particleCount: 140,
    palette: _shock,
    centerColors: _shockDeep,
    gravity: 0,
    speedMin: 250,
    speedMax: 550,
    lifeMin: 1.2,
    lifeMax: 2.4,
    centerMode: CenterHeartMode.shatterBurst,
    vibrationPattern: const [0, 500],
    extra: {'discs': 5.0},
  ),
  // ── 47 萤火虫 ──
  HeartAnimationPreset(
    name: '47 夏夜晚萤',
    emitter: EmitterPattern.fireflyGlow,
    particleShape: ParticleShape.circle,
    particleCount: 60,
    palette: _firefly,
    centerColors: _fireflyDeep,
    gravity: -10,
    speedMin: 20,
    speedMax: 60,
    sizeMin: 8,
    sizeMax: 18,
    lifeMin: 3,
    lifeMax: 5,
    centerMode: CenterHeartMode.breathe,
    bg: BgStyle.starry,
    customText: '夏 夜 萤 光',
  ),
  // ── 48 玫瑰绽放 ──
  HeartAnimationPreset(
    name: '48 玫瑰绽放',
    emitter: EmitterPattern.roseBloom,
    particleShape: ParticleShape.petal,
    particleCount: 150,
    palette: _roseBloom,
    centerColors: _roseBloomDeep,
    gravity: 0,
    speedMin: 80,
    speedMax: 260,
    sizeMin: 12,
    sizeMax: 32,
    centerMode: CenterHeartMode.roseUnfold,
    customText: '为 你 绽 放',
  ),
  // ── 49 水晶闪耀 ──
  HeartAnimationPreset(
    name: '49 水晶闪耀',
    emitter: EmitterPattern.crystalShine,
    particleShape: ParticleShape.diamond,
    particleCount: 110,
    palette: _crystal,
    centerColors: _crystalDeep,
    gravity: 80,
    speedMin: 80,
    speedMax: 200,
    sizeMin: 10,
    sizeMax: 28,
    lifeMin: 2,
    lifeMax: 4,
    centerMode: CenterHeartMode.pulseRing,
    bg: BgStyle.sparkleField,
    customText: '水 晶 之 心',
  ),
  // ── 50 终章 ──
  HeartAnimationPreset(
    name: '50 盛大终章',
    emitter: EmitterPattern.grandFinale,
    particleShape: ParticleShape.sparkle,
    particleCount: 220,
    palette: _finale,
    centerColors: _finaleDeep,
    gravity: 80,
    speedMin: 80,
    speedMax: 520,
    sizeMin: 6,
    sizeMax: 32,
    centerMode: CenterHeartMode.roseUnfold,
    bg: BgStyle.starry,
    vibrationPattern: const [0, 200, 80, 200, 80, 200, 80, 300, 100, 500],
    customText: '最 想 的 人 是 你',
    lifeMin: 2,
    lifeMax: 4.5,
  ),
];

// ── 工具：随机取一个预设 ──────────────────

/// 随机 pick 一种预设，排除索引（可选）
HeartAnimationPreset pickRandomPreset({int? excludeIndex}) {
  final rnd = Random();
  int idx;
  do {
    idx = rnd.nextInt(heartAnimationPresets.length);
  } while (excludeIndex != null && idx == excludeIndex && heartAnimationPresets.length > 1);
  return heartAnimationPresets[idx];
}

/// 根据 index 取预设（0~49）
HeartAnimationPreset presetByIndex(int index) {
  return heartAnimationPresets[index % heartAnimationPresets.length];
}

// ══════════════════════════════════════════════
//  调色板定义（复用，保持一致风格）
// ══════════════════════════════════════════════

// 基础粉色系
const _pinks = [Color(0xFFFF6B9D), Color(0xFFFF4081), Color(0xFFFF1744), Color(0xFFFFB6C1), Color(0xFFFFFFFF)];
const _pinkToRed = [Color(0xFFFF80AB), Color(0xFFFF1744)];

// 玫红系
const _magenta = [Color(0xFFE91E63), Color(0xFFF06292), Color(0xFFEC407A), Color(0xFFFF4081), Color(0xFFFFFF)];
const _magentaDeep = [Color(0xFFF06292), Color(0xFFC2185B)];

// 火红色系
const _redHot = [Color(0xFFFF1744), Color(0xFFFF5252), Color(0xFFFF6E40), Color(0xFFFFAB40), Color(0xFFFFFFFF)];
const _redDeep = [Color(0xFFFF5252), Color(0xFFB71C1C)];

// 玫瑰系
const _rose = [Color(0xFFFF4081), Color(0xFFF48FB1), Color(0xFFEC407A), Color(0xFFF8BBD0), Color(0xFFFFFFFF)];
const _roseDeep = [Color(0xFFFF80AB), Color(0xFF880E4F)];

// 梦幻系
const _dreamy = [Color(0xFFCE93D8), Color(0xFFF48FB1), Color(0xFF81D4FA), Color(0xFFFFF176), Color(0xFFFFFFFF)];
const _dreamyDeep = [Color(0xFFCE93D8), Color(0xFFEC407A)];

// 彩虹
const _rainbow = [
  Color(0xFFEF5350), Color(0xFFFFA726), Color(0xFFFFEE58),
  Color(0xFF66BB6A), Color(0xFF42A5F5), Color(0xFFAB47BC), Color(0xFFFFFFFF)
];
const _rainbowDeep = [Color(0xFFFF8A80), Color(0xFF8E24AA)];

// 冷蓝
const _coolBlue = [Color(0xFF64B5F6), Color(0xFF42A5F5), Color(0xFF1E88E5), Color(0xFFE3F2FD), Color(0xFFFFFFFF)];
const _coolDeep = [Color(0xFF90CAF9), Color(0xFF0D47A1)];

// 暖橙
const _warmOrange = [Color(0xFFFFCC80), Color(0xFFFFB74D), Color(0xFFFFA726), Color(0xFFFFE0B2), Color(0xFFFFFFFF)];
const _warmDeep = [Color(0xFFFFB74D), Color(0xFFE65100)];

// 紫雾
const _purpleMist = [Color(0xFFBA68C8), Color(0xFFAB47BC), Color(0xFF7E57C2), Color(0xFFCE93D8), Color(0xFFFFFFFF)];
const _purpleDeep = [Color(0xFFCE93D8), Color(0xFF4A148C)];

// 星系紫
const _galaxyPurple = [Color(0xFF5C6BC0), Color(0xFF7E57C2), Color(0xFFAB47BC), Color(0xFFEC407A), Color(0xFF00E5FF)];
const _galaxyPurpleDeep = [Color(0xFF9575CD), Color(0xFF4527A0)];

// 青蓝波浪
const _tealWave = [Color(0xFF4DD0E1), Color(0xFF26C6DA), Color(0xFF00BCD4), Color(0xFFB2EBF2), Color(0xFFFFFFFF)];
const _tealDeep = [Color(0xFF80DEEA), Color(0xFF006064)];

// 金色星
const _starGold = [Color(0xFFFFD54F), Color(0xFFFFCA28), Color(0xFFFFB300), Color(0xFFFFF59D), Color(0xFFFFFFFF)];
const _goldDeep = [Color(0xFFFFE082), Color(0xFFF57F17)];

// 霓虹青
const _neonCyan = [Color(0xFF18FFFF), Color(0xFF00E5FF), Color(0xFF00B8D4), Color(0xFF84FFFF), Color(0xFFFFFFFF)];
const _cyanDeep = [Color(0xFF84FFFF), Color(0xFF006064)];

// 水蓝
const _aqua = [Color(0xFF4FC3F7), Color(0xFF29B6F6), Color(0xFF81D4FA), Color(0xFFB3E5FC), Color(0xFFFFFFFF)];
const _aquaDeep = [Color(0xFF81D4FA), Color(0xFF01579B)];

// 双心
const _twinLove = [Color(0xFFFF4081), Color(0xFF1E88E5), Color(0xFFEC407A), Color(0xFF42A5F5), Color(0xFFFFFFFF)];

// 樱花
const _sakura = [Color(0xFFF8BBD0), Color(0xFFF48FB1), Color(0xFFFCE4EC), Color(0xFFF06292), Color(0xFFFFFFFF)];
const _sakuraDeep = [Color(0xFFF48FB1), Color(0xFFC2185B)];

// 星系
const _galaxy = [
  Color(0xFF5E35B1), Color(0xFF3949AB), Color(0xFF1E88E5),
  Color(0xFFEC407A), Color(0xFFFFFFFF), Color(0xFF00E5FF)
];
const _galaxyDeep = [Color(0xFF7E57C2), Color(0xFF1A237E)];

// 泡泡色
const _bubbleColor = [
  Color(0x80FFFFFF), Color(0x8081D4FA), Color(0x80B39DDB),
  Color(0x80F8BBD0), Color(0x80B2EBF2), Color(0x80FFE0B2)
];
const _bubbleDeep = [Color(0xFFB3E5FC), Color(0xFF4FC3F7)];

// 霓虹多色
const _neonMulti = [
  Color(0xFFFF1744), Color(0xFFFF9100), Color(0xFFFFEA00),
  Color(0xFF00E676), Color(0xFF00B0FF), Color(0xFFD500F9),
  Color(0xFFFFFFFF)
];
const _neonDeep = [Color(0xFFFF1744), Color(0xFFD500F9)];

// 烟雾
const _smoke = [Color(0x66FFFFFF), Color(0x55FFF3E0), Color(0x55F5F5F5), Color(0x44FFCCBC), Color(0xFFFFFFFF)];
const _smokeDeep = [Color(0x90FFFFFF), Color(0x40FFFFFF)];

// 电系
const _electric = [Color(0xFFFFFF00), Color(0xFFFFFF), Color(0xFF00E5FF), Color(0xFFFFD740), Color(0xFFE040FB)];
const _electricDeep = [Color(0xFFFFFF00), Color(0xFF00B0FF)];

// 星尘
const _stardust = [Color(0xFFFFFFFF), Color(0xFFFFF59D), Color(0xFFB388FF), Color(0xFF80D8FF), Color(0xFFE1BEE7)];
const _stardustDeep = [Color(0xFFFFF9C4), Color(0xFF7C4DFF)];

// 花园
const _gardenColors = [
  Color(0xFFF06292), Color(0xFFE91E63), Color(0xFFBA68C8),
  Color(0xFFAB47BC), Color(0xFFEC407A), Color(0xFFFFFFFF)
];
const _gardenDeep = [Color(0xFFF48FB1), Color(0xFF6A1B9A)];

// 羽毛
const _feather = [Color(0xFFFFFFFF), Color(0xFFFFF9C4), Color(0xFFE1F5FE), Color(0xFFF3E5F5), Color(0xFFFFCCBC)];
const _featherDeep = [Color(0xFFFFFFFF), Color(0xFFB0BEC5)];

// DNA
const _dnaColors = [Color(0xFF29B6F6), Color(0xFFEC407A), Color(0xFF00E676), Color(0xFFFFD54F), Color(0xFFFFFFFF)];
const _dnaDeep = [Color(0xFF29B6F6), Color(0xFFEC407A)];

// 伞
const _umbrellaColor = [Color(0xFF26C6DA), Color(0xFFEC407A), Color(0xFFFFB74D), Color(0xFF66BB6A), Color(0xFFFFFFFF)];
const _umbrellaDeep = [Color(0xFF4DD0E1), Color(0xFFEC407A)];

// 星云
const _nebula = [
  Color(0xFFF06292), Color(0xFFBA68C8), Color(0xFF7986CB),
  Color(0xFF4DD0E1), Color(0xFF81C784), Color(0xFFFFFFFF)
];
const _nebulaDeep = [Color(0xFFCE93D8), Color(0xFF283593)];

// 蒲公英
const _dandelion = [Color(0xFFFFFFFF), Color(0xFFFFF9C4), Color(0xFFFFF176), Color(0xFFDCEDC8), Color(0xFFD1C4E9)];
const _dandelionDeep = [Color(0xFFFFF9C4), Color(0xFFF9A825)];

// 钻石
const _diamond = [
  Color(0xFF81D4FA), Color(0xFFB3E5FC), Color(0xFFE1F5FE),
  Color(0xFFFFFFFF), Color(0xFFB39DDB), Color(0xFFCE93D8)
];
const _diamondDeep = [Color(0xFFB3E5FC), Color(0xFF3949AB)];

// 沙漏
const _hourglass = [Color(0xFFFFD54F), Color(0xFFFFB74D), Color(0xFFFFF176), Color(0xFFFFFFFF), Color(0xFF8D6E63)];
const _hourglassDeep = [Color(0xFFFFD54F), Color(0xFFBF360C)];

// 黑洞
const _blackhole = [
  Color(0xFF1A237E), Color(0xFF000000), Color(0xFF311B92),
  Color(0xFF4A148C), Color(0xFFFF1744), Color(0xFFFFFF)
];
const _blackholeDeep = [Color(0xFF512DA8), Color(0xFF000000)];

// 时钟
const _clock = [Color(0xFF90A4AE), Color(0xFF78909C), Color(0xFFFFB300), Color(0xFFFFFFFF), Color(0xFFEF5350)];
const _clockDeep = [Color(0xFFB0BEC5), Color(0xFF263238)];

// 摩天轮
const _ferrisWheel = [
  Color(0xFFF06292), Color(0xFFFFD54F), Color(0xFF4DD0E1),
  Color(0xFFAED581), Color(0xFFBA68C8), Color(0xFFFFFFFF)
];
const _ferrisDeep = [Color(0xFFF48FB1), Color(0xFF26C6DA)];

// 风车
const _pinwheel = [Color(0xFFEF5350), Color(0xFFFFEB3B), Color(0xFF66BB6A), Color(0xFF42A5F5), Color(0xFFFFFFFF)];
const _pinwheelDeep = [Color(0xFFEF5350), Color(0xFF42A5F5)];

// 海洋
const _ocean = [Color(0x80FFFFFF), Color(0xFF81D4FA), Color(0xFF4FC3F7), Color(0xFFB2EBF2), Color(0xFFA5D6A7)];
const _oceanDeep = [Color(0xFF4FC3F7), Color(0xFF01579B)];

// 水滴
const _water = [Color(0xFF29B6F6), Color(0xFF4FC3F7), Color(0xFF81D4FA), Color(0xFFB3E5FC), Color(0xFFFFFFFF)];
const _waterDeep = [Color(0xFF4FC3F7), Color(0xFF0277BD)];

// 彩带
const _ribbon = [
  Color(0xFFEF5350), Color(0xFFAB47BC), Color(0xFF3949AB),
  Color(0xFF00ACC1), Color(0xFF7CB342), Color(0xFFFFB300)
];
const _ribbonDeep = [Color(0xFFEC407A), Color(0xFFFFCA28)];

// 钻石雨
const _diamondRain = [
  Color(0xFFFFFFFF), Color(0xFFB3E5FC), Color(0xFFCE93D8),
  Color(0xFFFFF9C4), Color(0xFFB2DFDB), Color(0xFFF8BBD0)
];
const _diamondRainDeep = [Color(0xFFE1F5FE), Color(0xFF7C4DFF)];

// 像素
const _pixelLove = [Color(0xFFFF4081), Color(0xFFFFFFFF), Color(0xFFFF1744), Color(0xFFE91E63), Color(0xFF455A64)];
const _pixelDeep = [Color(0xFFFF80AB), Color(0xFFC62828)];

// 彩屑
const _confetti = [
  Color(0xFFF44336), Color(0xFFFF9800), Color(0xFFFFEB3B),
  Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFF9C27B0), Color(0xFFFFFFFF)
];
const _confettiDeep = [Color(0xFFFF5252), Color(0xFFFFAB40)];

// 叠心
const _stackHearts = [
  Color(0xFFFFCDD2), Color(0xFFF48FB1), Color(0xFFEC407A),
  Color(0xFFC2185B), Color(0xFFFF4081), Color(0xFFFFFFFF)
];
const _stackDeep = [Color(0xFFFF80AB), Color(0xFFAD1457)];

// 量子
const _quantum = [
  Color(0xFF448AFF), Color(0xFF40C4FF), Color(0xFF40C4FF),
  Color(0xFFEA80FC), Color(0xFFFFFF)
];
const _quantumDeep = [Color(0xFF536DFE), Color(0xFFE040FB)];

// 冲击波
const _shock = [Color(0xFFFF5252), Color(0xFFFFD740), Color(0xFFFFFFFF), Color(0xFF40C4FF), Color(0xFFFF6E40)];
const _shockDeep = [Color(0xFFFF5252), Color(0xFF40C4FF)];

// 萤火虫
const _firefly = [Color(0xFFCCFF90), Color(0xFFAED581), Color(0xFFFFFF), Color(0xFFFFF176), Color(0xFFDCEDC8)];
const _fireflyDeep = [Color(0xFFAED581), Color(0xFF33691E)];

// 玫瑰绽放
const _roseBloom = [
  Color(0xFFFCE4EC), Color(0xFFF8BBD0), Color(0xFFF48FB1),
  Color(0xFFEC407A), Color(0xFFC2185B), Color(0xFFFF80AB)
];
const _roseBloomDeep = [Color(0xFFF48FB1), Color(0xFF880E4F)];

// 水晶
const _crystal = [
  Color(0xFFFFFFFF), Color(0xFFE1BEE7), Color(0xFFD1C4E9),
  Color(0xFFC5CAE9), Color(0xFFB3E5FC), Color(0xFFFFFDE7)
];
const _crystalDeep = [Color(0xFFB39DDB), Color(0xFF4527A0)];

// 终章
const _finale = [
  Color(0xFFFF1744), Color(0xFFFFD740), Color(0xFF00E676),
  Color(0xFF00B0FF), Color(0xFFD500F9), Color(0xFFFFFFFF),
  Color(0xFFF06292), Color(0xFFFF9100), Color(0xFF64FFDA)
];
const _finaleDeep = [Color(0xFFFF4081), Color(0xFF651FFF)];

// bubbleBlow 没用到的可以无视，particleShape 无枚举需要 bubble 的检查
// ignore: unused_element
ParticleShape get _bubbleShape => ParticleShape.circle;

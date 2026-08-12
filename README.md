# ❤️ 想你 App (miss_you_lover)

一个跨网络的情侣互动 App：一键发送「想你」全屏爱心粒子动画 + 文字聊天，手机不在 App 前台时也会通过高优先级本地通知提醒，并附带与微信同款的系统通知铃声。

## ✨ 功能分析

### 1. 爱心「想你」信号
- **50 种粒子动画预设**（每次收到随机 1 种，不重样）
  - 发射模式：经典爆发 / 螺旋臂 / 银河系漩涡 / 流星雨 / 喷泉 / 泡泡浴 / 烟花 / 像素点阵 / 漩涡吞噬 / 爱心环 / 双心 / 粒子归心…共 50 种
  - 粒子形状：心形 / 樱花 / 星星 / 雪花 / 水滴 / 圆点 / 钻石 / 花簇…
  - 20+ 种调色板：粉红、马卡龙、银河、烟雾、电系、霓虹、极光、樱花…
- 前台收到 → 直接全屏悬浮窗爱心动画（需悬浮窗权限）
- 后台 / App 被杀 → 弹出高优先级系统通知（横幅+铃声+震动），点击通知自动唤醒 App 并再次播放全屏爱心
- 离线缓存：对方不在线时，服务端会缓存「想你」指令，对方上线后自动下发

### 2. 文字聊天
- 基于 WebSocket 的实时文字消息收发
- **消息同步/时间同步**：使用服务端 timestamp + 客户端升序排序 + 去重，解决乱序/重复问题
- **持久化**：聊天记录保存到 SharedPreferences，App 重启不丢
- 服务端离线消息队列：对方不在线时缓存 200 条，上线自动 FIFO 下发
- 前台直接在聊天面板显示，后台弹高优先级通知（横幅显示消息内容 + 响铃）

### 3. 配对机制
- 每台设备生成 6 位配对码
- 输入对方配对码进行绑定，服务端持久化绑定关系
- 网络重连后自动恢复绑定，无需重新配对

### 4. 跨网络通信（内网穿透）
- 自建 Node.js WebSocket 服务器，监听 TCP
- 通过 **cpolar / SakuraFrp TCP 隧道** 做内网穿透，双方在不同 WiFi / 4G / 5G 都能互联
  - ❌ HTTP 隧道不支持 WebSocket，请务必使用 TCP 隧道

### 5. 通知系统
- Android 高优先级通知渠道（Importance HIGH / Priority HIGH）
- **系统默认通知铃声**（= 微信默认音效，使用 `DEFAULT_NOTIFICATION_URI`）
- 横幅（Heads-up）+ 震动 + LED 呼吸灯
- 点击通知自动唤起 App 并触发对应动画/消息

---

## 📦 项目结构

```
shouujiapp/
├── lib/                          # Flutter App
│   ├── animations/
│   │   ├── heart_animation_presets.dart   # 50 套动画预设配置
│   │   ├── heart_particle_animation.dart  # 动画 Widget（+ 随机预设/覆盖参数）
│   │   ├── heart_particle_emitter.dart    # 50 种粒子发射算法
│   │   └── heart_particle_painter.dart    # Canvas 粒子渲染
│   ├── pages/
│   │   ├── splash_page.dart      # 启动页（检查连接/恢复状态）
│   │   ├── pairing_page.dart     # 配对码绑定页
│   │   ├── home_page.dart        # 主页面（想你按钮 + 聊天 + 设置）
│   │   ├── overlay_page.dart     # 全屏悬浮窗爱心动画
│   │   └── animation_test_page.dart
│   ├── services/
│   │   ├── websocket_service.dart      # WebSocket 核心 + 聊天持久化 + 离线合并
│   │   ├── notification_service.dart   # 本地通知（系统默认铃声）
│   │   ├── overlay_service.dart        # 悬浮窗管理
│   │   ├── app_lifecycle_manager.dart  # 前后台状态监听
│   │   ├── app_settings.dart           # 用户设置（服务器地址持久化）
│   │   ├── storage_service.dart        # SharedPreferences 封装
│   │   ├── permission_service.dart     # 权限申请（悬浮窗/通知）
│   │   └── foreground_service_util.dart
│   ├── widgets/
│   └── utils/constants.dart            # 默认服务器地址等常量
└── server/                       # Node.js WebSocket 服务器
    ├── index.js                         # 服务端核心：路由 + 持久绑定 + 离线消息队列
    └── package.json
```

---

## 🚀 如何使用

### 第一步：启动服务器
在自己的电脑/云服务器上：
```bash
cd server
npm install     # 第一次才需要
node index.js
```
服务默认监听 `0.0.0.0:8080`。

### 第二步：内网穿透（让不同网络的手机能连到你的服务器）
**推荐 cpolar**（原生支持 WebSocket，不会像 SakuraFrp 某些通道拦截 WS 升级请求）：
```bash
# 创建 TCP 隧道映射本地 8080 端口
cpolar tcp 8080
```
启动后你会得到类似 `tcp://10.tcp.cpolar.top:12017` 的公网地址，**注意：App 里填的时候去掉 tcp:// 前缀，改为 ws://**：
```
ws://10.tcp.cpolar.top:12017
```
> 💡 也可以用任意支持纯 TCP 转发的工具：ngrok、SakuraFrp（选择 TCP 类型，不是 HTTP）等。

### 第三步：编译安装 App 到两台手机
```bash
flutter build apk --debug
# 把 build/app/outputs/flutter-apk/app-debug.apk 分别安装到对方手机
```

### 第四步：配置服务器地址
- App 首页 → 右上角设置齿轮 → 把服务器地址改为上一步的公网地址（如 `ws://10.tcp.cpolar.top:12017`）
- 如果直接改代码里的默认值，修改 `lib/utils/constants.dart` 中的 `defaultWsUrl`。

### 第五步：配对 + 玩耍
1. 两台手机打开 App → 各自看到自己的 6 位配对码
2. A 在「输入对方配对码」里填 B 的码 → 点击配对
3. 配对成功后回到主界面
4. **想你按钮**：点一下 → 对方手机全屏爱心动画（随机 1/50 种！）+ 通知响铃
5. **聊天输入框**：发送文字消息 → 对方前台聊天区显示，后台通知横幅显示

---

## 🧪 快速自测清单

1. [ ] 两台手机都在 App 设置里填了同一个公网服务器地址并保存
2. [ ] 电脑 `node server/index.js` 正在运行（窗口别关）
3. [ ] cpolar / 樱花的 TCP 隧道在运行（窗口别关）
4. [ ] 两台手机都已拿到配对码并互相完成绑定
5. [ ] 悬浮窗权限和通知权限都已授予（App 内有引导弹窗）
6. [ ] 点击「想你」，对方手机弹出爱心/通知
7. [ ] 发送文字消息，双方聊天区按时间顺序显示，无重复/乱序
8. [ ] 其中一台完全杀掉 App，再点「想你」/发消息 → 对方推送通知，被杀掉的 App 点通知后能自动弹出爱心/显示文字

---

## 🐞 已知问题（待修复）

| # | 问题 | 说明 |
|---|------|------|
| 1 | **震动无法关闭** | `HeartAnimationWidget` 和通知都默认开启震动，设置页暂时没有关闭震动的开关 |
| 2 | **打开键盘偶尔卡顿** | 聊天输入框聚焦弹出软键盘时，部分机型会掉帧（可能是 Flutter Scaffold resize 下叠加动画层导致） |
| 3 | **打开键盘会自动震动** | 弹键盘时意外触发了 vibration 服务（建议检查 HomePage 里 `vibrate` 调用是否被误触发，或 FlutterOverlay 关联的焦点事件） |
| 4 | **部分粒子动画很卡** | 50 套预设里部分高粒子数（120+）或复杂发射模式（像素点阵、漩涡）在低端机上帧率低于 30fps；建议做 `device_info_plus` 分级或在设置里加「性能模式 / 省电模式」粒子数倍数 |
| 5 | **三台/多台手机可以同时绑定同一个配对码** | 服务端 `pair` 逻辑未做 `partnerId` 唯一性校验，也未限制「A 只能和 B 绑定」双向互斥；出现 C/D 也能绑到 B 的情况；应在服务端 pair 时检查「双方的现有 partnerId 是否为空」并加互斥校验 |
| 6 | **消息有时不同步** | 虽然已经加入 timestamp 排序 + 去重 + 持久化 + 离线队列，但在以下情况仍可能出现：<br>① 客户端时钟相差很大（应完全依赖服务端 timestamp，UI 展示时统一换算成本地时区）<br>② 重连后没有请求服务端拉取「我离线期间的历史消息」，只依赖上线 flush（对方先上线给我缓存才 OK，我自己主动发的历史记录只能从本地读）<br>③ 发送方 `sendChatMessage` 没走 `_appendMessage`，发送方本地看不到「我发的消息写入 recentMessages 再持久化」，会导致对方回复时双方列表不一致 |

> 建议修复优先级：**5（配对互斥）> 6（消息同步）> 4（粒子卡顿分级）> 1（震动开关）> 2/3（键盘相关）**

---

## ⚠️ 安全提示（切勿提交）

以下文件**仅保存在本地**，已通过 `.gitignore` 忽略：
- `android/key.properties`
- `android/app/release-keystore.jks` / `*.keystore`
- `android/local.properties`（本机 SDK 路径）
- `server/.env` / `server/node_modules/`
- `build/`、`.dart_tool/`、`.gradle/` 构建缓存

## 🛠 开发环境
- Flutter 3.x+
- Gradle 8.14.2 + AGP 8.9.1
- Node.js 18+
- 推荐内网穿透：cpolar（TCP 模式）

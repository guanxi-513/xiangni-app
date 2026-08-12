// ============================================================
// miss-you-lover WebSocket 转发服务
//
// 与 Flutter 客户端 (websocket_service.dart) 对齐的协议：
//
//  Client → Server:
//    {type: "ping"}                               心跳
//    {type: "register", code: "123456"}           绑定本机配对码
//    {type: "pair",     code: "654321"}           绑定对方配对码
//    {type: "miss_you", senderId, targetCode, color}  按对方配对码路由
//    {type: "unbind"}                             解除绑定
//
//  Server → Client:
//    {type: "pong"}                               心跳应答
//    {type: "connected", deviceId}                注册成功，下发 deviceId
//    {type: "paired",    partnerId, partnerCode}  配对成功
//    {type: "pair_error", message}                配对失败
//    {type: "miss_you",  senderId, color}         转发的想你指令
//    {type: "partner_disconnected"}                配对方下线
//    {type: "error",     message}                通用错误
//
// ── 强绑定机制 ──
//  1. 配对成功后，服务端在 bindings 中记录 pairCodeA ↔ pairCodeB
//  2. 设备重连后只需 register 自身配对码，服务端自动恢复绑定
//  3. miss_you 按对方配对码路由，不再依赖易变的 deviceId
// ============================================================

const { WebSocketServer } = require('ws');
const crypto = require('crypto');

const PORT = process.env.PORT || 8080;
const HOST = process.env.HOST || '0.0.0.0'; // 明确绑定 IPv4，确保 SakuraFrp 转发可达

const wss = new WebSocketServer({ host: HOST, port: PORT });

/**
 * 在线客户端表
 *   key   = deviceId（服务端分配的 UUID）
 *   value = { ws, pairCode, partnerId }
 *
 * 配对码索引表：
 *   codeIndex: Map<pairCode, deviceId> —— 方便用配对码反查
 *
 * 持久绑定表（强绑定）：
 *   bindings: Map<pairCode, partnerPairCode> —— 即使离线也保留
 *   设备重连 register 后，服务端自动检查并恢复配对
 */
const clients = new Map();
const codeIndex = new Map();
const bindings = new Map(); // pairCode → partnerPairCode（持久化）

/**
 * 离线消息队列
 *   key   = 接收方 pairCode
 *   value = Array<{ type, payload, queuedAt }>   （顺序保存，上线后 FIFO 下发）
 *
 * - miss_you 也缓存：确保对方不在线时再打开 App 仍能看到爱心。
 * - 限制单个 code 最多 200 条离线消息，防止内存无限增长。
 * - 每个队列按 timestamp 排序（客户端也会再排一次，双保险）。
 */
const offlineQueue = new Map();

/** 生成短 deviceId */
function genDeviceId() {
  return crypto.randomBytes(6).toString('hex');
}

console.log('');
console.log('  ❤  miss-you-lover WebSocket 服务');
console.log(`     监听端口: ${PORT}`);
console.log(`     等待连接...`);
console.log('');

wss.on('connection', (ws, req) => {
  const clientIp = req.socket.remoteAddress;
  console.log(`[+] 新连接来自 ${clientIp}`);

  // 每个新连接先分配一个 deviceId，不等客户端 register
  const deviceId = genDeviceId();
  clients.set(deviceId, { ws, pairCode: null, partnerId: null });

  // 立即告诉客户端「你已连接，这是你的 deviceId」
  send(ws, { type: 'connected', deviceId });
  console.log(`[connected] 分配 deviceId=${deviceId}`);

  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch (e) {
      console.error('[!] JSON解析失败:', e.message);
      return;
    }

    const fromId = findClientIdByWs(ws);
    const prefix = fromId ? `[${fromId}]` : `[?]`;
    console.log(`${prefix} → type=${msg.type} ${JSON.stringify(msg).slice(0, 120)}`);

    switch (msg.type) {

      // ── 心跳 ──
      case 'ping': {
        send(ws, { type: 'pong' });
        break;
      }

      // ── 绑定本机配对码 ──
      case 'register': {
        if (!fromId) {
          send(ws, { type: 'error', message: '未找到会话，请重连' });
          return;
        }
        const code = msg.code;
        if (!code || typeof code !== 'string') {
          send(ws, { type: 'error', message: '缺少 code 字段' });
          return;
        }

        // 如果该 code 已被其他设备占用，通知旧设备解绑
        if (codeIndex.has(code)) {
          const oldId = codeIndex.get(code);
          if (oldId !== fromId) {
            const oldClient = clients.get(oldId);
            if (oldClient) {
              oldClient.pairCode = null;
              if (oldClient.ws.readyState === ws.OPEN) {
                send(oldClient.ws, { type: 'partner_disconnected' });
              }
            }
          }
        }

        const me = clients.get(fromId);
        me.pairCode = code;
        codeIndex.set(code, fromId);

        console.log(`${prefix} register code=${code}`);

        // ── 强绑定自动恢复 ──
        // 检查是否有此配对码的持久绑定记录
        const boundPartnerCode = bindings.get(code);
        if (boundPartnerCode) {
          const partnerId = codeIndex.get(boundPartnerCode);
          if (partnerId && partnerId !== fromId) {
            // 对方也在线 → 自动恢复配对
            const partner = clients.get(partnerId);
            me.partnerId = partnerId;
            partner.partnerId = fromId;

            send(ws, { type: 'paired', partnerId, partnerCode: boundPartnerCode });
            send(partner.ws, { type: 'paired', partnerId: fromId, partnerCode: code });

            console.log(`${prefix} 自动恢复配对: ${code} <--> ${boundPartnerCode}`);
          } else {
            // 对方不在线，但绑定关系已记录，等对方上线时自动恢复
            console.log(`${prefix} 绑定记录存在，等待对方 ${boundPartnerCode} 上线`);
          }
        }

        // ── 离线消息下发 ──
        // 设备 register = 上线：把离线队列里存的所有消息按时间顺序下发
        // 稍微延迟一点点（100ms）让客户端 paired 恢复等逻辑先处理
        setTimeout(() => flushOffline(code, ws), 100);
        break;
      }

      // ── 绑定对方配对码（发起配对）──
      case 'pair': {
        if (!fromId) {
          send(ws, { type: 'error', message: '未找到会话，请重连' });
          return;
        }
        const code = msg.code;
        if (!code) {
          send(ws, { type: 'error', message: '缺少对方 code' });
          return;
        }

        const targetId = codeIndex.get(code);
        const me = clients.get(fromId);

        if (!targetId) {
          send(ws, { type: 'pair_error', message: '对方不在线，请让对方先生成配对码并打开 App' });
          console.log(`${prefix} pair 失败: code=${code} 不在线`);
          return;
        }
        if (targetId === fromId) {
          send(ws, { type: 'pair_error', message: '不能与自己配对' });
          return;
        }

        // 双向绑定
        const target = clients.get(targetId);
        me.partnerId = targetId;
        target.partnerId = fromId;

        // ── 持久化绑定关系（强绑定核心）──
        // 即使双方都断线重连，只要重新 register 各自配对码，就能自动恢复
        const myCode = me.pairCode;
        const partnerCode = target.pairCode;
        if (myCode && partnerCode) {
          bindings.set(myCode, partnerCode);
          bindings.set(partnerCode, myCode);
          console.log(`[bind] 持久绑定已保存: ${myCode} <--> ${partnerCode}`);
        }

        // 通知双方配对结果
        send(ws, { type: 'paired', partnerId: targetId, partnerCode });
        send(target.ws, { type: 'paired', partnerId: fromId, partnerCode: myCode });

        console.log(`${prefix} pair 成功: ${fromId} <--> ${targetId} (code=${code})`);
        break;
      }

      // ── 解除绑定 ──
      case 'unbind': {
        if (!fromId) return;
        const me = clients.get(fromId);
        if (!me) return;

        const myCode = me.pairCode;
        const partnerCode = myCode ? bindings.get(myCode) : null;

        // 清除持久绑定记录
        if (myCode) bindings.delete(myCode);
        if (partnerCode) bindings.delete(partnerCode);

        // 通知对方
        if (me.partnerId) {
          const partner = clients.get(me.partnerId);
          if (partner) {
            partner.partnerId = null;
            if (partner.ws.readyState === ws.OPEN) {
              send(partner.ws, { type: 'partner_disconnected' });
            }
          }
        }
        me.partnerId = null;

        console.log(`${prefix} unbind: ${myCode} <--> ${partnerCode} 已解除`);
        send(ws, { type: 'unbound' });
        break;
      }

      // ── 转发想你指令（按对方配对码路由 + 离线缓存）──
      case 'miss_you': {
        const senderId = fromId || msg.senderId;
        const color = msg.color || '#ff69b4';
        const { targetId, targetCode } = resolveTarget(fromId, msg, prefix, 'miss_you');
        const payload = { senderId, color };

        const target = targetId ? clients.get(targetId) : null;
        if (target && target.ws.readyState === ws.OPEN) {
          // 在线 → 即时转发
          send(target.ws, { type: 'miss_you', ...payload });
          console.log(`${prefix} miss_you → ${targetId} (code=${targetCode}) live`);
        } else if (targetCode) {
          // 不在线但有 targetCode → 入离线队列
          queueOffline(targetCode, 'miss_you', payload);
          // 发送方不弹 error（离线缓存是正常的）
        } else {
          send(ws, { type: 'error', message: '找不到接收方，请确认已配对' });
        }
        break;
      }

      // ── 转发文字消息（按对方配对码路由 + 离线缓存）──
      case 'text_message': {
        const senderId = fromId || msg.senderId;
        const content = (typeof msg.content === 'string') ? msg.content.trim() : '';
        const timestamp = msg.timestamp || Date.now();

        if (!content) {
          send(ws, { type: 'error', message: '消息内容不能为空' });
          return;
        }
        // 防止超长消息（超过 1000 字符截断）
        const safeContent = content.length > 1000 ? content.slice(0, 1000) + '…' : content;

        const { targetId, targetCode } = resolveTarget(fromId, msg, prefix, 'text_message');
        const payload = { senderId, content: safeContent, timestamp };

        const target = targetId ? clients.get(targetId) : null;
        if (target && target.ws.readyState === ws.OPEN) {
          // 在线 → 即时转发
          send(target.ws, { type: 'text_message', ...payload });
          console.log(`${prefix} text_message → ${targetId} (code=${targetCode}) live: "${safeContent.slice(0, 40)}${safeContent.length > 40 ? '…' : ''}"`);
        } else if (targetCode) {
          // 不在线但有 targetCode → 入离线队列
          queueOffline(targetCode, 'text_message', payload);
        } else {
          send(ws, { type: 'error', message: '找不到接收方，请确认已配对' });
          // 回 ack 失败（可选），这里不回避免 UI 混乱
          return;
        }

        // 无论在线/离线，都回 ack 给发送方（离线也算发送成功，会在对方上线时送达）
        send(ws, { type: 'text_message_ack', timestamp });
        break;
      }

      default:
        console.log(`${prefix} ??? 未知消息类型: ${msg.type}`);
        send(ws, { type: 'error', message: `未知消息类型: ${msg.type}` });
    }
  });

  // ── 断线清理 ──
  ws.on('close', () => {
    const id = findClientIdByWs(ws);
    if (!id) return;

    const client = clients.get(id);
    if (!client) return;

    // 1) 通知配对方
    if (client.partnerId) {
      const partner = clients.get(client.partnerId);
      if (partner) {
        partner.partnerId = null;
        if (partner.ws.readyState === ws.OPEN) {
          send(partner.ws, { type: 'partner_disconnected' });
        }
      }
    }

    // 2) 清理配对码索引（注意：不清除 bindings 持久绑定！）
    if (client.pairCode) {
      codeIndex.delete(client.pairCode);
    }

    // 3) 清理连接
    clients.delete(id);
    console.log(`[-] ${id} 已断开 (在线: ${clients.size}, 绑定: ${bindings.size})`);
  });

  ws.on('error', (err) => {
    console.error(`[!] 连接错误: ${err.message}`);
  });
});

// ── 工具函数 ──

/** 发送 JSON 消息 */
function send(ws, obj) {
  if (ws.readyState === ws.OPEN) {
    ws.send(JSON.stringify(obj));
  }
}

/** 通过 ws 反查 deviceId */
function findClientIdByWs(ws) {
  for (const [id, c] of clients) {
    if (c.ws === ws) return id;
  }
  return null;
}

/**
 * 解析消息的目标 deviceId / targetCode
 * 路由优先级：targetCode > targetId > bindings 持久绑定表
 * 返回 { targetId, targetCode }，targetId 为 null 表示找不到（可能是离线，仍可能返回 targetCode 用于离线队列）
 */
function resolveTarget(fromId, msg, prefix, typeName) {
  let targetId = null;
  let targetCode = msg.targetCode;

  if (targetCode) {
    targetId = codeIndex.get(targetCode);
  } else if (msg.targetId) {
    targetId = msg.targetId;
    if (!clients.get(targetId)) {
      // targetId 无效，回退到绑定关系
      const me = fromId ? clients.get(fromId) : null;
      const myCode = me?.pairCode;
      if (myCode) {
        const partnerCode = bindings.get(myCode);
        if (partnerCode) {
          targetId = codeIndex.get(partnerCode);
          targetCode = partnerCode;
          console.log(`${prefix} ${typeName}: targetId 无效，回退到绑定码 ${partnerCode}`);
        }
      }
    }
  } else {
    // 啥都没给，按持久绑定找
    const me = fromId ? clients.get(fromId) : null;
    const myCode = me?.pairCode;
    if (myCode) {
      const partnerCode = bindings.get(myCode);
      if (partnerCode) {
        targetId = codeIndex.get(partnerCode);
        targetCode = partnerCode;
      }
    }
  }
  return { targetId, targetCode };
}

// ── 离线消息队列工具 ──

/**
 * 入队一条离线消息（targetCode 是接收方的 pairCode）
 * 满 200 条时丢弃最旧的。
 */
function queueOffline(targetCode, type, payload) {
  if (!targetCode) return;
  if (!offlineQueue.has(targetCode)) {
    offlineQueue.set(targetCode, []);
  }
  const q = offlineQueue.get(targetCode);
  q.push({ type, payload, queuedAt: Date.now() });
  // 上限保护（200 条）
  while (q.length > 200) q.shift();
  console.log(`[offline] queue for ${targetCode}: ${type} (total=${q.length})`);
}

/**
 * 把 targetCode 对应队列里所有消息批量下发给在线的 ws，
 * 下发完毕清空队列。
 */
function flushOffline(targetCode, ws) {
  if (!targetCode || !ws) return;
  const q = offlineQueue.get(targetCode);
  if (!q || q.length === 0) return;
  console.log(`[offline] flush ${q.length} msgs for ${targetCode}`);
  // 按 queuedAt 升序（FIFO），再按 payload.timestamp 排序（双保险保证时序）
  q.sort((a, b) => {
    const ta = a.payload?.timestamp || a.queuedAt;
    const tb = b.payload?.timestamp || b.queuedAt;
    return ta - tb;
  });
  // 逐条发送
  for (const item of q) {
    try {
      send(ws, { type: item.type, ...item.payload });
    } catch (e) {
      console.error(`[offline] flush send error: ${e.message}`);
    }
  }
  // 清空
  offlineQueue.delete(targetCode);
}

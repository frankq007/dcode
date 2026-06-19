# DCode 补充设计文档

> 本文档补齐 `dcode.md` 主设计文档中未明确、不完整或存在歧义的协议契约、安全机制、功能行为与运维规范。所有章节编号对应主文档的"补充设计决策"分层结构，优先级标注为 **P0（阻塞集成）/ P1（影响正确性）/ P2（健壮性）/ P3（质量）**。

---

## 目录

- [1. Opencode 通信协议契约](#1-opencode-通信协议契约-p0)
- [2. 安全协议补充](#2-安全协议补充)
- [3. 消息协议补充](#3-消息协议补充)
- [4. 连接管理补充](#4-连接管理补充)
- [5. 功能行为补充](#5-功能行为补充)
- [6. 错误处理与日志规范](#6-错误处理与日志规范-p2)
- [7. 版本兼容性](#7-版本兼容性-p1)
- [8. 部署与运维](#8-部署与运维)
- [9. 测试策略](#9-测试策略)
- [10. 术语校正](#10-术语校正-p2)
- [11. 流式消息协议](#11-流式消息协议p0)
- [12. 并发与资源管理](#12-并发与资源管理)
- [13. Relay 配对协议补充](#13-relay-配对协议补充p1)
- [14. 心跳与连接存活检测](#14-心跳与连接存活检测p2)
- [15. 交互时序与会话引导](#15-交互时序与会话引导)
- [附录 A：消息类型完整对照表](#附录-a消息类型完整对照表)
- [附录 B：错误码枚举](#附录-b错误码枚举)
- [附录 C：配置项与环境变量对照表](#附录-c配置项与环境变量对照表)
- [附录 D：Opencode API 契约](#附录-dopencode-api-契约)

---

## 1. Opencode 通信协议契约（P0）

主文档仅声明"Gateway 通过 HTTP/SSE 与 opencode 通信"，未给出端点、schema 与事件格式，导致实现中用**本地随机 UUID** 冒充 opencode session ID。本节给出完整契约。

### 1.1 Session ID 归属（P0）

- **Session ID 唯一由 opencode 创建并返回**。Gateway 的本地 `SessionManager` 维护映射 `{ opencodeId, name, createdAt, lastActiveSeq }`。
- **不再引入 localId**：协议中所有引用均使用 opencodeId，无需本地独立 ID（原先设想的 localId 在协议中从不被使用，予以移除以避免混淆）。
- 新建会话流程：
  1. App 发送 `session_create` → Gateway 调用 `opencode.createSession()`
  2. opencode 返回真实 `sessionId`
  3. `SessionManager.create(name, opencodeId)` 落库本地映射
  4. Gateway 对该 `opencodeId` 建立 SSE 订阅
- 所有 SSE 订阅、消息发送、token 查询、权限回复**必须使用 opencodeId**。
- `lastActiveSeq`：记录该 session 最后投递给 App 的 seq，用于重连续点（见 4.1）。

### 1.2 会话历史拉取（P0）

主文档未定义历史消息获取方式，导致 App 切换 session 时新旧消息混杂。补充如下：

- **历史来源**：opencode 侧持久化。Gateway 提供历史拉取代理。
- **App 切换/进入 session 时**：
  1. 发送 `session_switch` → Gateway 调用 `GET /sessions/:id/messages?limit=N&cursor=`
  2. Gateway 将历史消息**按时间正序**以 `history` 消息类型批量回传
  3. App 收到后**清空当前消息列表**再加载历史，避免混杂
- 历史分页：通过游标 `cursor`（上一批最后一条消息 id）加载更早记录。

### 1.3 SSE 事件格式（P0）

主文档未规定 SSE 事件 schema。补充事件标准结构：

```jsonc
// opencode SSE 单个事件（data: 行内容）
{
  "type": "thinking" | "tool_call" | "permission_request" | "reply" | "token_usage" | "error" | "review_url",
  "data": { /* 见附录 D 各类型 payload */ }
}
```

- 未知 `type` **不得静默降级为 reply**（当前实现 `mapSSEEventType` 默认返回 `'reply'`，会误显思考过程为 AI 回复）。未知类型应转发为 `error` 类型并标注 `unknown_event`。

---

## 2. 安全协议补充

### 2.1 增强三步握手（P1）

当前第三步无任何验证，无法确认双方持有相同密钥。补充为**带密钥确认的握手**：

```
[Step 1] App → Gateway : handshake_init
          { publicKey: AppPubKey, nonce: AppNonce, token, version }

[Step 2] Gateway → App : handshake_ack
          { publicKey: GwPubKey, nonce: GwNonce, version, verify }

  --- 双方各自派生 sessionKey（见 2.2）---
  Gateway 立即用 sessionKey 加密 magic，随 ACK 一起返回 verify。

[Step 3] App → Gateway : handshake_complete
          { verify }

  App 校验 Gateway 的 verify → 再生成自己的 verify 发回。
  Gateway 校验 App 的 verify → 握手成功。
```

**verify 字段计算规则**（双向一致，仅发起方 nonce 顺序在前）：

| 方向 | 明文 | IV |
|------|------|----|
| Gateway→App（ACK 内） | `"DCODE-HANDSHAKE-OK" ‖ bytes(GwNonce) ‖ bytes(AppNonce)` | 全零 12 字节（固定，仅握手确认用） |
| App→Gateway（complete） | `"DCODE-HANDSHAKE-OK" ‖ bytes(AppNonce) ‖ bytes(GwNonce)` | 全零 12 字节 |

- `verify` = `{ iv: "AAAAAAAAAAAAAAAA"（base64 全零）, ciphertext: base64(明文加密+authTag) }`，复用现有 `EncryptedMessage` 结构。
- **双向确认**：App 验 Gateway 的 verify 确认 Gateway 持有正确密钥；Gateway 验 App 的 verify 确认 App 持有正确密钥。任一方向失败发 `error`（code=`HANDSHAKE_FAILED`）后关闭连接。
- 明文中 nonce **必须用原始字节**（base64 解码后的 16 字节），不得用 base64 字符串拼接。

### 2.2 会话密钥派生算法（P1）

主文档未规定 KDF。当前实现用裸 SHA-256，不符合标准。规定使用 **HKDF-SHA256**：

```
prk = HKDF-Extract(salt=nil, IKM=ECDH-SharedSecret)          // SharedSecret 为 X25519 原始 32 字节
info = UTF8("dcode-session-key") ‖ bytes(AppNonce) ‖ bytes(GwNonce)   // 16+16 字节拼接
sessionKey(32字节) = HKDF-Expand(prk, info=info, L=32)
```

- `info` 拼接为**字节级拼接**：UTF-8 编码的固定字符串后接 AppNonce、GwNonce 各自 base64 解码后的 16 字节，**顺序固定为 AppNonce 在前**。
- `salt` 取 nil（HKDF-Extract 中 salt 为空字符串），IKM 为 ECDH 共享密钥原始字节，不经过任何 hash 预处理。

### 2.3 Token 校验时机（P0）

主文档要求 TC-C05"错误 Token 握手失败"，但未定义校验点。规定：

- **校验时机**：Step 1（`handshake_init`）阶段，Gateway 收到消息后**立即校验 token**，在派生密钥前完成。
- **校验方式**：`token === this.token`（gateway 启动生成的内存 token）。
- **失败处理**：发送 `error`（code=`INVALID_TOKEN`）后**立即关闭 WebSocket**，不进入后续握手。
- **直连模式同样适用**（当前 `direct-server.ts:40-53` 完全未校验，需修复）。

### 2.4 QR 码有效期与一次性使用（P1）

当前 token 在 gateway 启动后永久有效，截图可复用。补充：

- **TTL**：QR 码 JSON 增加 `expiresAt` 字段（Unix 毫秒时间戳），默认 **10 分钟**。
- **双端校验**：
  - App 端：扫描后先校验 `Date.now() < expiresAt`，过期则提示"二维码已过期，请刷新"。
  - Gateway 端：握手校验 token 时**同时校验未过期**（`Date.now() < this.tokenExpiresAt`），防恶意 App 跳过本地校验。过期返回 `error`（code=`EXPIRED_QR`）。
- **刷新机制**：过期后 gateway 重新生成 `{token, expiresAt}` 并刷新终端二维码。直连模式下通过终端按键（如回车）触发刷新；relay 模式下 gateway 可周期性（每 9 分钟）预刷新 QR 并重新向 relay 注册新 token。

### 2.5 防重放攻击（P2）

当前消息无序号/nonce，无法防重放。补充：

- **每条加密消息**增加 `seq` 字段（uint32，从 1 递增），随 payload 一起加密。
- **接收方维护**最近 256 个已见 seq 的滑动窗口，重复 seq 丢弃并记日志。
- **乱序处理**：seq 间隙 < 256 时缓冲等待填补（最长等待 2s，超时按乱序投递并记 `WARN`）；间隙 > 256 触发全量重同步（重新握手）。
- **回绕处理**：uint32 达到 `0xFFFFFFFF` 后回绕到 1，此时接收方检测到 `seq < lastSeen` 且 `lastSeen > 0xF0000000`，判定为正常回绕并重置窗口基准。

### 2.6 本地敏感数据保护（P2）

当前 App 用 Preferences 明文存储 `publicKey`、`token`。补充：

- **敏感字段加密存储**：使用鸿蒙 `@kit.ArkData` 的加密能力或 HUKS（HarmonyOS Universal Keystore）对 `token`、`publicKey` 加密后落库。
- **完整公钥必须保留**：保存的连接用于免扫码重连，重连时需用对方公钥做 ECDH，因此 `publicKey` **不能只存指纹**。
- **公钥指纹仅用于展示**：在连接列表/详情页用 SHA-256 前 8 字节 hex 作为"公钥指纹"展示，便于用户人工核对，但不替换完整公钥的存储。
- **token 仅单次有效**：保存的连接中 `token` 仅作下次连接触发握手用；配合 2.4 的 TTL，过期连接提示"请重新扫码刷新"。

### 2.7 Relay 元数据混淆（P3）

端到端加密保护内容，但 Relay 可观测通信频率/流量大小。可选增强：

- **流量整形**：固定心跳包大小，对齐小消息到统一分片大小。
- **后续迭代**：Relay 模式下支持 dummy 填充流量（非 MVP）。

---

## 3. 消息协议补充

### 3.1 消息分片协议（P1）

主文档只说"超限分片"，未定义格式。补充完整分片协议：

**分片与加密的层次关系**：先分片，再对每个分片帧整体加密。即原始消息 → 切片 → 每个分片帧各自走正常加密流程。分片帧本身是应用层消息（有 `type/id/seq/data`），**必须加密**。

```jsonc
// 单个分片帧（加密前的明文结构，类型归入 data 层，外层仍是标准 {type,id,seq,data,timestamp}）
{
  "type": "chunk",
  "id": "<origMsgId>",          // 原始消息 UUID
  "data": {
    "chunkId": "<uuid>",        // 本次分片批次标识
    "seq": 0,                   // 片序号，从 0 起
    "total": 3,                 // 总片数
    "payload": "<base64>"       // 分片数据；start 片为空，end 片为空，data 片携带
    "status": "start" | "data" | "end"
  }
}
```

- **发送方**：消息 > 1MB 时切片，依次发 `status=start` → `status=data`(N) → `status=end`，每帧独立加密。
- **接收方**：按 `chunkId` 缓冲，收齐后按 `seq` 拼接 `payload` 解出原始消息再分发 UI。乱序容忍。
- **缺失重传**：接收方收到 `chunk(status=start)` 后 5s 未收齐全部分片，发送 `chunk_resend` 请求（方向与分片相反）：
  ```jsonc
  { "type": "chunk_resend", "data": { "chunkId": "<uuid>", "missing": [1, 2] } }
  ```
  发送方重发对应 `seq` 的分片帧。重传 3 次仍失败则丢弃整批发 `error`（code=`CHUNK_TIMEOUT`）。
- **两种模式统一**：直连与 relay **必须实现同一套分片逻辑**（当前 relay 模式 `relay-client.ts` 缺失，需补齐）。建议抽到共享 `Chunker` 模块。

### 3.2 消息顺序保证（P2）

- 每条应用消息增加 `seq`（见 2.5），接收方按 seq 排序后投递 UI。
- SSE 流本身保序，但跨重连的场景下依赖 seq + UUID 去重。

### 3.3 消息类型统一（P2）

主文档 `dcode.md:129`、README、实现三处不一致。统一为下表（见**附录 A**）。新增类型：
- `chunk`（分片，内含 `status=start/data/end`，见 3.1）
- `chunk_resend`（分片重传请求）
- `history`（历史消息批量回传，见 1.2）
- `sync`（重连续点同步，见 4.1）
- `session_delete`（删除会话）

### 3.4 幂等性实现位置（P2）

- **去重由接收方负责**（Gateway 去重 App 消息，App 去重 Gateway 消息）。
- 缓存最近 256 条消息 id，重复 id 丢弃并记 `WARN`。

---

## 4. 连接管理补充

### 4.1 重连后状态恢复（P1）

主文档只规定退避参数，未规定恢复行为。补充状态机：

```
[断线] → [指数退避重连] → [重新握手] → [恢复 session 订阅] → [拉取离线期间消息]
```

- **重新握手**：重连后必须重新执行三步握手（当前 relay 重连后未重置 `handshakeState`，状态会卡在 `complete`）。
- **恢复 session**：握手成功后 Gateway 重新对当前 `opencodeId` 建立 SSE 订阅。
- **离线消息补传（带续点协议）**：
  - App 重连握手成功后，发送 `sync` 消息：`{ type: "sync", data: { lastSeq: <App最后收到的seq> } }`。
  - Gateway 自 `lastSeq+1` 起补传离线期间 opencode 事件。补传条数上限 500 条，超出时通过 `history.hasMore=true` + `cursor` 提示"有更早记录，下拉加载"。
  - App 依据 `seq` 去重，避免重复显示。
  - 若 App 首次连接（无 lastSeq），Gateway 补传当前 session 最近 50 条历史。

### 4.2 App 前后台生命周期（P2）

- **进入后台**：保持 WebSocket，降低心跳频率（30s → 120s）。
- **后台超过 5 分钟**：主动断开，省电；返回前台后触发重连。
- **返回前台**：立即触发重连（若已断开），恢复到 [4.1] 流程。
- **未决权限的协调**：进入后台时若有未处理的 `permission_request`，**不立即断开**，等待用户处理或 60s 超时后再按后台策略执行；避免后台断开导致权限被 Gateway 65s 兜底强制拒绝。

### 4.3 直连/中转自动降级（P3，非 MVP）

- 直连握手失败 3 次后，若 QR 中同时含 `relayUrl`，提示用户"是否尝试中转连接"。
- MVP 阶段可不做，仅手动切换。

### 4.4 重连中握手状态重置（P1，bug 修复）

当前 `relay-client.ts` 重连后不重置 `handshakeState`，若 relay 未发 `peer_disconnected`（如进程崩溃），状态卡死。规定：

- **每次 WebSocket close/error**，无论是否收到 `peer_disconnected`，都执行 `cleanupConnection()` 重置 `handshakeState = 'waiting'` 并清理临时握手字段。

---

## 5. 功能行为补充

### 5.1 权限请求超时机制（P1）

主文档说"60s 超时自动拒绝"未明确责任端。规定**App 主导、Gateway 兜底，时间错开**：

- **App 端（主导）**：UI 卡片显示 60s 倒计时；倒计时结束自动发 `permission_reply(allowed=false, reason=timeout)`，卡片标记为"已超时自动拒绝"。
- **Gateway 端（兜底）**：自转发 `permission_request` 起 **65s** 未收到 reply，主动调用 opencode 权限拒绝接口，并记 `WARN` 日志。
- **时间错开**：Gateway 兜底设为 65s（比 App 多 5s），确保 App 在线时**由 App 先触发**，避免 App 的延迟回复与 Gateway 兜底冲突。Gateway 收到已超时的 reply 时忽略并记 `DEBUG`。
- **App 离线场景**：App 断开期间 Gateway 的 65s 兜底生效；若 App 重连时权限已超时，Gateway 不再补发该权限请求。

### 5.2 Session 管理行为（P1）

补充主文档未明确的边界行为：

- **切换 session**：App 发 `session_switch` 后**立即清空本地消息列表**，等待 `history` 批量回传（当前 `ChatPage.ets` 不清空，新旧混杂，需修复）。
- **新建 session**：创建后切换到新会话，消息列表为空。
- **删除 session**：App 发 `session_delete` → Gateway 调 opencode 删除 → 回 `session_list` 更新列表。
- **Session 列表上限**：当前 `ChatPage.ets:298-312` 硬编码最多 5 个，应改为**滚动列表浮层**，无上限。

### 5.3 Token 上下文窗口来源（P1）

- **limit 来源**：来自 opencode `GET /sessions/:id/tokens` 返回的 `contextWindow` 字段（非硬编码）。
- **展示规则**：`已用/上限`，超额时变红提示。
- **详情浮层**：点击展示 `inputTokens`、`outputTokens`、`total`、`contextWindow`、`占比%`。所有字段必须来自 opencode token 响应，不得臆造（如 `cost($)`——仅当 opencode 未来返回该字段时才展示，当前不显示）。

### 5.4 审查页面 URL 安全（P2）

- **白名单校验**：App 仅允许加载 `opencodeUrl` 同源或 localhost 的 URL，拒绝外部域名。
- **WebView 配置**：禁用文件访问（`fileFromUrlAccess=false`），按需开启 JS/DOM storage，隔离 cookie。
- **URL 透传校验**：Gateway 侧校验 review URL 是否以配置的 opencodeUrl 为前缀。

### 5.5 "大头贴"图片来源（P3）

- 连接保存时由用户选择或生成首字母头像（HarmonyOS 本地图形绘制）。
- 不涉及网络下载，无隐私风险。

### 5.6 Markdown 与 Mermaid 渲染（P1）

- **Markdown**：集成 `@luvi/lv-markdown-in` HAR 包替换当前手写 `MarkdownText.ets`。需将其加入 `oh-package.json5` 依赖。
- **Mermaid**：当前用 CDN（`MermaidDiagram.ets:51`），改为**本地打包 mermaid.min.js** 放入 `resources/rawfile/`，WebView 用 `resource://rawfile/mermaid.min.js` 加载，实现离线可用。

---

## 6. 错误处理与日志规范（P2）

### 6.1 错误码体系

见**附录 B**。所有 `error` 消息 data 增加 `code` 字段：

```jsonc
{
  "type": "error",
  "data": {
    "code": "INVALID_TOKEN",
    "message": "Token 无效，请重新扫码",
    "detail": "optional technical detail"
  }
}
```

- `message`：用户友好文案（App 直接展示）。
- `detail`：技术细节（仅日志，不展示）。

### 6.2 结构化日志规范

主文档要求"JSON 格式含时间戳、级别、模块、消息"，当前全是 `console.log`。统一格式：

```jsonc
{ "ts": "2026-06-19T10:00:00.000Z", "level": "INFO", "module": "DirectServer",
  "msg": "Handshake complete", "sessionId": "...", "traceId": "..." }
```

- **级别**：`TRACE | DEBUG | INFO | WARN | ERROR`。
- **字段**：必填 `ts/level/module/msg`；可选 `sessionId/msgId/traceId/errorCode/duration`。
- **实现**：封装共享 `Logger` 类（gateway/relay 复用），替换裸 `console`。
- **级别可控**：通过 `DCODE_LOG_LEVEL` 环境变量过滤。

### 6.3 未捕获异常防护（P1，bug 修复）

`direct-server.ts:76` 加密分支外层 `JSON.parse` 无 try/catch，损坏帧会导致未捕获异常。规定：**所有入站消息的 JSON 解析、解密、JSON.parse 必须包在 try/catch**，失败发 `error`（code=`BAD_FRAME`）并跳过，不得中断连接。

---

## 7. 版本兼容性（P1）

主文档说"版本不匹配提示升级"但未定义规则。补充：

- **版本号格式**：语义化版本 `MAJOR.MINOR.PATCH`（如 `0.1.0`）。
- **兼容性判定**：
  - `MAJOR` 不一致 → 不兼容，握手后提示"App 与 Gateway 版本不兼容，请升级"。
  - `MAJOR == 0`（初始开发阶段，特殊规则）：`MINOR` 不一致即视为不兼容（0.x 版本无稳定性保证，0.1 与 0.2 可能不兼容）。
  - `MAJOR >= 1` 且 `MINOR` 差距 ≥ 2 → 警告但允许连接。
  - `PATCH` 不影响兼容性。
- **握手交换**：当前已交换 `version` 字段但未比较。在 Step 2 ACK 时 Gateway 比较版本，不兼容则发 `error`（code=`VERSION_MISMATCH`）后关闭连接。

---

## 8. 部署与运维

### 8.1 Relay 服务器部署指南（P2）

- **单机部署**：`npm run dev` / Docker，适合小规模。
- **水平扩展**：基于 token 哈希一致性路由到同一 Relay 实例（同一对 gateway-app 必须命中同一实例）。
- **监控**：暴露 `/health` 与 `/metrics`（连接数、转发量、配对成功率）。
- **认证**（建议）：gateway 注册时携带 relay 预共享密钥，防未授权注册。

### 8.2 配置项与环境变量统一

见**附录 C**。统一 CLI 参数与环境变量，补齐缺失的 `--host`、`--computer-name`。

### 8.3 Opencode 版本检测（P1）

- Gateway 连接 opencode 后调用 `GET /version`（或 `/health` 返回 version）。
- 与 Gateway 内置的兼容版本范围比较，不兼容则启动报错并提示。

---

## 9. 测试策略

### 9.1 单元测试补齐

- **App**：当前零测试。补齐 `WebSocketService`（握手、加解密、重连）、`ConnectionService`（CRUD、加密存储）、`MessageBubble`（类型分发）的单元测试。
- **mock-opencode**：补齐行为型测试（消息→SSE 响应联动，而非固定序列）。

### 9.2 E2E 自动化

- **鸿蒙模拟器**：使用 DevEco CLI（`hdc`）驱动，脚本化扫码→连接→聊天→权限流程。
- **测试数据**：统一 mock QR JSON、固定密钥对（见 `app/TESTING_GUIDE.md` 附录）。
- **TC 用例**：每个 TC-* 编写可执行脚本，输出通过/失败报告。

### 9.3 测试用例补遗

| ID | 场景 | 预期 |
|----|------|------|
| TC-C06 | 过期 QR 扫码 | 提示"二维码已过期" |
| TC-C07 | 重放相同 token 握手（若启用一次性） | 第二次拒绝 |
| TC-M11 | 切换 session 历史加载 | 消息列表先清空再加载历史，无混杂 |
| TC-M12 | 离线后重连消息补传 | 离线期间事件通过 history 补传，seq 去重 |
| TC-G05 | 第三步握手密钥校验 | 错误密钥的 verify 被拒，连接关闭 |
| TC-G06 | 直连 token 校验 | 错误 token 立即拒绝（修复 direct-server） |
| TC-G07 | relay 模式消息分片 | >1MB 消息经 relay 正确分片重组 |
| TC-M13 | 流式回复增量渲染 | start→append→end，逐步显示，结束时 Markdown 完整渲染 |
| TC-M14 | 流中断后重连恢复 | 30s 未收到 end 标记"响应中断"，重连后补传 |
| TC-M15 | 并发权限请求 | 多卡片堆叠，各自独立倒计时 |
| TC-M16 | 被踢连接提示 | 收到 CONFLICT 后停止重连并提示 |
| TC-G08 | App 先于 Gateway 注册 relay | App 等待 30s 超时提示 |
| TC-G09 | opencode 重启恢复 | 收到 OPENCODE_RESTARTED，消息列表清空 |
| TC-G10 | SSE 订阅切换清理 | 切换 session 后旧 SSE 被 abort |
| TC-G11 | 应用层心跳超时 | 45s 无 heartbeat 主动断开重连 |
| TC-M17 | 首个会话引导 | 握手后自动收到 session_list + history |
| TC-M18 | 消息接收确认 | 发消息后收到 message_ack，标记已接收 |
| TC-M19 | opencode 响应超时 | 120s 无事件，提示超时 |
| TC-M20 | 流式期间发新消息 | 旧流收到 aborted，新流正常开始 |
| TC-M21 | 重复权限去重 | 同 requestId 第二次不展示卡片 |
| TC-M22 | 重复扫码匹配 | 同 publicKey 提示打开，不同提示新建 |

---

## 10. 术语校正（P2）

主文档 `dcode.md:26` 写"https端到端加密"，**不准确**。实际为：

- 传输层：WebSocket（`ws://`，明文）
- 应用层：X25519 ECDH 协商 + AES-256-GCM 端到端加密

校正表述：**"应用层端到端加密（X25519 + AES-256-GCM），传输层为 WebSocket，握手前公钥/nonce 明文传输，依赖扫码物理通道防 MITM。"**

---

## 11. 流式消息协议（P0）

主文档将 `thinking`、`reply` 标记为"流式显示"，但消息格式是原子的 `{content}`。AI 实际逐 token 输出，若每 token 发一条完整消息会造成大量重复渲染与数据冗余。本节定义 delta 增量协议。

### 11.1 增量 vs 完整模式

每条流式消息携带 `stream` 字段，标识该片段如何与已有内容合并：

| `stream` 值 | 含义 | App 行为 |
|-------------|------|----------|
| `"start"` | 流开始，`content` 为首片段 | 新建消息气泡，渲染首片段 |
| `"append"` | 追加片段，`content` 为增量文本 | 追加到**同一条消息**（按 `id` 匹配）末尾 |
| `"replace"` | 替换片段，`content` 为完整最新文本 | 整体替换同 `id` 消息内容 |
| `"end"` | 流结束，`content` 为最终完整文本 | 用最终文本替换，锁定消息（停止加载动画） |
| `"aborted"` | 流被中断（如用户发新消息），`content` 为已收到的部分文本 | 锁定消息并标记"已被中断" |
| 无 `stream` 字段 | 原子完整消息（向后兼容） | 直接渲染为独立消息 |

### 11.2 适用范围

- **`thinking`**：采用 `start` → `append`(N) → `end`。思考过程增量显示，结束时锁定。
- **`reply`**：采用 `start` → `append`(N) → `end`。最终回复逐 token 流式渲染，结束时做 Markdown/Mermaid 完整渲染。
- **`tool_call`**：采用 `start`（携带 `toolName`、`parameters`）→ `end`（补充 `result`）。执行中显示"调用中"，结果到达后更新。
- 其余消息类型（`permission_request`、`token_info` 等）为**原子消息**，无 `stream` 字段。

### 11.3 消息结构

```jsonc
// 流式消息（加密载荷内）
{
  "type": "thinking" | "reply" | "tool_call",
  "id": "<固定UUID，同一流期间不变>",
  "seq": <全局递增seq>,
  "stream": "start" | "append" | "end",
  "data": { "content": "增量或完整文本" },
  "timestamp": 1234567890
}
```

- **`id` 是流标识**：同一流的多个片段共享同一 `id`，App 据此聚合。
- **App 渲染策略**：`start` 创建气泡；`append` 仅更新文本组件（避免每片段重新解析 Markdown，性能优化）；`end` 触发一次完整 Markdown/Mermaid 解析渲染。
- **流中断恢复**：若 App 在流中途断线重连，通过 [4.1] 的 `sync` 续点协议补传，`end` 片段到达前气泡保持"加载中"状态；超时（30s 未收到 `end`）则标记为"响应中断"。
- **幂等**：`append` 片段若重复（重连补传），App 依据 `seq` 去重，已渲染的 `seq` 跳过。

### 11.4 Markdown 渲染时机

- 流式过程中（`start`/`append`）显示**纯文本**或轻量格式（行内代码、加粗），不做完整 Markdown 解析（避免每 token 重渲染的性能开销）。
- 仅在 `end` 时做一次完整 Markdown + Mermaid 渲染。

---

## 12. 并发与资源管理

### 12.1 seq 方向空间（P2）

- **双向独立计数**：App→Gw 方向和 Gw→App 方向各维护**独立的 seq 计数器**，互不影响。
- App 的发送 seq 从 1 起，Gateway 的发送 seq 也从 1 起，接收方各自维护一个方向的去重窗口。
- 重连后各方向 seq **重置为 1**（新握手 = 新 seq 空间），配合 `sync` 的 `lastSeq` 仅在当前握手周期内有效。

### 12.2 SSE 订阅生命周期（P1）

- **每个 session 独立 SSE 连接**：Gateway 对每个活跃 session 维护一条到 opencode 的 SSE 流。
- **切换 session 时**：App 发 `session_switch` → Gateway **先 abort 旧 session 的 SSE 订阅**（`AbortController.abort()`）→ 再对新 `opencodeId` 建立新 SSE 订阅。避免连接泄漏。
- **删除 session 时**：abort SSE + 删除本地映射 + 调 opencode 删除接口。
- **资源上限**：单 Gateway 维护的 SSE 流不超过 **8 条**（即最多 8 个并发 session 订阅）；超出时拒绝新建并提示"请先关闭其他会话"。

### 12.3 opencode 崩溃/重启恢复（P1）

- **检测**：Gateway 的 SSE 流收到 `error` 或连接断开时，调用 `GET /version` 探活；若 opencode 不可达，向 App 发 `error`（code=`OPENCODE_UNREACHABLE`）。
- **重启后**：opencode 重启会导致所有 session ID 失效。Gateway 检测到 SSE 全部断开后**清空本地 SessionManager 映射**，向 App 发 `session_list`（空）+ `error`（code=`OPENCODE_RESTARTED`，文案"桌面端服务已重启，请重新开始会话"）。
- **App 行为**：收到 `OPENCODE_RESTARTED` 后清空消息列表，提示用户"会话已因服务重启重置"。

### 12.4 新连接踢旧连接（P2）

主文档说"新连接会踢掉旧连接"，补充两模式的具体行为：

- **直连模式**：Gateway 收到新 App 的 WebSocket 连接时，若已有活跃连接，向旧连接发送 `error`（code=`CONFLICT`，文案"连接已被其他设备取代"）后关闭旧 WebSocket，再与新 App 握手。
- **Relay 模式**：新 App 注册同一 token 时，Relay 检测到已有同 token 的 app 注册，向旧 app 发 `{type:'peer_disconnected', reason:'replaced'}`，Gateway 侧收到 `peer_disconnected` 后清理状态，接受新配对。
- **App 被踢行为**：收到 `CONFLICT`/`replaced` 后停止重连（区别于普通断线的自动重连），显示"该连接已被其他设备使用"。

### 12.5 并发权限请求（P2）

- 允许**多条 permission_request 同时在途**，App 按 `requestId` 区分，UI 以堆叠卡片展示，各自独立 60s 倒计时。
- App 维护待处理权限队列，用户可逐个处理。
- Gateway 对每个 `requestId` 独立维护 65s 兜底定时器。

### 12.6 消息大小限制语义（P2）

- **1MB 限制针对加密后帧**：即外层 WebSocket 文本帧的 UTF-8 字节数 ≤ 1MB。
- 换算：明文经 Base64 + IV + authTag 后膨胀约 35%，故原始明文 JSON 上限约 **740KB**。
- 超过 740KB 的明文消息触发 [3.1] 分片协议。

---

## 13. Relay 配对协议补充（P1）

主文档只描述了 Gateway→Relay 的注册，未定义 App→Relay 的连接流程。补充完整双向协议。

### 13.1 App 连接 Relay 流程

```
[1] App 扫码获得 relayUrl + token
[2] App 连接 relayUrl 的 WebSocket
[3] App 发送 { type: "register", token, role: "app", version }
[4a] 若 Gateway 已注册 → Relay 回 { type: "paired", token }
[4b] 若 Gateway 未注册 → Relay 回 { type: "waiting", token }
    → App 显示"等待电脑端连接..."
    → Gateway 注册后 Relay 回 paired
[5] 配对后，后续消息透明转发（加密密文）
```

- **App 超时**：发送 register 后等待配对 **30s**，超时提示"电脑端未响应，请确认 Gateway 已启动"。
- **Relay 待配对清理**：Relay 对 `pendingClients` 中超过 **60s** 未配对的注册连接主动关闭并清理。

### 13.2 Relay 注册消息安全（P2）

- 当前 token 明文发给 relay（注册消息）。8.1 建议的 relay 预共享密钥接入注册消息：
  ```jsonc
  { "type": "register", "token": "<配对token>", "role": "gateway"|"app", "version": "0.1.0", "relayKey": "<预共享密钥>" }
  ```
- Relay 校验 `relayKey` 通过后才接受注册，防未授权连接。`relayKey` 通过 Gateway 配置文件的 `relayKey` 字段 + QR 码透传给 App。
- **配对 token 与 relayKey 分离**：token 用于 gateway-app 配对关联，relayKey 用于 relay 服务准入认证，职责不同。

### 13.3 QR 码结构扩展

补充 [2.4] 后，QR 码 JSON 完整结构：

```jsonc
{
  "mode": "direct" | "relay",
  "name": "电脑名",
  "host": "192.168.x.x",          // direct 模式有效；relay 模式可省略或为空
  "port": 8765,
  "publicKey": "base64(X25519公钥)",
  "token": "uuid",
  "expiresAt": 1718800000000,     // 新增，Unix 毫秒
  "relayUrl": "wss://relay.example.com",  // relay 模式必填
  "relayKey": "base64"             // 新增，relay 模式必填
}
```

- **direct 模式**：省略 `relayUrl`、`relayKey`；`host/port` 必填。
- **relay 模式**：省略无意义的 `host/port`（App 经 `relayUrl` 连接）；`relayUrl`、`relayKey` 必填。

---

## 14. 心跳与连接存活检测（P2）

主文档说"利用 WebSocket ping/pong 帧检测存活"但未给参数。补充：

### 14.1 双层存活检测

| 层级 | 机制 | 间隔 | 超时 | 说明 |
|------|------|------|------|------|
| 传输层 | WebSocket ping/pong 帧 | 15s | 10s 未收 pong | 网关/Relay 侧发起，TCP 级保活 |
| 应用层 | 加密 `heartbeat` 消息 | 30s | 45s 未收 | 端到端存活，验证加密通道可用 |

- **传输层 ping/pong**：WebSocket 协议内置，无需业务代码，由 ws 库自动处理。超时触发 `close` 事件。
- **应用层 heartbeat**：握手成功后启动，双向互发 `{type:"heartbeat", data:{ts}}`，加密携带 `seq`。用于检测"传输层活着但加密层卡死"的场景。
- **前后台切换**：前台 30s 间隔，后台降为 120s（见 [4.2]）。

### 14.2 检测到失联后的行为

- 传输层超时 → 触发 `close` → 进入 [4.1] 重连流程。
- 应用层超时（45s 无 heartbeat）→ 主动 `close` WebSocket 并进入重连流程（避免半开连接）。
- App 发送 heartbeat 后 45s 无回应，UI 状态点变灰"连接异常"。

---

## 15. 交互时序与会话引导

### 15.1 首个会话引导流程（P1）

握手成功后，从"已连接"到"首个可用会话"的引导步骤此前为空白。规定如下：

```
[握手完成] 
  → Gateway 调用 opencode.listSessions()
    ├─ 有历史 session：取最近活跃的 1 个为 activeSession，推 session_list + history
    └─ 无 session：Gateway 调用 opencode.createSession() 建立默认会话，推 session_list
  → Gateway 对 activeSession 建立 SSE 订阅
  → Gateway 推 history（该会话最近 N 条）供 App 渲染
```

- **不得使用本地自生成 ID**（修复当前 `direct-server.ts:124` 直接 `sessions.create('Default')` 的行为，必须经 opencode）。
- **App 端**：握手成功后**等待** `session_list` 消息到达后再渲染会话 UI；超时（10s 未收到）显示"加载会话失败，请重试"。

### 15.2 session_list 推送时机（P2）

明确 `session_list` 的推送触发点（当前实现仅在 `session_create` 后推送，遗漏多处）：

| 时机 | 是否推送 | 说明 |
|------|----------|------|
| 握手完成后（[15.1]） | 是 | 首次告知 App 会话列表 |
| `session_create` 后 | 是 | 列表已更新 |
| `session_delete` 后 | 是 | 列表已更新 |
| App 发送 `session_list` 请求 | 是 | 支持显式拉取（新增请求语义） |
| opencode 侧 session 变化 | 是 | 若 opencode 支持 session 变更通知 |

> `session_list` 请求与响应复用同一消息类型：App 发 `{type:"session_list"}`（data 为空）作请求；Gateway 回 `{type:"session_list", data:{sessions:[...]}}`。通过 `data` 是否为空区分请求/响应。

### 15.3 token_info 推拉分离（P2）

当前 `token_info` 消息类型同时用作 App 请求（拉）和 Gateway 推送（SSE），语义混乱。拆分：

- **推送**：opencode 通过 SSE `token_usage` 事件推送 → Gateway 转 `token_info` 消息给 App（每次回复后自动更新）。
- **拉取请求**：App 主动查询改用显式类型 `token_query`：`{type:"token_query"}`，Gateway 回 `token_info`。
- 由此 `token_info` **仅作 Gw→App 推送/响应**，`token_query` 仅作 App→Gw 请求，职责清晰。

### 15.4 user_message 确认与超时（P1）

App 发送消息后无确认机制，opencode 无响应时会永久挂起。补充：

- **接收确认（ACK）**：Gateway 收到 `user_message` 后**立即回 `message_ack`**：`{type:"message_ack", data:{id:<原消息id>, status:"accepted"}}`。App 据此将消息标记为"已接收"（避免重发）。
- **处理超时**：Gateway 转发 `user_message` 给 opencode 后，若 **120s** 内无任何 SSE 事件（thinking/tool_call/reply）返回，向 App 发 `error`（code=`OPENCODE_TIMEOUT`，文案"桌面端响应超时"），并建议用户重试。
- **App 端超时**：App 发送消息后 30s 未收到 `message_ack`，提示"消息发送失败，请检查连接"；收到 ACK 后 120s 未收到首条回复事件，显示"等待响应中..."并可手动取消。
- **取消机制**：App 发送 `{type:"cancel"}` 可中止当前请求（Gateway 调 opencode 取消接口，若支持；否则忽略后续 SSE 事件）。

### 15.5 流式期间发新消息（P1）

AI 正在流式输出时用户发送新消息的行为此前未定义：

- **中止旧流**：Gateway 收到新 `user_message` 时，若当前会话有未完成的流（已发 `start` 未发 `end`），向 App 发**旧流的 `end`（标记 `stream:"aborted"`）** 关闭旧流，再处理新消息。
- **禁止并发流**：同一会话**不允许两个 reply 流同时进行**。新消息总是取代旧流。
- **App 行为**：收到 `stream:"aborted"` 的 `end` 后，旧消息气泡标记为"已被新消息中断"，停止加载动画。

### 15.6 permission_request 去重（P2）

opencode 可能因 SSE 重连等原因重发同一权限请求。补充：

- **App 端**：维护在途 `requestId` 集合，收到已存在的 `requestId` 时**忽略并记 `DEBUG`**（不重复展示卡片）。
- **Gateway 端**：转发权限请求前检查是否已转发过同一 `requestId`，重复则跳过。

### 15.7 SSE 订阅策略（P2）

明确 Gateway 维护 SSE 的范围（当前实现仅维护活跃会话一个）：

- **仅活跃会话订阅**：Gateway 只对当前 `activeSession` 维护一条 SSE 流。切换会话时 abort 旧流、建立新流（与现有实现一致）。
- **理由**：节省 opencode 连接资源，避免多流管理复杂度。非活跃会话的事件在重新切换时通过 `history` 补传。
- **限制**：用户无法同时接收多个会话的实时事件（设计取舍，符合手机端单会话聚焦的交互）。

### 15.8 重复扫码的连接匹配（P2）

主文档 TC-C03"扫码已存在连接"未定义匹配键。token 刷新后会变，不能作为匹配键。规定：

- **匹配键**：`mode + host + port`（直连）或 `mode + relayUrl`（中转）+ `publicKey` 指纹。
- **匹配后**：
  - 若 publicKey 相同（同一 gateway 未重启）：提示"已存在连接 [名称]，是否打开？"，可选更新 token。
  - 若 publicKey 不同（gateway 已重启/换密钥）：视为新连接，提示"电脑端密钥已变更"，建议新建连接。


---

## 附录 A：消息类型完整对照表

> **加密规则**：除 `handshake_init` / `handshake_ack` 在握手阶段明文外，**其余所有消息（含 `handshake_complete`、`heartbeat`、`chunk`、`chunk_resend`、`sync`）必须加密传输**。`heartbeat` 虽不携带业务数据，仍需加密并携带 `seq` 以纳入防重放窗口。
>
> **流式字段**：`thinking`、`reply`、`tool_call` 支持流式，携带可选 `stream` 字段（`start`/`append`/`replace`/`end`），同一流的片段共享同一 `id`（见 11）。

| 类型 | 方向 | data 字段 | 加密 | 说明 |
|------|------|-----------|------|------|
| `handshake_init` | App→Gw | `{publicKey, nonce, token, version}` | 否 | 握手第1步 |
| `handshake_ack` | Gw→App | `{publicKey, nonce, version, verify}` | 否 | 握手第2步（含 Gateway 密钥确认） |
| `handshake_complete` | App→Gw | `{verify}` | 是 | 握手第3步（App 密钥确认） |
| `user_message` | App→Gw | `{content}` | 是 | 用户输入 |
| `message_ack` | Gw→App | `{id, status}` | 是 | 消息接收确认（新增，见 15.4） |
| `cancel` | App→Gw | `{}` | 是 | 取消当前请求（新增，见 15.4） |
| `thinking` | Gw→App | `{content}` + `stream?` | 是 | 思考过程（流式，见 11） |
| `tool_call` | Gw→App | `{toolName, parameters, result?}` + `stream?` | 是 | 工具调用（流式） |
| `permission_request` | Gw→App | `{requestId, description}` | 是 | 权限请求 |
| `permission_reply` | App→Gw | `{requestId, allowed, reason?}` | 是 | 权限回复 |
| `reply` | Gw→App | `{content}` + `stream?` | 是 | AI 最终回复（流式，Markdown，见 11） |
| `review_url` | Gw→App | `{url}` | 是 | 审查页面 URL |
| `session_list` | 双向 | App 请求 data 为空；Gw 响应 `{sessions:[{id,name}]}` | 是 | 会话列表（请求/响应复用，见 15.2） |
| `session_switch` | App→Gw | `{sessionId}` | 是 | 切换会话 |
| `session_create` | App→Gw | `{name?}` | 是 | 新建会话 |
| `session_delete` | App→Gw | `{sessionId}` | 是 | 删除会话（新增） |
| `token_info` | Gw→App | `{total, input, output, contextWindow}` | 是 | Token 消耗（仅推送/响应，见 15.3） |
| `token_query` | App→Gw | `{}` | 是 | 主动查询 Token（新增，见 15.3） |
| `history` | Gw→App | `{sessionId, messages:[], hasMore, cursor}` | 是 | 历史批量回传（新增） |
| `heartbeat` | 双向 | `{ts}` | 是 | 心跳保活（加密，带 seq） |
| `chunk` | 双向 | `{chunkId, seq, total, payload, status}` | 是 | 分片帧（新增，status=start/data/end） |
| `chunk_resend` | 双向 | `{chunkId, missing:[int]}` | 是 | 分片重传请求（新增） |
| `sync` | App→Gw | `{lastSeq}` | 是 | 重连续点同步（新增） |
| `error` | Gw→App | `{code, message, detail?}` | 是 | 错误 |

> 所有加密消息统一结构为 `{type, id, seq, data, timestamp}`，其中 `seq` 见 2.5 防重放（**双向独立计数**，见 12.1）。`handshake_init/ack` 明文因密钥尚未派生。

---

## 附录 B：错误码枚举

| code | 触发场景 | 用户文案 |
|------|----------|----------|
| `INVALID_TOKEN` | 握手 token 校验失败 | Token 无效，请重新扫码 |
| `EXPIRED_QR` | QR 过期 | 二维码已过期，请刷新 |
| `HANDSHAKE_FAILED` | 第三步密钥确认失败 | 连接握手失败 |
| `VERSION_MISMATCH` | 版本不兼容 | 版本不兼容，请升级 |
| `BAD_FRAME` | 消息帧格式错误 | 数据异常（自动忽略） |
| `CHUNK_TIMEOUT` | 分片重传 3 次仍失败 | 大消息传输失败 |
| `UNKNOWN_EVENT` | 未知 SSE 事件类型 | （仅日志） |
| `PERMISSION_TIMEOUT` | 权限超时自动拒绝 | 操作超时已自动拒绝 |
| `SESSION_NOT_FOUND` | opencode session 不存在 | 会话不存在 |
| `OPENCODE_UNREACHABLE` | opencode 连接失败 | 桌面端服务不可用 |
| `OPENCODE_RESTARTED` | opencode 重启导致 session 失效 | 桌面端服务已重启，请重新开始会话 |
| `OPENCODE_TIMEOUT` | opencode 处理超时（120s 无事件） | 桌面端响应超时，请重试 |
| `CONFLICT` | 新连接取代旧连接 | 该连接已被其他设备使用 |
| `RATE_LIMITED` | 触发限流 | 操作过于频繁 |
| `SESSION_LIMIT` | 并发 session 超过上限 | 请先关闭其他会话 |
| `INTERNAL` | 其他未分类错误 | 发生未知错误 |

---

## 附录 C：配置项与环境变量对照表

| 配置键 | 环境变量 | CLI 参数 | 默认值 | 说明 |
|--------|----------|----------|--------|------|
| mode | `DCODE_MODE` | `--mode=` | `direct` | 连接模式 |
| host | `DCODE_HOST` | `--host=`（**补齐**） | `0.0.0.0` | 监听地址 |
| port | `DCODE_PORT` | `--port=` | `8765` | 监听端口 |
| relayUrl | `DCODE_RELAY_URL` | `--relay-url=` | — | Relay 地址 |
| opencodeUrl | `DCODE_OPENCODE_URL` | `--opencode-url=` | `http://localhost:3000` | opencode 地址 |
| computerName | `DCODE_COMPUTER_NAME` | `--computer-name=`（**补齐**） | 主机名 | 电脑显示名 |
| version | — | — | 包版本 | 版本号 |
| logLevel | `DCODE_LOG_LEVEL`（**新增**） | `--log-level=`（**新增**） | `INFO` | 日志级别 |
| qrTtlMs | `DCODE_QR_TTL`（**新增**） | — | `600000` | QR 有效期(ms) |
| relayKey | `DCODE_RELAY_KEY`（**新增**） | `--relay-key=`（**新增**） | — | Relay 准入预共享密钥（见 13.2） |

> CLI 解析当前仅支持 `--key=value` 形式，统一后应支持 `--key value` 空格分隔。

---

## 附录 D：Opencode API 契约

> Gateway 作为 opencode serve 的 HTTP 客户端，契约如下（mock-opencode 需对齐）：

| 方法 | 路径 | 请求体 | 响应 |
|------|------|--------|------|
| 创建会话 | `POST /sessions` | `{name?}` | `{id, name, createdAt}` |
| 会话列表 | `GET /sessions` | — | `[{id, name, createdAt}]` |
| 删除会话 | `DELETE /sessions/:id` | — | `{status:"ok"}` |
| 发送消息 | `POST /sessions/:id/messages` | `{content}` | `{status:"ok"}` |
| 订阅事件 | `GET /sessions/:id/events` | — | SSE 流（见下） |
| 历史消息 | `GET /sessions/:id/messages?limit=&cursor=`（**新增**） | — | `{messages:[...], hasMore, cursor}` |
| Token 用量 | `GET /sessions/:id/tokens` | — | `{total, input, output, contextWindow}` |
| 权限回复 | `POST /sessions/:id/permissions/:reqId` | `{allowed, reason?}` | `{status:"ok"}` |
| 审查 URL | `GET /review/url` | — | `{url}` |
| 版本 | `GET /version`（**新增**） | — | `{version}` |

**SSE 事件 payload 各类型**：
- `thinking`: `{content}`
- `tool_call`: `{toolName, parameters, result}`
- `permission_request`: `{requestId, description}`
- `reply`: `{content}`
- `token_usage`: `{total, input, output, contextWindow}`
- `review_url`: `{url}`
- `error`: `{message}`

**SSE 客户端重连**：流断开后 Gateway 必须重连（当前未实现，`opencode-client.ts:72-77` 直接返回）。重连使用 `Last-Event-ID` 头恢复。

**重要**：`POST /sessions/:id/messages` 只负责提交，实际响应通过 SSE 事件流异步推送。mock-opencode 当前用固定序列模拟，需改为**收到消息后向该 session 的活跃 SSE 流写入对应事件**。

---

## 实施优先级总结

| 优先级 | 项目 | 不修复的后果 |
|--------|------|--------------|
| **P0** | Opencode session ID 对接（1.1） | 对接真实 opencode 整个会话流失败 |
| **P0** | 直连 token 校验（2.3） | 安全形同虚设 |
| **P0** | 历史消息拉取（1.2） | 切换 session 数据混杂 |
| **P0** | 流式消息协议（11） | AI 输出无法增量显示，每 token 重渲染卡顿/冗余 |
| **P1** | 握手双向密钥确认（2.1） | 单向握手无法检测对端密钥错误 |
| **P1** | HKDF 派生（2.2） | 弱于标准 |
| **P1** | 分片协议统一（3.1） | relay 模式大消息丢失 |
| **P1** | 权限超时双端错开（5.1） | 权限永久挂起 / 双计时器竞态 |
| **P1** | Session 切换清空（5.2） | 新旧消息混杂 |
| **P1** | 版本校验含 0.x 规则（7） | 版本不兼容静默失败 |
| **P1** | 重连状态恢复 + sync 续点（4.1/4.4） | 重连后丢消息 / 无法恢复 |
| **P1** | 未捕获异常防护（6.3） | 损坏帧中断连接 |
| **P1** | 首个会话引导流程（15.1） | 握手后会话状态不明 |
| **P1** | user_message 确认与超时（15.4） | 消息无回执，opencode 无响应时永久挂起 |
| **P1** | 流式期间发新消息（15.5） | 旧流未关闭导致并发渲染错乱 |
| **P1** | SSE 订阅生命周期管理（12.2） | session 切换泄漏连接 |
| **P1** | opencode 崩溃恢复（12.3） | session 失效后陈旧引用 |
| **P1** | App↔Relay 注册协议（13.1） | relay 模式 App 无法配对连接 |
| **P2** | 防重放 seq + 回绕 + 双向计数（2.5/12.1） | 可重放攻击 |
| **P2** | 本地加密存储（2.6） | token 泄露 |
| **P2** | 结构化日志（6.2） | 运维困难 |
| **P2** | Markdown/Mermaid 离线（5.6） | 功能残缺 |
| **P2** | 心跳双层检测参数（14） | 半开连接无法检测 |
| **P2** | 新连接踢旧连接通知（12.4） | 被踢方无限重连 |
| **P2** | 并发权限队列（12.5） | 多权限请求 UI 错乱 |
| **P2** | 消息大小限制语义（12.6） | 边界值超限丢消息 |
| **P2** | session_list 推送时机（15.2） | App 不知有哪些会话 |
| **P2** | token_info 推拉分离（15.3） | 消息类型双向复用语义混乱 |
| **P2** | permission 去重（15.6） | 重复权限卡片 |
| **P2** | 重复扫码连接匹配（15.8） | token 刷新后无法识别已有连接 |
| **P2** | Relay 准入认证（13.2） | 未授权连接 |
| **P3** | Relay 扩展/混淆（2.7/8.1） | 非阻塞 |

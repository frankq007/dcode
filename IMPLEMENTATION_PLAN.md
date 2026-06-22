# DCode 分阶段实施计划

> 基于 `dcode.md`（主设计）与 `dcode-supplement.md`（补充设计）制定。每阶段含**验证门禁**，必须全部验收项通过方可进入下一阶段。

## 现状基线（制定计划时）

| 模块 | 完成度 | 关键缺口 |
|------|--------|----------|
| Gateway | 高 | createSession 链路断裂、直连 token 未校验、握手无密钥确认 |
| Relay | 中 | 无 relayKey 鉴权（pending 清理已有） |
| App | 低 | 握手是假的、消息零加密、Markdown 手写、Mermaid 走 CDN、Voice 是 stub |
| mock-opencode | 低 | 消息与 SSE 固定序列、无联动、零测试 |
| 测试 | 低 | gateway 13 个、relay 2 个、app 0 个、mock 0 个、集成 0 个 |

---

## 阶段依赖关系

```
阶段1: 基础契约(opencode API + mock 真实化)
   ↓ [验收: mock 行为型测试通过]
阶段2: 安全协议(端到端加密 + 握手 + token)
   ↓ [验收: 加密握手 e2e 通过]
阶段3: 核心消息流(流式 + 确认 + 会话引导 + 历史)
   ↓ [验收: 真实聊天流 e2e 通过]
阶段4: 连接韧性(重连 + sync + 心跳 + SSE生命周期)
   ↓ [验收: 断线重连状态恢复通过]
阶段5: 功能完整(Markdown离线 + 语音 + 审查 + 权限超时)
   ↓ [验收: 全功能 e2e 通过]
阶段6: 加固(防重放 + 日志 + 错误码 + 集成测试套件)
   ↓ [验收: 全量测试套件通过]
```

---

## 阶段 1：基础契约对齐（Opencode API + Mock 真实化）

**目标**：打通 gateway↔opencode 的真实 session 链路，mock-opencode 能模拟真实对话流。
**依赖**：无（基础设施阶段）
**参考设计**：补充文档 §1（opencode 契约）、§12.3（opencode 崩溃恢复）、附录 D

### 工作项

1. **修复 SessionManager↔opencode 链路**
   - `gateway/src/ws/direct-server.ts:124` 与 `relay-client.ts:125` 握手完成时改调用 `opencode.createSession()` 取真实 ID，禁止本地 `randomUUID()` 冒充
   - SessionManager 映射改为 `{ opencodeId, name, createdAt, lastActiveSeq }`
2. **mock-opencode 行为真实化**
   - POST `/sessions/:id/messages` 收到消息后，向该 session 的**活跃 SSE 流**写入对应事件（而非固定序列）
   - SSE 流保持长连接（不 2s 后关闭），按 session 内存中的消息队列驱动
   - 新增 `GET /sessions/:id/messages?limit=&cursor=` 历史拉取端点
   - 新增 `GET /version` 端点
3. **opencode-client SSE 重连**
   - `opencode-client.ts:72` 断开后重连，使用 `Last-Event-ID` 头恢复
4. **mock-opencode 测试**
   - 补齐行为型测试：发消息→SSE 收到对应事件、历史分页、版本端点

### 验收门禁（必须全部通过）

- [ ] **V1.1** `cd mock-opencode && npm test` 通过（新增行为型测试 ≥ 4 用例）
- [ ] **V1.2** `cd gateway && npm test` 通过（原有 13 + 新增 opencode 集成测试）
- [ ] **V1.3** 手动验证：启动 mock-opencode + gateway，用 curl/wscat 创建 session → 发消息 → SSE 收到对应事件（非固定序列）
- [ ] **V1.4** grep 确认 `opencode-client.createSession` 在 direct-server/relay-client 中被调用，`sessions.create` 不再单独用本地 UUID
- [ ] **V1.5** mock-opencode SSE 流持续 > 60s 不自动关闭

**退出标准**：gateway 能用真实 opencodeId 创建会话并收到消息驱动的 SSE 事件。

---

## 阶段 2：安全协议（端到端加密 + 握手 + Token）

**目标**：app 与 gateway 实现真实 ECDH 握手与 AES-256-GCM 加密，端到端密文可互通。
**依赖**：阶段 1 通过
**参考设计**：补充文档 §2（安全协议）、§2.1-2.6

### 工作项

1. **App 端实现真实加密栈**
   - 集成鸿蒙 X25519 + AES-256-GCM 能力（`@kit.CryptoArchitectureKit` 或等效）
   - `WebSocketService.ets` 生成密钥对、握手发送 publicKey+nonce、派生会话密钥
   - `sendMessage`/`handleMessage` 改为加密/解密 `{iv, ciphertext}` 结构
2. **双向握手密钥确认**（补充文档 §2.1）
   - handshake_ack 携带 Gateway 的 verify；handshake_complete 携带 App 的 verify
   - verify = AES-256-GCM(sessionKey, "DCODE-HANDSHAKE-OK"‖nonce1‖nonce2, IV=全零12字节)
3. **HKDF 派生**（补充文档 §2.2）
   - gateway `crypto-manager.ts` 的裸 SHA-256 改为 HKDF-SHA256；app 对齐
4. **Token 校验**（补充文档 §2.3）
   - direct-server 握手第1步校验 token，失败发 INVALID_TOKEN 后关闭
5. **QR 有效期**（补充文档 §2.4）
   - QR JSON 增加 expiresAt；gateway 与 app 双端校验
6. **未捕获异常防护**（补充文档 §6.3）
   - direct-server.ts:76 加密分支 JSON.parse 包 try/catch

### 验收门禁（必须全部通过）

- [ ] **V2.1** App 单元测试：密钥生成、ECDH 派生对称性、加解密往返通过（`ohosTest` 或独立 TS 测试）
- [ ] **V2.2** Gateway `crypto-manager.test.ts` 增加 HKDF 测试用例，验证与 app 派生结果一致（相同输入派生相同密钥）
- [ ] **V2.3** **端到端加密验证**：app 扫码连接 gateway，抓包/日志确认 WebSocket 负载为密文（非明文 JSON）
- [ ] **V2.4** **握手双向确认**：故意篡改 app 密钥 → handshake_complete 的 verify 校验失败 → 连接关闭（新增 TC-G05）
- [ ] **V2.5** **Token 校验**：错误 token 连接 → 收到 INVALID_TOKEN → 连接关闭（新增 TC-G06）
- [ ] **V2.6** **过期 QR**：修改 expiresAt 为过去时间 → app 提示"二维码已过期"（新增 TC-C06）
- [ ] **V2.7** 损坏密文帧 → gateway 记 BAD_FRAME 日志且不中断连接

**退出标准**：app↔gateway 全链路 AES-256-GCM 加密，无明文传输，握手双向密钥确认生效。

---

## 阶段 3：核心消息流（流式 + 确认 + 会话引导 + 历史）

**目标**：app 能与 gateway/opencode 完成真实聊天流：发消息→收到 ACK→流式回复→Markdown 渲染。
**依赖**：阶段 2 通过
**参考设计**：补充文档 §1.2（历史）、§11（流式）、§15（交互时序）

### 工作项

1. **流式消息协议**（补充文档 §11）
   - gateway SSE→app 消息增加 `stream` 字段（start/append/end/aborted）
   - app MessageBubble 支持同 id 片段聚合，append 时纯文本追加，end 时完整 Markdown 渲染
   - mock-opencode 支持流式推送（分多个 SSE 事件发送一条回复）
2. **message_ack 与超时**（补充文档 §15.4）
   - gateway 收到 user_message 立即回 message_ack
   - gateway 转发后 120s 无 SSE 事件 → 发 OPENCODE_TIMEOUT
3. **首个会话引导**（补充文档 §15.1）
   - 握手后 gateway 调 listSessions 取/建活跃会话 → 推 session_list + history
   - app 等待 session_list 后渲染
4. **session_list 推送时机**（补充文档 §15.2）
   - 握手后、增删后、显式请求时推送
5. **历史拉取与切换清空**（补充文档 §1.2、§5.2）
   - session_switch 时 app 清空消息列表 → gateway 回 history → app 渲染
6. **token_info 推拉分离**（补充文档 §15.3）
   - 新增 token_query 请求类型；token_info 仅作推送/响应
7. **流式期间发新消息**（补充文档 §15.5）
   - 旧流发 end(aborted)，禁止并发流

### 验收门禁（必须全部通过）

- [ ] **V3.1** **真实聊天流 e2e**：app 发"你好" → 收到 message_ack → 收到 thinking(start→append→end) → 收到 reply(start→append→end) → Markdown 正确渲染（新增 TC-M01+M13）
- [ ] **V3.2** **会话引导**：握手后自动收到 session_list + history，app 显示会话名和历史消息（新增 TC-M17）
- [ ] **V3.3** **切换会话清空**：切换 session 后消息列表先清空再加载历史，无新旧混杂（新增 TC-M11）
- [ ] **V3.4** **响应超时**：mock 配置延迟 120s+ → app 收到 OPENCODE_TIMEOUT 提示（新增 TC-M19）
- [ ] **V3.5** **流式中断**：AI 流式输出时发新消息 → 旧流标记 aborted，新流正常（新增 TC TC-M20）
- [ ] **V3.6** **token_query**：app 主动查询 → 收到 token_info，展示消耗（新增 TC-M08）

**退出标准**：完整聊天流程端到端可用，流式渲染、会话切换、超时处理均正常。

---

## 阶段 4：连接韧性（重连 + Sync + 心跳 + SSE 生命周期）

**目标**：网络中断后能自动恢复，会话状态不丢失，半开连接可检测。
**依赖**：阶段 3 通过
**参考设计**：补充文档 §4（连接管理）、§12（并发资源）、§14（心跳）

### 工作项

1. **重连状态恢复 + sync 续点**（补充文档 §4.1）
   - 重连后重新握手；app 发 sync(lastSeq)；gateway 补传离线事件
   - gateway 维护 per-session 离线事件缓冲（上限 500）
2. **握手状态重置**（补充文档 §4.4）
   - WebSocket close/error 时无条件 cleanupConnection() 重置 handshakeState
3. **心跳双层检测**（补充文档 §14）
   - 传输层 ping/pong（ws 库自动，15s/10s）
   - 应用层加密 heartbeat（30s 间隔，45s 超时触发重连）
   - 前后台心跳降频（前台 30s，后台 120s）
4. **SSE 订阅生命周期**（补充文档 §12.2）
   - 切换 session 时 abort 旧 SSE；活跃会话单订阅策略
5. **新连接踢旧连接**（补充文档 §12.4）
   - 直连/relay 两模式发送 CONFLICT/replaced 通知
   - app 收到后停止重连
6. **opencode 崩溃恢复**（补充文档 §12.3）
   - SSE 全断 → 探活 → 清空映射 → 推 OPENCODE_RESTARTED
7. **前后台生命周期**（补充文档 §4.2）
   - 后台降频、5 分钟断开、未决权限协调

### 验收门禁（必须全部通过）

- [ ] **V4.1** **断线重连恢复**：连接中手动 kill gateway → app 显示"未连接" → 重启 gateway → 自动重连 → 收到 sync 补传的离线消息（新增 TC-M12）
- [ ] **V4.2** **心跳超时**：gateway 停止响应 heartbeat → app 45s 后检测失联并重连（新增 TC-G11）
- [ ] **V4.3** **SSE 切换清理**：切换 session 时旧 SSE 连接被 abort（日志/计数验证，无连接泄漏）
- [ ] **V4.4** **踢连接**：同 token 第二个 app 连入 → 第一个 app 收到 CONFLICT 并停止重连（新增 TC-M16）
- [ ] **V4.5** **opencode 重启**：重启 mock-opencode → app 收到 OPENCODE_RESTARTED，会话重置（新增 TC-G09）
- [ ] **V4.6** **relay 重连**：kill relay → gateway 指数退避重连 → 恢复（新增 TC-G03）

**退出标准**：网络异常/服务重启场景下连接可恢复，状态不丢失，无连接泄漏。

---

## 阶段 5：功能完整（Markdown 离线 + 语音 + 审查 + 权限超时）

**目标**：补齐主文档所有承诺的核心功能，达到产品可用。
**依赖**：阶段 4 通过
**参考设计**：补充文档 §5.1、§5.6、§5.4；主文档功能列表

### 工作项

1. **Markdown 离线渲染**
   - 集成 `@luvi/lv-markdown-in` HAR 包到 `oh-package.json5`
   - MessageBubble 的 ReplyMessage 用 lv-markdown-in 替换手写 MarkdownText
   - 支持：标题、列表、表格、代码块、链接、加粗斜体
2. **Mermaid 离线**
   - mermaid.min.js 放入 `resources/rawfile/`
   - MermaidDiagram 改用 `resource://rawfile/mermaid.min.js`（去掉 CDN）
3. **语音输入（真实 ASR）**
   - VoiceService 调用鸿蒙 `@kit.CoreSpeechKit` 或等效 ASR API
   - 实现录音采集、识别回调、结果填入输入框
   - 运行时麦克风权限请求流程
4. **权限请求超时**（补充文档 §5.1）
   - app 端 60s 倒计时 + 自动拒绝；gateway 65s 兜底
   - 并发权限卡片堆叠（§12.5）+ requestId 去重（§15.6）
5. **审查页面**（补充文档 §5.4）
   - 整页跳转，原生渲染文件 diff（增删行高亮、文件状态标签、展开/折叠）
   - 无 WebView，无需白名单/cookie 隔离（若后续引入 WebView 再补）
6. **Session 列表浮层**（补充文档 §5.2）
   - 替换硬编码 5 个的 ActionMenu，改为滚动列表浮层，无上限

### 验收门禁（必须全部通过）

- [ ] **V5.1** **Markdown 渲染**：发送含标题/列表/表格/代码块的 Markdown → 全部正确渲染（标题加粗、列表缩进、代码高亮）（新增 TC-M01 完整版）
- [ ] **V5.2** **Mermaid 离线**：断网状态下发送含 Mermaid 图表 → 正常渲染为 SVG（新增 TC-M04）
- [ ] **V5.3** **语音输入**：按住录音 → 松开 → 真实识别结果填入输入框并发送（非硬编码字符串）（新增 TC-M04）
- [ ] **V5.4** **权限超时**：60s 不操作 → 自动拒绝 + 卡片标记；gateway 65s 兜底（app 离线时）（新增 TC-M05）
- [ ] **V5.5** **审查页面**：整页跳转，diff 列表正确渲染（文件状态、增删行高亮、展开/折叠）（新增 TC-M10）
- [ ] **V5.6** **并发权限**：同时 2 个权限请求 → 堆叠展示，各自独立倒计时（新增 TC-M15）

**退出标准**：主文档承诺的核心功能全部可用，离线渲染、语音、权限超时均正常。

---

## 阶段 6：加固（防重放 + 日志 + 错误码 + 集成测试套件）

**目标**：补齐健壮性、可观测性、安全加固，建立完整测试套件保障回归。
**依赖**：阶段 5 通过
**参考设计**：补充文档 §2.5、§6、§3、§13.2、§9

### 工作项

1. **防重放 seq**（补充文档 §2.5、§12.1）
   - 双向独立 seq 计数器；256 滑动窗口去重；回绕处理
   - 消息帧结构增加 seq 字段
2. **分片协议**（补充文档 §3.1）
   - gateway 抽共享 Chunker 模块；relay-client 补齐分片
   - chunk_resend 重传请求
3. **结构化日志**（补充文档 §6.2）
   - 封装共享 Logger 类（gateway/relay 复用），JSON 格式
   - DCODE_LOG_LEVEL 环境变量过滤
4. **错误码体系**（补充文档 §6.1、附录 B）
   - 所有 error 消息统一 {code, message, detail}
   - 补齐 OPENCODE_TIMEOUT/CONFLICT/SESSION_LIMIT 等
5. **Relay 准入认证**（补充文档 §13.2）
   - register 消息增加 relayKey；relay 校验；QR 透传
6. **App 端本地加密存储**（补充文档 §2.6）
   - token/publicKey 加密落库（HUKS/ArkData）
7. **集成测试套件**（补充文档 §9）
   - gateway 集成测试（direct+relay 完整流程）
   - E2E 脚本（hdc 驱动扫码→聊天→权限）
   - 补齐所有 TC-* 用例
8. **版本兼容校验**（补充文档 §7）
   - 握手交换版本，0.x 规则，不兼容拒绝

### 验收门禁（必须全部通过）

- [ ] **V6.1** **防重放**：重放相同 seq 消息 → 被丢弃 + 日志（新增测试）
- [ ] **V6.2** **分片 e2e**：发送 > 1MB 消息 → 直连与 relay 两种模式均正确分片重组（新增 TC-G07）
- [ ] **V6.3** **结构化日志**：gateway/relay 日志为 JSON 格式，含 ts/level/module/msg（新增测试）
- [ ] **V6.4** **错误码**：触发 INVALID_TOKEN/HANDSHAKE_FAILED/OPENCODE_TIMEOUT → 各收到对应 code
- [ ] **V6.5** **Relay 鉴权**：无 relayKey 注册 → 被拒（新增测试）
- [ ] **V6.6** **版本校验**：app 与 gateway 主版本不一致 → 握手拒绝
- [ ] **V6.7** **全量测试**：`cd gateway && npm test` + `cd relay && npm test` + `cd mock-opencode && npm test` 全绿，用例数 ≥ 40
- [ ] **V6.8** **E2E 脚本**：扫码→连接→聊天→权限→切换会话 全流程脚本化通过

**退出标准**：安全加固、可观测性、测试覆盖达到可发布质量。

---

## 跨阶段约定

| 约定 | 说明 |
|------|------|
| **每阶段必须先补该阶段的单元测试再开发** | 测试先行，验收时测试必须绿 |
| **每阶段产出需更新 IMPLEMENTATION_STATUS.md** | 标注实际完成项，纠正历史失真记录 |
| **禁止跨阶段并行** | 上阶段未验收禁动下阶段代码 |
| **验收阻塞时** | 记录阻塞项，修复后重新跑全部验收项（非增量） |
| **提交规范** | 每阶段一个 feat/* 分支，验收通过后合并 master |

## 工作量预估（参考）

| 阶段 | 核心工作 | 相对工作量 |
|------|----------|-----------|
| 1 基础契约 | gateway 链路修复 + mock 重写 | 中 |
| 2 安全协议 | app 加密栈从零搭建 | **大**（app 侧主债） |
| 3 核心消息流 | 流式 + 引导 + 历史 | 中 |
| 4 连接韧性 | 重连 + sync + 心跳 | 中 |
| 5 功能完整 | Markdown/语音/审查 | 中（含三方集成） |
| 6 加固 | seq + 分片 + 日志 + 测试套件 | 中 |

> 阶段 2 工作量最大（app 加密从零），是关键路径瓶颈。

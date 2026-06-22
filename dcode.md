
## 项目目标
实现鸿蒙手机端连接到电脑上opencode，支持扫码功能；
- app与电脑两种连接方式：直连和云转发；
- 端到端数据加密传输；
- 通过手机扫码建立连接，连接可在手机端保存；
- 云转发时，有一个可独立部署的relay服务器程序；
- 语音输入和手机键盘输入两种输入；
- markdown渲染，支持Mermaid预览
- 与opencode通信，能实时看到opencode的思考过程，工具调用过程；
- 能解析opencode权限请求，弹出窗口和按钮供用户选择；
- 支持opencode session新建，查看，和切换；
- 支持opencode server的审查页面，支持提交文件的diff查看
- 支持连接鸿蒙远程模拟器，展示模拟器界面，支持模拟器基本操作，查看模拟器的设备类型，启动等。
- 支持查看当前会话token消耗
- 支持推包到本机验证

## 架构设计
### 总体架构
电脑端使用opencode为server，opencode serve方式运行，通过gateway转发给手机端或中继服务器。 
手机端使用微信UX交互风格，使用华为鸿蒙设计语言，尽可能简洁，主界面为跟agent聊天界面。通过该界面实现指挥电脑端opencode工作。
支持直连和云转发两种方式
- 直连方式：电脑（opencode + gateway）--- 手机（dcode app）
- 云转发：电脑（opencode + gateway）---relay server --- 手机（dcode app）
通过手机扫码电脑上gateway的二维码实现默认连接
https端到端加密
gateway和relay server是用nodejs实现
手机端鸿蒙原生ArkTS语言实现

## 详细功能(微信UX风格版)
### 页面结构
页面/浮层 | 路径/入口 | 核心职责 |
|--------|-----------|----------|
|连接列表页 | 首页 | 已保存连接列表，扫码/手动添加入口，状态圆点，长按/左滑操作 |
|主会话页 | 点击连接进入 | 显示大头贴，整合 Session 切换、Token 查看、权限处理、输入/语音 |
|审查页面 | 主会话页菜单 | 整页跳转，加载 opencode 审查页面，支持文件 diff 查看 |
| 扫码全屏视图 | 首页“+”或空状态按钮 | 全屏扫描二维码，自动解析连接信息 |
| Session 切换浮层 | 点击标题栏 Session 名 | 下拉显示 Session 列表，底部“+新建会话”|
| Token 详情浮层 | 点击标题栏 Token 胶囊 | 展示当前会话 Token 消耗、上下文窗口占比 |

### 关键交互流程
#### 扫码连接
- 首页图标“扫一扫”→ 全屏扫描视图识别二维码 → 解析 JSON (模式、地址、公钥、token) → 弹出底部动作面板：
- 显示电脑名称、模式、地址掩码、公钥指纹
- 按钮: [连接并保存] [仅连接一次]
- 执行 WebSocket 连接 → ECDH 握手 → 成功后保存（可选）并跳转主会话页。
#### 主会话页布局
- 导航栏: 返回按钮 + Session 名（可点击切换）+ Token 胶囊 ● 1.2k/4k（可点击查看详情）
#### 消息列表:
- 用户输入: 右对齐绿色气泡
- Opencode 思考过程：左对齐色块折叠文字，点击展开
- 工具调用：左对齐卡片（工具名、参数摘要、结果）
- 最终回复：白底气泡，Markdown 渲染（含 Mermaid 图表）
- 权限请求：内嵌为特殊卡片，直接提供“允许”“拒绝”按钮
- 输入栏：语音按钮（按住说话）+ 文本输入框 + 发送按钮
#### Session 管理
- 点击标题栏 Session 名 → 浮层列表，点击切换；底部“+ 新建会话”
- 新建后消息区重置，旧会话保存历史（可回溯）
#### 审查页面
- 从主会话右上角菜单进入 → 整页跳转至审查页面，有返回按钮。
### 连接管理
- 列表项左滑删除，长按重命名或查看详情（地址、公钥指纹）
- 手动添加：表单浮层（连接名称、模式、地址、Token）

## Gateway 详细设计（Node.js，双模式）
- 模块架构
- 配置管理
- 加密模块（ECDH + AES-256-GCM）
- 连接管理器（直连服务器 / Relay 客户端）
- Opencode HTTP 客户端（Session 管理、消息路由）
- 二维码生成器（qrcode-terminal + 可选 HTTP 页面）
- 直连模式
1. 启动 WebSocket Server（端口可配）
2. 生成 ECDH 密钥对，构造连接信息 JSON（见补充设计决策）
3. 等待 App 连接，执行三步握手（见补充设计决策）
4. 后续消息加密传输，解密后转发至 Opencode，将输出封装为相应类型的消息加密返回
- 云转发模式
1. 主动连接 Relay Server WebSocket，发送注册消息（token、公钥）
2. 等待 Relay 通知配对完成
3. 通过 Relay 客户端收发加密密文，内部处理逻辑与直连一致
4. 支持断线自动重连 Relay，重连后重新注册
- Opencode 集成
- 每个 App 连接维护一个或多个 Opencode HTTP Session 连接（根据 Session 数量）
- 解析 Opencode 输出，提取思考步骤、工具调用、权限请求、最终回复
- 权限请求封装为 “permissionrequest” 消息，接收 “permissionreply” 传回

## Relay Server 简述
- 轻量级 Node.js WebSocket 服务
- 配对逻辑: 根据 token 关联同一个用户的电脑 (gateway) 和手机 (App)
- 透明转发二进制帧，不参与加密
- 心跳检测，超时清理闲置连接
## 测试用例总结
### 连接建立
| ID | 模式 | 场景 | 预期结果 |
|----|------|------|----------|
| TC-C01 | 直连 | 扫码连接并保存 | 连接列表新增，加密握手成功，进入主会话页 |
| TC-C02 | 云转发 | 扫码连接并保存 | 同上，数据经由 Relay 加密转发 |
| TC-C03 | 通用 | 扫码已存在的连接 | 提示“已存在连接，是否打开？”，可覆盖更新 |
| TC-C04 | 通用 | 手动输入地址+token 连接 | 成功建立连接，或明确提示错误（地址不可达/Token 无效）|
| TC-C05 | 通用 | 错误 Token 握手 | 底部面板显示“连接失败：Token 无效”，不保存 |
### 主会话页功能
| ID | 场景 | 预期 |
|----|------|------|
| TC-M01 | 发送文本，收到 Markdown 回复（含 Mermaid）| 用户气泡与白底回复气泡正确渲染，Mermaid 图表正常显示 |
| TC-M02 | 思考过程流式显示 | 灰色折叠区域实时更新，点击可展开 |
| TC-M03 | 工具调用卡片展示 | 显示工具名、参数、执行结果 |
| TC-M04 | 语音输入 | 按住录音，松开后发送，识别结果填入并发送 |
| TC-M05 | 权限请求内嵌卡片 | 卡片显示请求描述，“允许”/“拒绝”按钮点击后生效 |
| TC-M06 | 点击 Session 名切换 | 下拉列表显示当前会话，切换后消息区加载对应历史 |
| TC-M07 | 新建 Session | 浮层底部“+新建会话”，创建后列表更新，消息区空白 |
| TC-M08 | 点击 Token 设置 | 浮层展示当前消耗、输入/输出 token 数、窗口占比 |
| TC-M09 | 网络中断后重连 | 自动重连，加密通道恢复，状态保持 |
| TC-M10 | 审查页面 | 整页加载审查页，diff 正常显示，返回手势正常 |
### Gateway 与 Relay
| ID | 场景 | 预期 |
|----|------|------|
| TC-G01 | 正常模式握手 | 密钥协商成功，后续消息加解密正确 |
| TC-G02 | 云转发模式通过 Relay 传输 | Relay 不解密，App 与 Gateway 端到端加密 |
| TC-G03 | Relay 断线重连 | Gateway 自动重连，App 连接恢复 |
| TC-G04 | 多 Session 并发 | 多个 Opencode 进程隔离，资源独立 |

## 补充设计决策

### 架构层

- **Opencode 通信协议**：Gateway 通过 HTTP/SSE 与 opencode 通信。Gateway 作为 HTTP 客户端连接已运行的 opencode serve 进程，通过 SSE 事件流接收实时输出（思考过程、工具调用、权限请求、最终回复等）
- **端到端加密曲线**：使用 X25519 ECDH 曲线，密钥 32 字节。QR 码中携带 X25519 公钥（Base64 编码），握手后使用 ECDH 共享密钥派生 AES-256-GCM 会话密钥
- **中间人防护策略**：信任扫码物理通道的安全性，不在软件层额外验证公钥
- **WebSocket 消息帧格式**：所有消息使用 JSON 文本帧，统一 {type, data} 结构。消息类型包括：user_message、thinking、tool_call、permission_request、permission_reply、reply、session_list、session_switch、token_info、error
- **QR 码 JSON 完整结构**：{"mode":"direct"|"relay", "name":"电脑名", "host":"192.168.x.x", "port":8765, "publicKey":"base64...", "token":"uuid", "relayUrl":"wss://..."（仅 relay 模式）}
- **ECDH 握手时序**：三步握手——App 发送 AppPublicKey + Nonce → Gateway 回复 ACK + Nonce → 双方用 ECDH 派生 AES-256-GCM 会话密钥，后续消息加密传输
- **Relay 地址来源**：QR 码 JSON 的 relayUrl 字段携带，Gateway 配置文件中指定 Relay 地址
- **Opencode 集成方式**：纯 HTTP 客户端连接，非子进程管理。opencode 作为独立服务部署，Gateway 只做协议转换
- **Opencode 认证方式**：opencode serve 运行在 localhost，Gateway 信任本地网络不做额外认证
- **版本兼容性**：App 和 Gateway 在握手时交换版本号，版本不匹配时提示用户升级

### 数据与状态层

- **连接 Token 来源**：Gateway 启动时一次性生成 token，显示在 QR 码中。Gateway 重启后重新生成
- **手机端数据存储**：使用鸿蒙 Preferences API 存储连接信息（连接名称、模式、地址、X25519 公钥、token）
- **会话历史存储位置**：opencode 侧存储会话历史，Gateway 和 App 仅做转发和展示，保持数据单一来源
- **多 App 并发**：单 App 连接模式，新连接会踢掉旧连接
- **Session 生命周期**：用户主动关闭或删除 Session，opencode 侧统一管理。App 关闭后 Session 保留在 opencode 侧，重新打开后可恢复
- **消息幂等性**：每条消息携带唯一 UUID，重连后通过消息 ID 去重，避免重复显示
- **消息大小限制**：单条 WebSocket 消息最大 1MB，超限时分片发送

- **App 语言与 API 版本**：App 使用 ArkTS 原生语言开发，目标 API 版本 6.1 及以上

### 功能层

- **语音识别方案**：使用鸿蒙端侧 ASR 能力，调用系统内置语音识别 API，无需外部服务依赖
- **审查页面 URL 来源**：opencode 提供审查页面 URL，Gateway 透传给 App
- **鸿蒙远程模拟器**：功能 TBD，后续单独设计
- **推包到本机验证**：功能 TBD，后续单独设计
- **Markdown 渲染**：使用 luvi/lv-markdown-in 组件渲染 Markdown
- **Mermaid 渲染**：WebView 兜底渲染，本地打包 mermaid.js 资源，离线可用
- **权限请求超时**：60s 超时自动拒绝并记录日志
- **深色模式**：仅支持浅色模式
- **App 权限声明**：基础权限集——网络访问（INTERNET）、摄像头（扫码）、麦克风（语音）、状态栏通知（连接状态）
- **"大头贴"含义**：主会话页导航栏显示的用户头像/连接标识，用于快速识别当前连接

### 运维与工程层

- **连接状态检测**：利用 WebSocket 协议内置的 ping/pong 帧检测连接存活，App 端定期心跳确认在线状态
- **重连策略**：断线后使用指数退避算法重连（1s→2s→4s→8s...），最大间隔 30s，最多重试 10 次后停止
- **配置管理**：Gateway 使用 JSON 配置文件，支持命令行参数覆盖默认值，配置文件路径通过环境变量指定
- **错误处理**：所有错误统一显示用户友好的提示消息，同时在控制台输出详细技术信息供调试
- **日志**：Gateway 和 App 都记录结构化日志（JSON 格式），包含时间戳、日志级别、模块名、消息内容
- **安全措施**：Relay 服务器实施速率限制防止滥用，连接失败时记录日志并告警

### 开发环境

- **本地开发环境**：提供 docker-compose 文件，一键启动 Gateway + Relay + 模拟 opencode 的本地开发环境
- **测试策略**：单元测试覆盖核心模块，集成测试验证 App-Gateway-Relay 通信，端到端测试验证完整用户流程

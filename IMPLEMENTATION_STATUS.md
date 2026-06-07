# DCode 项目实现状态报告

## 项目概述
DCode 是一个鸿蒙移动应用，用于连接桌面端运行的 opencode（AI 编程助手）。项目包含三个主要组件：
- **Gateway** (Node.js): 桌面端网关服务
- **Relay** (Node.js): 云转发中继服务器
- **App** (HarmonyOS ArkTS): 移动客户端应用

## 已完成的功能

### ? Gateway (Node.js 网关)
- [x] WebSocket 服务器（直连模式）
- [x] WebSocket 客户端（中继模式）
- [x] ECDH 加密模块（X25519 密钥交换 + AES-256-GCM 加密）
- [x] Opencode HTTP/SSE 集成
- [x] 会话管理器
- [x] QR 码生成（终端显示）
- [x] 消息分片处理（大消息支持）
- [x] 配置管理（环境变量、命令行参数、配置文件）
- [x] 单元测试（14/14 通过）
- [x] ESM 模块系统支持
- [x] qrcode-terminal 依赖

### ? Relay (Node.js 中继服务器)
- [x] WebSocket 服务器
- [x] Token 配对机制
- [x] 消息透明转发
- [x] 心跳检测
- [x] 速率限制（100 消息/分钟）
- [x] 自动会话清理
- [x] 导出类（供测试使用）
- [x] Vitest 配置

### ? App (HarmonyOS ArkTS 应用)

#### 页面
- [x] **Index.ets** - 入口页面，重定向到连接列表
- [x] **ConnectionListPage.ets** - 连接列表页面
  - 显示已保存的连接
  - 扫码按钮
  - 手动添加按钮
- [x] **QRScannerPage.ets** - 二维码扫描页面
  - 使用 HarmonyOS ScanKit
  - 解析 QR 码数据
  - 显示连接信息
  - 保存/连接选项
- [x] **ManualConnectionPage.ets** - 手动添加连接
  - 连接名称
  - 模式选择（直连/中继）
  - 主机地址和端口
  - 中继 URL（中继模式）
  - 公钥和 Token
- [x] **ChatPage.ets** - 主聊天界面
  - 消息列表显示
  - 文本输入和发送
  - 语音输入按钮（已实现 UI，功能待集成）
  - 会话切换下拉菜单
  - Token 使用情况显示
  - 权限请求处理
- [x] **ReviewPage.ets** - 代码审查页面
  - WebView 显示
  - 加载进度条
  - 刷新按钮

#### 组件
- [x] **ConnectionListItem.ets** - 连接列表项
  - 显示连接信息
  - 在线状态指示器
  - 删除按钮
- [x] **MessageBubble.ets** - 消息气泡
  - 用户消息（绿色气泡）
  - AI 回复（白色气泡）
  - 思考过程（可折叠）
  - 工具调用（工具卡片）
  - 权限请求（批准/拒绝按钮）
  - 错误消息
  - 权限回复通过 WebSocket 发送

#### 服务
- [x] **WebSocketService.ets** - WebSocket 服务
  - 连接管理（直连和中继模式）
  - ECDH 握手（三步握手）
  - X25519 密钥生成
  - AES-256-GCM 加密/解密
  - 消息发送/接收
  - 自动重连（指数退避）
- [x] **ConnectionService.ets** - 连接管理服务
  - 保存连接信息
  - 加载连接列表
  - 更新连接状态
  - 删除连接
  - 使用 Preferences API 持久化

#### 入口
- [x] **EntryAbility.ets** - 应用入口
  - 初始化 ConnectionService
  - 加载主页面

### ? 开发环境
- [x] docker-compose.yml（容器化部署）
- [x] Mock Opencode 服务器（测试用）
- [x] Dockerfile（Gateway、Relay、Mock）
- [x] gateway.config.example.json（配置示例）
- [x] README.md（完整文档）

## 待完善功能

### ?? App 功能
- [ ] Markdown 渲染库集成（lv-markdown-in）
  - 当前：使用纯文本显示
  - 需要：安装 lv-markdown-in HAR 包并更新 MessageBubble.ets
- [ ] Mermaid 图表渲染
  - 需要：在 ReviewPage 或 ChatPage 中集成 Mermaid.js
- [ ] 语音输入（HarmonyOS ASR）
  - 当前：UI 已实现，功能显示 Toast 提示
  - 需要：集成 HarmonyOS 语音识别 API
- [ ] Markdown 消息渲染
  - 当前：ReplyMessage 使用 Text 组件
  - 需要：使用 lv-markdown-in 组件替换

### ?? 测试
- [ ] Relay 集成测试（当前超时，需要调试）
- [ ] App 单元测试
- [ ] E2E 测试（扫码 → 连接 → 聊天 → 权限处理）

## 测试指南

### 1. 启动开发环境

#### 方式 A：使用 Docker Compose（推荐）
```bash
docker-compose up -d
```
这将启动：
- Mock opencode 服务器（端口 3000）
- Relay 服务器（端口 8766）
- Gateway（端口 8765）

#### 方式 B：手动启动
```bash
# 终端 1：启动 Mock Opencode
cd mock-opencode
npm install
npm run dev

# 终端 2：启动 Relay（可选）
cd relay
npm install
npm run dev

# 终端 3：启动 Gateway
cd gateway
npm install
npm run dev
```

### 2. 构建和运行 App

1. 使用 DevEco Studio 打开 `app/` 目录
2. 等待依赖安装完成
3. 配置模拟器或连接真机
4. 点击运行按钮

### 3. 测试连接流程

#### 直连模式测试
1. 确保 Gateway 正在运行
2. 在 App 中点击"扫一扫"
3. 扫描 Gateway 终端显示的二维码
4. 选择"连接并保存"或"仅连接一次"
5. 验证连接状态指示器变为绿色

#### 中继模式测试
1. 确保 Relay 和 Gateway 都在运行
2. 修改 Gateway 配置：`"mode": "relay"`
3. 重启 Gateway
4. 在 App 中扫描新的二维码
5. 验证通过中继服务器连接成功

### 4. 测试聊天功能

1. 在 ChatPage 中输入消息并发送
2. 观察消息气泡显示（用户消息为绿色）
3. 等待 Mock 服务器响应
4. 验证以下消息类型：
   - 思考过程（可折叠展开）
   - 工具调用（工具卡片）
   - AI 回复（白色气泡）
   - Token 使用情况更新

### 5. 测试会话管理

1. 点击会话下拉菜单
2. 创建新会话
3. 切换不同会话
4. 验证消息隔离正确

### 6. 测试权限请求

1. Mock 服务器会自动发送权限请求
2. 验证权限请求卡片显示
3. 点击"允许"或"拒绝"按钮
4. 检查 Gateway 日志确认权限回复已发送

### 7. 测试连接管理

1. 返回 ConnectionListPage
2. 验证新保存的连接显示
3. 点击连接进入聊天页面
4. 左滑删除连接
5. 验证删除成功

## 已知问题

1. **Markdown 渲染**：当前使用纯文本，需要集成 lv-markdown-in
2. **语音输入**：UI 已实现，功能未集成
3. **Relay 测试超时**：需要调试测试环境
4. **Mermaid 图表**：未实现，需要在 WebView 中集成

## 下一步行动

### 立即执行
1. ? 在模拟器中运行 App
2. ? 测试直连模式连接
3. ? 测试基本聊天功能
4. ? 验证权限请求处理

### 短期优化
1. 集成 lv-markdown-in 库实现 Markdown 渲染
2. 实现语音输入功能
3. 修复 Relay 测试超时问题
4. 添加 Mermaid 图表支持

### 长期规划
1. 添加推送通知支持
2. 实现离线模式
3. 多语言支持
4. 深色模式
5. 远程模拟器支持

## 技术栈

- **App**: HarmonyOS ArkTS (API 6.1+)
- **Gateway/Relay**: Node.js + TypeScript
- **加密**: X25519 ECDH + AES-256-GCM
- **通信**: WebSocket + HTTP/SSE
- **测试**: Vitest
- **容器**: Docker + Docker Compose

## 联系方式

如有问题或建议，请通过项目仓库提交 Issue。

---

**最后更新**: 2026-06-07
**版本**: 0.1.0

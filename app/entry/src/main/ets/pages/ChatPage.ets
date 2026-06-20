import { Connection, Message, Session, QRCodeData, MessageData } from '../models/index';
import { connectionService } from '../services/ConnectionService';
import { webSocketService } from '../services/WebSocketService';
import { voiceService } from '../services/VoiceService';
import { MessageBubble } from '../components/MessageBubble';
import router from '@ohos.router';
import { promptAction, KeyboardAvoidMode } from '@kit.ArkUI';

interface ChatPageParams {
  connectionId?: string;
  qrData?: string;
}

@Entry
@Component
struct ChatPage {
  @State messages: Message[] = [];
  @State inputText: string = '';
  @State currentSession: Session | null = null;
  @State sessions: Session[] = [];
  @State isConnected: boolean = false;
  @State tokenTotal: number = 0;
  @State tokenLimit: number = 4096;
  @State isRecording: boolean = false;
  @State reviewUrl: string = '';
  @State loadingHistory: boolean = false;
  @State pendingMessageIds: Set<string> = new Set();

  private connection: Connection | null = null;
  private scroller: Scroller = new Scroller();
  private wsListenersRegistered: boolean = false;

  aboutToAppear() {
    const params = router.getParams() as ChatPageParams;

    if (params?.connectionId) {
      this.connection = connectionService.get(params.connectionId) || null;
    } else if (params?.qrData) {
      try {
        const qrData: QRCodeData = JSON.parse(params.qrData) as QRCodeData;
        this.connection = {
          id: `emp_${Date.now()}`,
          name: qrData.name,
          mode: qrData.mode,
          host: qrData.host,
          port: qrData.port,
          publicKey: qrData.publicKey,
          token: qrData.token,
          relayUrl: qrData.relayUrl,
          isOnline: false
        };
      } catch (e) {
        console.error('[ChatPage] Parse QR data error:', e);
      }
    }

    this.setKeyboardAvoidMode();
    this.setupWebSocket();
    this.setupVoiceInput();
  }

  private setKeyboardAvoidMode() {
    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    } catch (e) {
      console.error('[ChatPage] setKeyboardAvoidMode error:', e);
    }
  }

  setupWebSocket() {
    if (!this.connection) return;

    const qrData: QRCodeData = {
      mode: this.connection.mode,
      name: this.connection.name,
      host: '10.0.2.2',
      port: this.connection.port,
      publicKey: this.connection.publicKey,
      token: this.connection.token,
      relayUrl: this.connection.relayUrl
    };

    if (!this.wsListenersRegistered) {
      webSocketService.onConnectionChange((connected: boolean) => {
        this.isConnected = connected;
        if (connected && this.connection) {
          connectionService.updateOnlineStatus(this.connection.id, true);
        }
      });

      webSocketService.onMessage((message: Message) => {
        this.handleIncomingMessage(message);
      });
      this.wsListenersRegistered = true;
    }

    webSocketService.connect(qrData);
  }

  setupVoiceInput() {
    voiceService.onResult((text: string) => {
      this.inputText = text;
      this.isRecording = false;
    });
  }

  handleIncomingMessage(message: Message) {
    switch (message.type) {
      case 'session_list': {
        const sessions: Session[] = message.data.sessions || [];
        this.sessions = sessions;
        if (sessions.length > 0 && !this.currentSession) {
          this.currentSession = sessions[0];
        }
        break;
      }
      case 'session_switch': {
        this.currentSession = {
          id: message.data.sessionId || '',
          name: message.data.name || '',
          createdAt: Date.now(),
          lastActivity: Date.now()
        };
        break;
      }
      case 'history': {
        this.loadingHistory = false;
        const historyMessages = message.data.messages || [];
        const mapped = historyMessages.map((m: object) => this.mapHistoryMessage(m));
        const existingIds = new Set<string>();
        this.messages.forEach((m: Message) => existingIds.add(m.id));
        for (const msg of mapped) {
          if (!existingIds.has(msg.id)) {
            this.messages.push(msg);
          }
        }
        this.scrollToBottom();
        break;
      }
      case 'token_info': {
        this.tokenTotal = message.data.total || 0;
        this.tokenLimit = message.data.contextWindow || 4096;
        break;
      }
      case 'review_url': {
        this.reviewUrl = message.data.url || '';
        break;
      }
      case 'message_ack': {
        const msgId = message.data.id;
        if (msgId) {
          this.pendingMessageIds.delete(msgId);
        }
        break;
      }
      case 'error': {
        const code = message.data.code || '';
        const msg = message.data.message || '未知错误';
        console.error('[ChatPage] Error:', code, msg);
        promptAction.showToast({ message: msg });
        break;
      }
      case 'thinking':
      case 'reply':
      case 'tool_call':
      case 'permission_request':
      default: {
        this.handleStreamMessage(message);
        this.scrollToBottom();
        break;
      }
    }
  }

  private handleStreamMessage(message: Message) {
    const stream = message.stream;
    if (stream === 'append') {
      const existing = this.messages.findIndex((m: Message) => m.id === message.id);
      if (existing >= 0) {
        const old = this.messages[existing];
        const newData: MessageData = {
          content: (old.data.content || '') + (message.data.content || '')
        };
        const updated: Message = {
          type: old.type,
          id: old.id,
          seq: old.seq,
          stream: old.stream,
          data: newData,
          timestamp: old.timestamp
        };
        this.messages.splice(existing, 1, updated);
      } else {
        this.messages.push(message);
      }
      return;
    }

    if (stream === 'replace') {
      const existing = this.messages.findIndex((m: Message) => m.id === message.id);
      if (existing >= 0) {
        this.messages.splice(existing, 1, message);
      } else {
        this.messages.push(message);
      }
      return;
    }

    if (stream === 'end' || stream === 'aborted') {
      const existing = this.messages.findIndex((m: Message) => m.id === message.id);
      if (existing >= 0) {
        this.messages.splice(existing, 1, message);
      } else {
        this.messages.push(message);
      }
      return;
    }

    this.messages.push(message);
  }

  private scrollToBottom() {
    setTimeout(() => {
      if (this.scroller) {
        this.scroller.scrollEdge(Edge.Bottom);
      }
    }, 50);
  }

  private mapHistoryMessage(m: object): Message {
    const msg = m as Record<string, Object>;
    const info = (msg['info'] || {}) as Record<string, Object>;
    const parts = (msg['parts'] || []) as Object[];
    const role = (info['role'] as string) || 'user';

    let content = '';
    for (const p of parts) {
      const part = p as Record<string, Object>;
      if (part['type'] === 'text') {
        content = (part['text'] as string) || '';
        break;
      }
    }

    const timeObj = (info['time'] || {}) as Record<string, number>;
    return {
      type: role === 'assistant' ? 'reply' : 'user_message',
      id: (info['id'] as string) || `hist_${Date.now()}_${Math.random()}`,
      data: { content },
      timestamp: timeObj['created'] || Date.now()
    };
  }

  sendMessage() {
    if (!this.inputText.trim()) return;

    const data: MessageData = { content: this.inputText };
    const message: Message = {
      type: 'user_message',
      id: `msg_${Date.now()}`,
      data: data,
      timestamp: Date.now()
    };

    this.pendingMessageIds.add(message.id);
    webSocketService.sendMessage(message);
    this.messages.push(message);
    this.inputText = '';
    this.scrollToBottom();
  }

  createSession() {
    const data: MessageData = {};
    const message: Message = {
      type: 'session_create',
      id: `msg_${Date.now()}`,
      data: data,
      timestamp: Date.now()
    };

    webSocketService.sendMessage(message);
  }

  switchSession(sessionId: string) {
    this.messages = [];
    this.loadingHistory = true;

    const data: MessageData = { sessionId };
    const message: Message = {
      type: 'session_switch',
      id: `msg_${Date.now()}`,
      data: data,
      timestamp: Date.now()
    };

    webSocketService.sendMessage(message);
  }

  openReviewPage() {
    if (this.reviewUrl) {
      router.pushUrl({
        url: 'pages/ReviewPage',
        params: { url: this.reviewUrl, title: 'Code Review' }
      });
    } else {
      promptAction.showToast({ message: '暂无审查页面' });
    }
  }

  async toggleVoiceInput() {
    try {
      if (this.isRecording) {
        await voiceService.stopRecording();
      } else {
        this.isRecording = true;
        await voiceService.startRecording();
      }
    } catch (error) {
      console.error('[ChatPage] Voice input error:', error);
      this.isRecording = false;
    }
  }

  private get tokenUsageText(): string {
    const totalK = Math.round(this.tokenTotal / 1000 * 10) / 10;
    const limitK = Math.round(this.tokenLimit / 1000 * 10) / 10;
    return `${totalK}k/${limitK}k`;
  }

  @Builder
  TitleBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Text('\u2190')
          .fontSize(20)
      }
      .width(40)
      .height(40)
      .onClick(() => {
        webSocketService.disconnect();
        router.back();
      })

      Column() {
        Text(this.currentSession?.name || '加载中...')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .onClick(() => {
            this.showSessionSwitcher();
          })

        Row() {
          Circle({ width: 8, height: 8 })
            .fill(this.isConnected ? '#52c41a' : '#ff4d4f')
            .margin({ right: 4 })

          Text(this.isConnected ? '已连接' : '未连接')
            .fontSize(11)
            .fontColor('#999999')
        }
        .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      Text(this.tokenUsageText)
        .fontSize(12)
        .fontColor(this.tokenTotal > this.tokenLimit * 0.8 ? '#ff4d4f' : '#52c41a')
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(12)
        .backgroundColor('#f6ffed')

      Button({ type: ButtonType.Normal }) {
        Text('\u22ee')
          .fontSize(20)
      }
      .width(40)
      .height(40)
      .onClick(() => {
        this.showMenu();
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: 12, right: 12 })
    .backgroundColor('#ffffff')
  }

  @Builder
  ChatArea() {
    if (this.loadingHistory) {
      Column() {
        LoadingProgress()
          .width(32)
          .height(32)
          .color('#999999')
        Text('加载历史消息...')
          .fontSize(13)
          .fontColor('#999999')
          .margin({ top: 8 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ scroller: this.scroller }) {
        ForEach(this.messages, (message: Message) => {
          ListItem() {
            MessageBubble({ message: message })
          }
        }, (message: Message) => message.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
  }

  @Builder
  InputBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Text(this.isRecording ? '\u23f9' : '\ud83c\udf99')
          .fontSize(20)
      }
      .width(40)
      .height(40)
      .backgroundColor(this.isRecording ? '#ff4d4f' : '#f0f0f0')
      .onClick(() => {
        this.toggleVoiceInput();
      })

      TextInput({ text: this.inputText, placeholder: '输入消息...' })
        .layoutWeight(1)
        .margin({ left: 8, right: 8 })
        .height(40)
        .borderRadius(20)
        .backgroundColor('#f5f5f5')
        .onChange((value: string) => {
          this.inputText = value;
        })
        .onSubmit(() => {
          this.sendMessage();
        })

      Button('发送')
        .height(40)
        .fontSize(14)
        .onClick(() => {
          this.sendMessage();
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor('#ffffff')
  }

  build() {
    Column() {
      this.TitleBar()
      this.ChatArea()
      this.InputBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#ededed')
  }

  showSessionSwitcher() {
    const count = Math.min(this.sessions.length, 5);
    const buttons: promptAction.Button[] = [];
    for (let i = 0; i < count; i++) {
      buttons.push({ text: this.sessions[i].name, color: '#000000' });
    }
    buttons.push({ text: '+ 新建会话', color: '#52c41a' });

    const b1 = buttons[0];
    const b2 = buttons.length > 1 ? buttons[1] : undefined;
    const b3 = buttons.length > 2 ? buttons[2] : undefined;
    const b4 = buttons.length > 3 ? buttons[3] : undefined;
    const b5 = buttons.length > 4 ? buttons[4] : undefined;
    const b6 = buttons.length > 5 ? buttons[5] : undefined;

    promptAction.showActionMenu({
      title: '切换会话',
      buttons: [b1, b2, b3, b4, b5, b6] as [promptAction.Button, promptAction.Button?, promptAction.Button?, promptAction.Button?, promptAction.Button?, promptAction.Button?]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (result.index === count) {
        this.createSession();
      } else if (result.index < count) {
        this.switchSession(this.sessions[result.index].id);
      }
    });
  }

  showMenu() {
    promptAction.showActionMenu({
      title: '菜单',
      buttons: [
        { text: '代码审查', color: '#000000' },
        { text: '新建会话', color: '#52c41a' }
      ] as [promptAction.Button, promptAction.Button, promptAction.Button?, promptAction.Button?, promptAction.Button?, promptAction.Button?]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (result.index === 0) {
        this.openReviewPage();
      } else if (result.index === 1) {
        this.createSession();
      }
    });
  }

  aboutToDisappear() {
    if (this.connection) {
      connectionService.updateOnlineStatus(this.connection.id, false);
    }
  }
}

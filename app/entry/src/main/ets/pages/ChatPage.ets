import { Connection, Message, Session, QRCodeData, MessageData, ToolCallItem } from '../models/index';
import { connectionService } from '../services/ConnectionService';
import { webSocketService } from '../services/WebSocketService';
import { voiceService } from '../services/VoiceService';
import { MessageBubble } from '../components/MessageBubble';
import { SessionListSheet } from '../components/SessionListSheet';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { WX } from '../theme/WXTheme';

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
  @State showSessionSheet: boolean = false;

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

    this.setupWebSocket();
    this.setupVoiceInput();
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
          const existing = connectionService.get(this.connection.id);
          if (existing) {
            connectionService.updateOnlineStatus(this.connection.id, true);
          } else {
            this.connection.isOnline = true;
            this.connection.lastConnected = Date.now();
            connectionService.add(this.connection);
          }
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
        const rawSessions = message.data.sessions || [];
        const sessions: Session[] = rawSessions.map((s: object) => {
          const r = s as Record<string, Object>;
          return {
            id: (r['id'] as string) || '',
            name: (r['name'] as string) || '',
            createdAt: (r['createdAt'] as number) || 0,
            lastActivity: (r['lastActivity'] as number) || 0,
            isActive: (r['isActive'] as boolean) || false
          } as Session;
        });
        this.sessions = sessions;
        if (sessions.length > 0) {
          const active = sessions.find(s => s.isActive);
          if (active) {
            this.currentSession = active;
          } else if (!this.currentSession) {
            this.currentSession = sessions[0];
          }
        }
        break;
      }
      case 'session_switch': {
        this.currentSession = {
          id: message.data.sessionId || '',
          name: message.data.name || '',
          createdAt: message.data.createdAt || Date.now(),
          lastActivity: message.data.lastActivity || Date.now(),
          isActive: true
        };
        const sid = message.data.sessionId;
        if (sid) {
          const arr: Session[] = [];
          for (const s of this.sessions) {
            arr.push({
              id: s.id,
              name: s.name,
              createdAt: s.createdAt,
              lastActivity: s.lastActivity,
              isActive: s.id === sid
            });
          }
          this.sessions = arr;
        }
        break;
      }
      case 'history': {
        this.loadingHistory = false;
        const historyMessages = message.data.messages || [];
        this.messages = this.messages.filter((m: Message) => {
          const s = m.stream;
          return s === undefined || s === null || s === 'end' || s === 'aborted';
        });
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
        const arr = [...this.messages];
        arr[existing] = updated;
        this.messages = arr;
      } else {
        this.messages = [...this.messages, message];
      }
      return;
    }

    if (stream === 'replace') {
      const existing = this.messages.findIndex((m: Message) => m.id === message.id);
      if (existing >= 0) {
        const arr = [...this.messages];
        arr[existing] = message;
        this.messages = arr;
      } else {
        this.messages = [...this.messages, message];
      }
      return;
    }

    if (stream === 'end' || stream === 'aborted') {
      const existing = this.messages.findIndex((m: Message) => m.id === message.id);
      if (existing >= 0) {
        const old = this.messages[existing];
        const newContent = message.data.content || old.data.content || '';
        const updated: Message = {
          type: old.type,
          id: old.id,
          seq: old.seq,
          stream: stream,
          data: old.type === 'tool_call'
            ? message.data
            : { content: newContent },
          timestamp: old.timestamp
        };
        const arr = [...this.messages];
        arr[existing] = updated;
        this.messages = arr;
      } else {
        if (message.type === 'tool_call' && this.messages.length > 0) {
          const lastIdx = this.messages.length - 1;
          const last = this.messages[lastIdx];
          if (last.type === 'tool_call') {
            const tools: ToolCallItem[] = last.data.tools ? [...last.data.tools] : [];
            if (tools.length === 0 && last.data.toolName) {
              tools.push({
                toolName: last.data.toolName,
                parameters: last.data.parameters,
                result: last.data.result
              });
            }
            tools.push({
              toolName: message.data.toolName || 'unknown',
              parameters: message.data.parameters,
              result: message.data.result || ''
            });
            const updated: Message = {
              type: last.type,
              id: last.id,
              seq: last.seq,
              stream: last.stream,
              data: { tools: tools },
              timestamp: last.timestamp
            };
            const arr2 = [...this.messages];
            arr2[lastIdx] = updated;
            this.messages = arr2;
            return;
          }
        }
        this.messages = [...this.messages, message];
      }
      return;
    }

    this.messages = [...this.messages, message];
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
    this.showSessionSheet = false;
    const data: MessageData = {};
    const message: Message = {
      type: 'session_create',
      id: `msg_${Date.now()}`,
      data: data,
      timestamp: Date.now()
    };

    webSocketService.sendMessage(message);
    this.messages = [];
    this.loadingHistory = true;
  }

  switchSession(sessionId: string) {
    this.messages = [];
    this.loadingHistory = true;
    this.showSessionSheet = false;

    const data: MessageData = { sessionId };
    const message: Message = {
      type: 'session_switch',
      id: `msg_${Date.now()}`,
      data: data,
      timestamp: Date.now()
    };

    webSocketService.sendMessage(message);
  }

  deleteSession(sessionId: string) {
    if (this.sessions.length <= 1) {
      promptAction.showToast({ message: '至少保留一个会话' });
      return;
    }

    const data: MessageData = { sessionId };
    const message: Message = {
      type: 'session_delete',
      id: `msg_${Date.now()}`,
      data: data,
      timestamp: Date.now()
    };

    webSocketService.sendMessage(message);

    this.sessions = this.sessions.filter(s => s.id !== sessionId);
    if (this.currentSession && this.currentSession.id === sessionId) {
      const next = this.sessions[0];
      if (next) {
        this.switchSession(next.id);
      } else {
        this.currentSession = null;
        this.messages = [];
      }
    }
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
          .fontColor(WX.TEXT)
      }
      .width(40)
      .height(40)
      .backgroundColor(WX.GREEN_BG)
      .onClick(() => {
        webSocketService.disconnect();
        router.back();
      })

      Column() {
        Text(this.currentSession?.name || '加载中...')
          .fontSize(WX.FONT_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(WX.TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .onClick(() => {
            this.showSessionSheet = true;
          })

        Row() {
          Circle({ width: 8, height: 8 })
            .fill(this.isConnected ? WX.GREEN : WX.DANGER)
            .margin({ right: 4 })

          Text(this.isConnected ? '已连接' : '未连接')
            .fontSize(WX.FONT_TINY)
            .fontColor(WX.TEXT_SUB)
        }
        .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      Text(this.tokenUsageText)
        .fontSize(WX.FONT_SMALL)
        .fontColor(this.tokenTotal > this.tokenLimit * 0.8 ? WX.DANGER : WX.GREEN)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(WX.RADIUS_SM)
        .backgroundColor(WX.GRAY_LIGHT)

      Button({ type: ButtonType.Normal }) {
        Text('\u22ee')
          .fontSize(20)
          .fontColor(WX.TEXT)
      }
      .width(40)
      .height(40)
      .backgroundColor(WX.GREEN_BG)
      .onClick(() => {
        this.showMenu();
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: 12, right: 12 })
    .backgroundColor(WX.GREEN_BG)
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
        }, (message: Message) => {
          const toolCount = message.data.tools ? message.data.tools.length : 0;
          return message.id + '_' + (message.stream || 'none') + '_' + toolCount;
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onAreaChange(() => {
        if (this.scroller) {
          this.scroller.scrollEdge(Edge.Bottom);
        }
      })
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
      .backgroundColor(this.isRecording ? WX.DANGER : WX.GRAY_LIGHT)
      .onClick(() => {
        this.toggleVoiceInput();
      })

      TextInput({ text: this.inputText, placeholder: '输入消息...' })
        .layoutWeight(1)
        .margin({ left: 8, right: 8 })
        .height(40)
        .borderRadius(WX.RADIUS_SM)
        .backgroundColor(WX.WHITE)
        .onChange((value: string) => {
          this.inputText = value;
        })
        .onFocus(() => {
          this.scrollToBottom();
        })
        .onSubmit(() => {
          this.sendMessage();
        })

      Button('发送')
        .height(40)
        .fontSize(WX.FONT_CAPTION)
        .type(ButtonType.Normal)
        .backgroundColor(WX.GREEN)
        .fontColor(WX.WHITE)
        .borderRadius(WX.RADIUS_SM)
        .onClick(() => {
          this.sendMessage();
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(WX.GREEN_INPUT)
  }

  build() {
    Stack() {
      Column() {
        this.TitleBar()
        this.ChatArea()
        this.InputBar()
      }
      .width('100%')
      .height('100%')

      if (this.showSessionSheet) {
        SessionListSheet({
          sessions: this.sessions,
          currentSessionId: this.currentSession ? this.currentSession.id : '',
          onDeleteSession: (id: string) => {
            this.deleteSession(id);
          },
          onSwitchSession: (id: string) => {
            this.switchSession(id);
          },
          onCreateSession: () => {
            this.createSession();
          },
          onClose: () => {
            this.showSessionSheet = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(WX.GREEN_BG)
  }

  showMenu() {
    promptAction.showActionMenu({
      title: '菜单',
      buttons: [
        { text: '切换会话', color: '#000000' },
        { text: '代码审查', color: '#000000' },
        { text: '新建会话', color: '#52c41a' }
      ] as [promptAction.Button, promptAction.Button, promptAction.Button, promptAction.Button?, promptAction.Button?, promptAction.Button?]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (result.index === 0) {
        this.showSessionSheet = true;
      } else if (result.index === 1) {
        this.openReviewPage();
      } else if (result.index === 2) {
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

import { Connection, Message, Session, QRCodeData, MessageData } from '../models/index';
import { connectionService } from '../services/ConnectionService';
import { webSocketService } from '../services/WebSocketService';
import { voiceService } from '../services/VoiceService';
import { MessageBubble } from '../components/MessageBubble';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';

interface ChatPageParams {
  connectionId?: string;
  qrData?: string;
}

interface UsageInfo {
  total: number;
  limit: number;
}

@Entry
@Component
struct ChatPage {
  @State messages: Message[] = [];
  @State inputText: string = '';
  @State currentSession: Session | null = null;
  @State sessions: Session[] = [];
  @State isConnected: boolean = false;
  @State tokenUsage: string = '0/4k';
  @State isRecording: boolean = false;
  @State reviewUrl: string = '';

  private connection: Connection | null = null;

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
      host: this.connection.host,
      port: this.connection.port,
      publicKey: this.connection.publicKey,
      token: this.connection.token,
      relayUrl: this.connection.relayUrl
    };

    webSocketService.onConnectionChange((connected: boolean) => {
      this.isConnected = connected;
      if (connected && this.connection) {
        connectionService.updateOnlineStatus(this.connection.id, true);
      }
    });

    webSocketService.onMessage((message: Message) => {
      this.handleIncomingMessage(message);
    });

    webSocketService.connect(qrData);
  }

  setupVoiceInput() {
    voiceService.onResult((text: string) => {
      this.inputText = text;
      this.isRecording = false;
    });
  }

  handleIncomingMessage(message: Message) {
    if (message.type === 'session_list') {
      const sessions: Session[] = message.data.sessions || [];
      this.sessions = sessions;
    } else if (message.type === 'session_switch') {
      this.currentSession = {
        id: message.data.sessionId || '',
        name: message.data.name || '',
        createdAt: Date.now(),
        lastActivity: Date.now()
      };
    } else if (message.type === 'token_info') {
      const usage: UsageInfo = {
        total: (message.data.total || 0) as number,
        limit: (message.data.limit || 4000) as number
      };
      this.tokenUsage = `${usage.total}/${usage.limit}`;
    } else if (message.type === 'review_url') {
      this.reviewUrl = message.data.url || '';
    } else {
      this.messages.push(message);
    }
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

    webSocketService.sendMessage(message);
    this.messages.push(message);
    this.inputText = '';
  }

  createSession() {
    const data: MessageData = { name: '新会话' };
    const message: Message = {
      type: 'session_create',
      id: `msg_${Date.now()}`,
      data: data,
      timestamp: Date.now()
    };

    webSocketService.sendMessage(message);
  }

  switchSession(sessionId: string) {
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
      promptAction.showToast({ message: 'No review URL available' });
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

  build() {
    Column() {
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

        Text(this.tokenUsage)
          .fontSize(12)
          .fontColor('#52c41a')
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
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#ffffff')

      List() {
        ForEach(this.messages, (message: Message) => {
          ListItem() {
            MessageBubble({ message: message })
          }
        }, (message: Message) => message.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)

      Row() {
        Button({ type: ButtonType.Circle }) {
          Text(this.isRecording ? '\u23f9' : '\ud83c\udf99')
            .fontSize(20)
        }
        .width(44)
        .height(44)
        .backgroundColor(this.isRecording ? '#ff4d4f' : '#f0f0f0')
        .onClick(() => {
          this.toggleVoiceInput();
        })

        TextInput({ text: this.inputText, placeholder: '输入消息...' })
          .layoutWeight(1)
          .margin({ left: 8, right: 8 })
          .height(44)
          .borderRadius(22)
          .backgroundColor('#f5f5f5')
          .onChange((value: string) => {
            this.inputText = value;
          })
          .onSubmit(() => {
            this.sendMessage();
          })

        Button('发送')
          .height(44)
          .onClick(() => {
            this.sendMessage();
          })
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#ffffff')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  showSessionSwitcher() {
    const sessionNames = this.sessions.map((s: Session) => s.name);
    const buttons: [promptAction.Button] = [{ text: '+ 新建会话', color: '#52c41a' }];
    
    if (sessionNames.length > 0) {
      buttons.unshift({ text: sessionNames[0], color: '#000000' });
    }
    if (sessionNames.length > 1) {
      buttons.splice(1, 0, { text: sessionNames[1], color: '#000000' });
    }
    if (sessionNames.length > 2) {
      buttons.splice(2, 0, { text: sessionNames[2], color: '#000000' });
    }
    if (sessionNames.length > 3) {
      buttons.splice(3, 0, { text: sessionNames[3], color: '#000000' });
    }
    if (sessionNames.length > 4) {
      buttons.splice(4, 0, { text: sessionNames[4], color: '#000000' });
    }
    
    const sessionCount = this.sessions.length;
    promptAction.showActionMenu({
      title: '切换会话',
      buttons: buttons
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      const index = result.index;
      if (index === sessionCount) {
        this.createSession();
      } else if (index < sessionCount) {
        this.switchSession(this.sessions[index].id);
      }
    });
  }

  showMenu() {
    promptAction.showActionMenu({
      title: '菜单',
      buttons: [
        { text: '代码审查', color: '#000000' },
        { text: '新建会话', color: '#52c41a' }
      ]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (result.index === 0) {
        this.openReviewPage();
      } else if (result.index === 1) {
        this.createSession();
      }
    });
  }

  aboutToDisappear() {
    webSocketService.disconnect();
    voiceService.cleanup();
    if (this.connection) {
      connectionService.updateOnlineStatus(this.connection.id, false);
    }
  }
}
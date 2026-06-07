import { Connection, Message, Session, QRCodeData } from '../models/index';
import { connectionService } from '../services/ConnectionService';
import { webSocketService } from '../services/WebSocketService';
import { MessageBubble } from '../components/MessageBubble';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';

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
        const qrData = JSON.parse(params.qrData);
        this.connection = {
          id: `temp_${Date.now()}`,
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

  handleIncomingMessage(message: Message) {
    if (message.type === 'session_list') {
      this.sessions = message.data.sessions;
    } else if (message.type === 'session_switch') {
      this.currentSession = {
        id: message.data.sessionId,
        name: message.data.name,
        createdAt: Date.now(),
        lastActivity: Date.now()
      };
    } else if (message.type === 'token_info') {
      const usage = message.data;
      this.tokenUsage = `${usage.total || 0}/${usage.contextWindow || 4000}`;
    } else if (message.type === 'review_url') {
      this.reviewUrl = message.data.url;
    } else {
      this.messages.push(message);
    }
  }

  sendMessage() {
    if (!this.inputText.trim()) return;

    const message: Message = {
      type: 'user_message',
      id: `msg_${Date.now()}`,
      data: { content: this.inputText },
      timestamp: Date.now()
    };

    webSocketService.sendMessage(message);
    this.messages.push(message);
    this.inputText = '';
  }

  createSession() {
    const message: Message = {
      type: 'session_create',
      id: `msg_${Date.now()}`,
      data: { name: `Session ${this.sessions.length + 1}` },
      timestamp: Date.now()
    };

    webSocketService.sendMessage(message);
  }

  switchSession(sessionId: string) {
    const message: Message = {
      type: 'session_switch',
      id: `msg_${Date.now()}`,
      data: { sessionId },
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

  startVoiceInput() {
    this.isRecording = true;
    // TODO: Implement HarmonyOS ASR
    // Using system voice recognition API
    promptAction.showToast({ message: 'Voice input not yet implemented' });
    
    setTimeout(() => {
      this.isRecording = false;
    }, 3000);
  }

  build() {
    Column() {
      // Header
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('←')
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

        // Token usage
        Text(this.tokenUsage)
          .fontSize(12)
          .fontColor('#52c41a')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(12)
          .backgroundColor('#f6ffed')

        // Menu button
        Button({ type: ButtonType.Normal }) {
          Text('⋮')
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

      // Message list
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

      // Input bar
      Row() {
        // Voice input button
        Button({ type: ButtonType.Circle }) {
          Text(this.isRecording ? '⏹' : '🎤')
            .fontSize(20)
        }
        .width(44)
        .height(44)
        .backgroundColor(this.isRecording ? '#ff4d4f' : '#f0f0f0')
        .onClick(() => {
          this.startVoiceInput();
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
    // Show a dialog or bottom sheet with session list
    promptAction.showActionMenu({
      title: '切换会话',
      buttons: [
        ...this.sessions.map(s => ({ text: s.name, color: '#000000' })),
        { text: '+ 新建会话', color: '#52c41a' }
      ]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      const index = result.index;
      if (index === this.sessions.length) {
        this.createSession();
      } else if (index < this.sessions.length) {
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
    if (this.connection) {
      connectionService.updateOnlineStatus(this.connection.id, false);
    }
  }
}

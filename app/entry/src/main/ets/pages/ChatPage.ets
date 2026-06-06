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
  
  private connection: Connection | null = null;

  aboutToAppear() {
    const params = router.getParams() as ChatPageParams;
    
    if (params?.connectionId) {
      this.connection = connectionService.get(params.connectionId) || null;
    } else if (params?.qrData) {
      // Temporary connection from QR scan
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
              // Show session switcher
            })
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
        Button({ type: ButtonType.Circle }) {
          Text('🎤')
            .fontSize(20)
        }
        .width(44)
        .height(44)
        .backgroundColor('#f0f0f0')

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

  aboutToDisappear() {
    webSocketService.disconnect();
  }
}

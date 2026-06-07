import { Message, MessageData } from '../models/index';
import { webSocketService } from '../services/WebSocketService';
import { MarkdownText } from './MarkdownText';
import { MermaidDiagram } from './MermaidDiagram';

@Component
export struct MessageBubble {
  @Prop message: Message;
  @State isExpanded: boolean = false;

  build() {
    if (this.message.type === 'user_message') {
      this.UserMessage()
    } else if (this.message.type === 'thinking') {
      this.ThinkingMessage()
    } else if (this.message.type === 'tool_call') {
      this.ToolCallMessage()
    } else if (this.message.type === 'permission_request') {
      this.PermissionRequestMessage()
    } else if (this.message.type === 'reply') {
      this.ReplyMessage()
    } else {
      this.DefaultMessage()
    }
  }

  @Builder
  UserMessage() {
    Row() {
      Blank()
      Text(this.message.data.content || '')
        .fontSize(14)
        .fontColor('#ffffff')
        .padding(12)
        .backgroundColor('#52c41a')
        .borderRadius(12)
        .constraintSize({ maxWidth: '70%' })
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  ThinkingMessage() {
    Row() {
      Column() {
        Row() {
          Text('思考中...')
            .fontSize(12)
            .fontColor('#999999')

          Blank()

          Button({ type: ButtonType.Normal }) {
            Text(this.isExpanded ? '收起' : '展开')
              .fontSize(11)
          }
          .height(24)
          .onClick(() => {
            this.isExpanded = !this.isExpanded;
          })
        }
        .width('100%')

        if (this.isExpanded) {
          Text(this.message.data.content || '')
            .fontSize(13)
            .fontColor('#666666')
            .margin({ top: 8 })
        }
      }
      .padding(12)
      .backgroundColor('#f0f0f0')
      .borderRadius(12)
      .constraintSize({ maxWidth: '70%' })

      Blank()
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  ToolCallMessage() {
    Row() {
      Column() {
        Text(`🔧 ${this.message.data.name || '未知工具'}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')

        if (this.message.data.parameters) {
          Text(`参数: ${JSON.stringify(this.message.data.parameters)}`)
            .fontSize(11)
            .fontColor('#999999')
            .margin({ top: 4 })
        }

        if (this.message.data.result) {
          Text(`结果: ${this.message.data.result}`)
            .fontSize(11)
            .fontColor('#666666')
            .margin({ top: 4 })
        }
      }
      .padding(12)
      .backgroundColor('#e6f7ff')
      .borderRadius(12)
      .constraintSize({ maxWidth: '70%' })

      Blank()
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  PermissionRequestMessage() {
    Row() {
      Column() {
        Text('权限请求')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')

        Text(this.message.data.description || '')
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 8 })

        Row() {
          Button('允许')
            .height(32)
            .fontSize(12)
            .layoutWeight(1)
            .onClick(() => {
              this.handlePermissionReply(true);
            })

          Button('拒绝')
            .height(32)
            .fontSize(12)
            .layoutWeight(1)
            .margin({ left: 8 })
            .type(ButtonType.Normal)
            .backgroundColor('#ff4d4f')
            .onClick(() => {
              this.handlePermissionReply(false);
            })
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .padding(12)
      .backgroundColor('#fff7e6')
      .borderRadius(12)
      .constraintSize({ maxWidth: '70%' })

      Blank()
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  ReplyMessage() {
    Row() {
      Column() {
        if (this.hasMermaidDiagram()) {
          MermaidDiagram({ code: this.extractMermaidCode() })
            .margin({ bottom: 12 })
        }

        MarkdownText({ markdown: this.extractMarkdownContent() })
      }
      .padding(12)
      .backgroundColor('#ffffff')
      .borderRadius(12)
      .constraintSize({ maxWidth: '70%' })

      Blank()
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  DefaultMessage() {
    Row() {
      Text('[未知消息]')
        .fontSize(12)
        .fontColor('#999999')
        .padding(8)

      Blank()
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  private hasMermaidDiagram(): boolean {
    const content = this.message.data.content || '';
    return content.includes('```mermaid');
  }

  private extractMermaidCode(): string {
    const content = this.message.data.content || '';
    const regex = /```mermaid\n([\s\S]*?)\n```/;
    const match = regex.exec(content);
    if (match !== null && match.length > 1) {
      const result: string = match[1] as string;
      return result;
    }
    return '';
  }

  private extractMarkdownContent(): string {
    const content = this.message.data.content || '';
    return content.replace(/```mermaid\n[\s\S]*?\n```\n?/g, '').trim();
  }

  handlePermissionReply(allowed: boolean) {
    const replyData: MessageData = {
      requestId: this.message.data.requestId || '',
      allowed: allowed
    };
    const replyMessage: Message = {
      type: 'permission_reply',
      id: `reply_${Date.now()}`,
      data: replyData,
      timestamp: Date.now()
    };
    webSocketService.sendMessage(replyMessage);
    console.log('Permission reply sent');
  }
}
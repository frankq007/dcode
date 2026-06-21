import { Message, MessageData } from '../models/index';
import { webSocketService } from '../services/WebSocketService';
import { Markdown } from '@luvi/lv-markdown-in';
import { MermaidDiagram } from './MermaidDiagram';

@Component
export struct MessageBubble {
  @Prop message: Message;
  @State isThinkingExpanded: boolean = false;
  @State isToolExpanded: boolean = false;

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

  private isStreaming(): boolean {
    const s = this.message.stream;
    return s === 'start' || s === 'append';
  }

  private isFinished(): boolean {
    const s = this.message.stream;
    return s === undefined || s === null || s === 'end' || s === 'aborted' || s === 'replace';
  }

  @Builder
  UserMessage() {
    Row() {
      Blank()
      Column() {
        Text(this.message.data.content || '')
          .fontSize(15)
          .fontColor('#000000')
          .textAlign(TextAlign.Start)
          .constraintSize({ maxWidth: '100%' })
      }
      .constraintSize({ maxWidth: '80%' })
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor('#95EC69')
      .borderRadius(12)
      .clip(true)
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  ThinkingMessage() {
    Row() {
      Column() {
        Row() {
          Text('思考')
            .fontSize(12)
            .fontColor('#8c8c8c')
            .fontWeight(FontWeight.Medium)
          if (this.isStreaming()) {
            LoadingProgress()
              .width(12)
              .height(12)
              .margin({ left: 6 })
              .color('#bfbfbf')
          }
          Blank()
          Text(this.isThinkingExpanded ? '收起' : '展开')
            .fontSize(11)
            .fontColor('#1890ff')
            .onClick(() => {
              this.isThinkingExpanded = !this.isThinkingExpanded;
            })
        }
        .width('100%')

        if (!this.isThinkingExpanded) {
          Text(this.thinkingPreview())
            .fontSize(12)
            .fontColor('#bfbfbf')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 4 })
        } else {
          Text(this.message.data.content || '(空)')
            .fontSize(13)
            .fontColor('#595959')
            .width('100%')
            .margin({ top: 6 })
        }
      }
      .constraintSize({ maxWidth: '80%' })
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor('#F5F5F5')
      .borderRadius(12)
      .clip(true)
      .onClick(() => {
        this.isThinkingExpanded = !this.isThinkingExpanded;
      })

      Blank()
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  ToolCallMessage() {
    Row() {
      Column() {
        Row() {
          Text('🔧')
            .fontSize(14)
          Text((this.message.data.toolName || this.message.data.name || '工具调用') as string)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: 4 })
          Blank()
          if (this.message.data.result) {
            Text(this.isToolExpanded ? '收起' : '详情')
              .fontSize(11)
              .fontColor('#1890ff')
              .onClick(() => {
                this.isToolExpanded = !this.isToolExpanded;
              })
          }
        }
        .width('100%')

        if (this.message.data.parameters) {
          Text(`参数: ${JSON.stringify(this.message.data.parameters)}`)
            .fontSize(11)
            .fontColor('#999999')
            .margin({ top: 4 })
            .maxLines(this.isToolExpanded ? undefined : 2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }

        if (this.message.data.result && this.isToolExpanded) {
          Text(`结果: ${this.message.data.result}`)
            .fontSize(11)
            .fontColor('#666666')
            .margin({ top: 4 })
            .width('100%')
        }
      }
      .constraintSize({ maxWidth: '80%' })
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor('#E8F5E9')
      .borderRadius(12)
      .clip(true)

      Blank()
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  PermissionRequestMessage() {
    Row() {
      Column() {
        Text('权限请求')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .width('100%')

        Text(this.message.data.description || '')
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 6 })
          .width('100%')

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
        .margin({ top: 10 })
      }
      .constraintSize({ maxWidth: '80%' })
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor('#FFF3E0')
      .borderRadius(12)
      .clip(true)

      Blank()
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  ReplyMessage() {
    Row() {
      Column() {
        if (this.hasMermaidDiagram() && this.isFinished()) {
          MermaidDiagram({ code: this.extractMermaidCode() })
            .margin({ bottom: 8 })
        }

        if (this.isStreaming()) {
          Text(this.message.data.content || '')
            .fontSize(14)
            .fontColor('#262626')
            .width('100%')
            .lineHeight(22)

          Row() {
            LoadingProgress()
              .width(12)
              .height(12)
              .color('#1890ff')
            Text('正在输入')
              .fontSize(11)
              .fontColor('#bfbfbf')
              .margin({ left: 4 })
          }
          .margin({ top: 6 })
        } else {
          Markdown({ text: this.extractMarkdownContent(), mode: 'text' })
        }
      }
      .layoutWeight(1)
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor('#FFFFFF')
      .borderRadius(12)

      Blank()
        .width(40)
    }
    .width('100%')
    .margin({ bottom: 8 })
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
    .margin({ bottom: 8 })
  }

  private thinkingPreview(): string {
    const c = this.message.data.content || '';
    if (!c) {
      return this.isStreaming() ? '思考中...' : '(空)';
    }
    return c;
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
  }
}

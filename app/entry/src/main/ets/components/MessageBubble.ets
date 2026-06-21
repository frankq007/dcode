import { Message, MessageData, ToolCallItem } from '../models/index';
import { webSocketService } from '../services/WebSocketService';
import { Markdown } from '@luvi/lv-markdown-in';
import { MermaidDiagram } from './MermaidDiagram';
import { WX } from '../theme/WXTheme';

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
    return s === undefined || s === null || s === 'end' || s === 'aborted';
  }

  @Builder
  UserMessage() {
    Row() {
      Blank()
      Column() {
        Text(this.message.data.content || '')
          .fontSize(WX.FONT_BODY)
          .fontColor(WX.TEXT)
          .textAlign(TextAlign.Start)
          .constraintSize({ maxWidth: '100%' })
      }
      .constraintSize({ maxWidth: '75%' })
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .backgroundColor(WX.GREEN_LIGHT)
      .borderRadius(WX.RADIUS_SM)
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
          if (this.isStreaming()) {
            LoadingProgress()
              .width(12)
              .height(12)
              .color(WX.GREEN)
          }
          Text(this.isStreaming() ? '思考中' : '思考过程')
            .fontSize(WX.FONT_CAPTION)
            .fontColor(this.isStreaming() ? WX.GREEN : WX.TEXT_SUB)
            .fontWeight(FontWeight.Medium)
            .margin({ left: this.isStreaming() ? 6 : 0 })
          Blank()
          if (!this.isStreaming() && this.message.data.content) {
            Text(this.isThinkingExpanded ? '收起' : '展开')
              .fontSize(WX.FONT_TINY)
              .fontColor(WX.LINK)
              .onClick(() => {
                this.isThinkingExpanded = !this.isThinkingExpanded;
              })
          }
        }
        .width('100%')

        if (this.isStreaming()) {
          Text('正在等待 AI 响应...')
            .fontSize(WX.FONT_SMALL)
            .fontColor(WX.TEXT_HINT)
            .margin({ top: 4 })
        } else if (!this.isThinkingExpanded) {
          Text(this.thinkingPreview())
            .fontSize(WX.FONT_SMALL)
            .fontColor(WX.TEXT_HINT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: '100%' })
            .margin({ top: 4 })
        } else {
          Text(this.message.data.content || '(空)')
            .fontSize(WX.FONT_SMALL)
            .fontColor(WX.TEXT_SUB)
            .constraintSize({ maxWidth: '100%' })
            .margin({ top: 6 })
        }
      }
      .layoutWeight(1)
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .backgroundColor(WX.GRAY)
      .borderRadius(WX.RADIUS_SM)

      Blank()
        .width(40)
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  private hasParameters(): boolean {
    const p = this.message.data.parameters;
    if (!p) return false;
    if (typeof p === 'string') return p.length > 0;
    try {
      return Object.keys(p as object).length > 0;
    } catch {
      return false;
    }
  }

  private hasToolParameters(tool: ToolCallItem): boolean {
    if (!tool.parameters) return false;
    if (typeof tool.parameters === 'string') return (tool.parameters as string).length > 0;
    try {
      return Object.keys(tool.parameters as object).length > 0;
    } catch {
      return false;
    }
  }

  private getToolList(): ToolCallItem[] {
    if (this.message.data.tools && this.message.data.tools.length > 0) {
      return this.message.data.tools;
    }
    const tools: ToolCallItem[] = [];
    if (this.message.data.toolName) {
      tools.push({
        toolName: this.message.data.toolName,
        parameters: this.message.data.parameters,
        result: this.message.data.result
      });
    }
    return tools;
  }

  private hasAnyResult(): boolean {
    const tools = this.getToolList();
    for (const t of tools) {
      if (t.result) return true;
    }
    return false;
  }

  @Builder
  ToolCallMessage() {
    Row() {
      Column() {
        Row() {
          Text('🔧')
            .fontSize(WX.FONT_CAPTION)
          Text(this.getToolList().length > 1
            ? `工具调用 (${this.getToolList().length})`
            : (this.message.data.toolName || this.message.data.name || '工具调用') as string)
            .fontSize(WX.FONT_CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor(WX.TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: 4 })
            .layoutWeight(1)
          if (this.hasAnyResult()) {
            Text(this.isToolExpanded ? '收起' : '详情')
              .fontSize(WX.FONT_TINY)
              .fontColor(WX.LINK)
              .onClick(() => {
                this.isToolExpanded = !this.isToolExpanded;
              })
          }
        }
        .width('100%')

        ForEach(this.getToolList(), (tool: ToolCallItem, index: number) => {
          Column() {
            if (index > 0) {
              Divider()
                .color(WX.DIVIDER)
                .margin({ top: 6, bottom: 4 })
            }
            Row() {
              Text(tool.toolName || 'unknown')
                .fontSize(WX.FONT_SMALL)
                .fontColor(WX.TEXT_SUB)
                .layoutWeight(1)
            }
            .width('100%')

            if (this.hasToolParameters(tool)) {
                Text(`参数: ${JSON.stringify(tool.parameters)}`)
                  .fontSize(WX.FONT_TINY)
                  .fontColor(WX.TEXT_HINT)
                  .margin({ top: 2 })
                  .maxLines(this.isToolExpanded ? undefined : 2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
            }

            if (tool.result && this.isToolExpanded) {
              Text(`结果: ${tool.result}`)
                .fontSize(WX.FONT_TINY)
                .fontColor(WX.TEXT_SUB)
                .margin({ top: 2 })
                .width('100%')
            }
          }
          .width('100%')
        }, (tool: ToolCallItem, index: number) => `${tool.toolName}_${index}`)
      }
      .layoutWeight(1)
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .backgroundColor(WX.GRAY)
      .borderRadius(WX.RADIUS_SM)
      .clip(true)

      Blank()
        .width(40)
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  PermissionRequestMessage() {
    Row() {
      Column() {
        Text('权限请求')
          .fontSize(WX.FONT_CAPTION)
          .fontWeight(FontWeight.Bold)
          .fontColor(WX.TEXT)
          .width('100%')

        Text(this.message.data.description || '')
          .fontSize(WX.FONT_SMALL)
          .fontColor(WX.TEXT_SUB)
          .margin({ top: 6 })
          .width('100%')

        Row() {
          Button('允许')
            .height(32)
            .fontSize(WX.FONT_SMALL)
            .layoutWeight(1)
            .type(ButtonType.Normal)
            .backgroundColor(WX.GREEN)
            .fontColor(WX.WHITE)
            .borderRadius(WX.RADIUS_SM)
            .onClick(() => {
              this.handlePermissionReply(true);
            })

          Button('拒绝')
            .height(32)
            .fontSize(WX.FONT_SMALL)
            .layoutWeight(1)
            .margin({ left: 8 })
            .type(ButtonType.Normal)
            .backgroundColor(WX.DANGER)
            .fontColor(WX.WHITE)
            .borderRadius(WX.RADIUS_SM)
            .onClick(() => {
              this.handlePermissionReply(false);
            })
        }
        .width('100%')
        .margin({ top: 10 })
      }
      .constraintSize({ maxWidth: '75%' })
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(WX.WARNING_BG)
      .borderRadius(WX.RADIUS_SM)
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
            .fontSize(WX.FONT_BODY)
            .fontColor(WX.TEXT)
            .width('100%')
            .lineHeight(22)

          Row() {
            LoadingProgress()
              .width(12)
              .height(12)
              .color(WX.GREEN)
            Text('正在输入')
              .fontSize(WX.FONT_TINY)
              .fontColor(WX.TEXT_HINT)
              .margin({ left: 4 })
          }
          .margin({ top: 6 })
        } else {
          Markdown({ text: this.extractMarkdownContent(), mode: 'text' })
        }
      }
      .layoutWeight(1)
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .backgroundColor(WX.WHITE)
      .borderRadius(WX.RADIUS_SM)

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
        .fontSize(WX.FONT_SMALL)
        .fontColor(WX.TEXT_HINT)
        .padding(8)
      Blank()
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  private thinkingPreview(): string {
    const c = this.message.data.content || '';
    if (!c) {
      return this.isStreaming() ? '正在等待 AI 响应...' : '(空)';
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

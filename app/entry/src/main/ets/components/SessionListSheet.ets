import { Session } from '../models/index';
import { WX } from '../theme/WXTheme';

@Component
export struct SessionListSheet {
  @Prop sessions: Session[];
  @Prop currentSessionId: string;
  @State deleteMode: boolean = false;
  onDeleteSession: (sessionId: string) => void = () => {};
  onSwitchSession: (sessionId: string) => void = () => {};
  onCreateSession: () => void = () => {};
  onClose: () => void = () => {};

  build() {
    Column() {
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#000000')
        .opacity(0.4)
        .onClick(() => {
          this.deleteMode = false;
          this.onClose();
        })

      Column() {
        this.SheetHeader()
        this.SheetList()
        this.SheetFooter()
      }
      .width('100%')
      .height('75%')
      .backgroundColor(WX.WHITE)
      .borderRadius({ topLeft: WX.RADIUS_LG, topRight: WX.RADIUS_LG })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SheetHeader() {
    Row() {
      Text('会话列表')
        .fontSize(WX.FONT_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(WX.TEXT)

      Blank()

      Button(this.deleteMode ? '完成' : '管理')
        .type(ButtonType.Normal)
        .height(30)
        .fontSize(WX.FONT_SMALL)
        .fontColor(this.deleteMode ? WX.GREEN : WX.TEXT_SUB)
        .backgroundColor(this.deleteMode ? WX.GRAY_LIGHT : WX.GRAY)
        .borderRadius(WX.RADIUS_SM)
        .onClick(() => {
          this.deleteMode = !this.deleteMode;
        })

      Button({ type: ButtonType.Circle }) {
        Text('\u2715')
          .fontSize(16)
          .fontColor(WX.TEXT_SUB)
      }
      .width(32)
      .height(32)
      .margin({ left: 4 })
      .backgroundColor(WX.GRAY)
      .onClick(() => {
        this.deleteMode = false;
        this.onClose();
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 12 })
  }

  @Builder
  SheetList() {
    if (this.sessions.length === 0) {
      Column() {
        Text('暂无会话')
          .fontSize(WX.FONT_CAPTION)
          .fontColor(WX.TEXT_SUB)
        Text('点击下方按钮新建会话')
          .fontSize(WX.FONT_SMALL)
          .fontColor(WX.TEXT_HINT)
          .margin({ top: 4 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List() {
        ForEach(this.sessions, (session: Session) => {
          ListItem() {
            this.SessionRow(session)
          }
        }, (session: Session) => session.id + (session.isActive ? '_a' : ''))
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: WX.DIVIDER, startMargin: 16, endMargin: 16 })
      .scrollBar(BarState.Auto)
    }
  }

  @Builder
  SessionRow(session: Session) {
    Row() {
      Column() {
        Text(session.name || session.id.substring(0, 8))
          .fontSize(WX.FONT_BODY)
          .fontColor(session.id === this.currentSessionId ? WX.GREEN : WX.TEXT)
          .fontWeight(session.id === this.currentSessionId ? FontWeight.Bold : FontWeight.Normal)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '80%' })

        if (session.lastActivity > 0) {
          Text(this.formatTime(session.lastActivity))
            .fontSize(WX.FONT_TINY)
            .fontColor(WX.TEXT_SUB)
            .margin({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.deleteMode) {
        Button('删除', { type: ButtonType.Normal })
          .height(28)
          .fontSize(WX.FONT_SMALL)
          .fontColor(WX.WHITE)
          .backgroundColor(WX.DANGER)
          .borderRadius(WX.RADIUS_SM)
          .onClick(() => {
            this.onDeleteSession(session.id);
          })
      } else if (session.id === this.currentSessionId) {
        Text('当前')
          .fontSize(WX.FONT_TINY)
          .fontColor(WX.GREEN)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(WX.RADIUS_SM)
          .backgroundColor(WX.GRAY_LIGHT)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick(() => {
      if (this.deleteMode) return;
      if (session.id !== this.currentSessionId) {
        this.onSwitchSession(session.id);
      } else {
        this.onClose();
      }
    })
  }

  @Builder
  SheetFooter() {
    Button('+ 新建会话')
      .width('90%')
      .height(44)
      .fontSize(WX.FONT_BODY)
      .fontColor(WX.WHITE)
      .backgroundColor(WX.GREEN)
      .borderRadius(WX.RADIUS_SM)
      .margin({ top: 12, bottom: 16 })
      .onClick(() => {
        this.deleteMode = false;
        this.onCreateSession();
      })
  }

  private formatTime(timestamp: number): string {
    if (!timestamp) return '';
    const date = new Date(timestamp);
    const now = new Date();
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const hours = date.getHours();
    const minutes = date.getMinutes();
    const h = hours < 10 ? '0' + hours : '' + hours;
    const m = minutes < 10 ? '0' + minutes : '' + minutes;

    if (date.getFullYear() === now.getFullYear() &&
        date.getMonth() === now.getMonth() &&
        date.getDate() === now.getDate()) {
      return `今天 ${h}:${m}`;
    }

    const yesterday = new Date(now);
    yesterday.setDate(now.getDate() - 1);
    if (date.getFullYear() === yesterday.getFullYear() &&
        date.getMonth() === yesterday.getMonth() &&
        date.getDate() === yesterday.getDate()) {
      return `昨天 ${h}:${m}`;
    }

    return `${month}月${day}日 ${h}:${m}`;
  }
}

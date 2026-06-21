import { Session } from '../models/index';

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
      .backgroundColor('#ffffff')
      .borderRadius({ topLeft: 16, topRight: 16 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SheetHeader() {
    Row() {
      Text('会话列表')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')

      Blank()

      Button(this.deleteMode ? '完成' : '管理')
        .type(ButtonType.Normal)
        .height(32)
        .fontSize(13)
        .fontColor(this.deleteMode ? '#1890ff' : '#666666')
        .onClick(() => {
          this.deleteMode = !this.deleteMode;
        })

      Button({ type: ButtonType.Circle }) {
        Text('\u2715')
          .fontSize(16)
          .fontColor('#999999')
      }
      .width(32)
      .height(32)
      .margin({ left: 4 })
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
          .fontSize(14)
          .fontColor('#999999')
        Text('点击下方按钮新建会话')
          .fontSize(12)
          .fontColor('#bbbbbb')
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
      .divider({ strokeWidth: 1, color: '#f0f0f0', startMargin: 16, endMargin: 16 })
      .scrollBar(BarState.Auto)
    }
  }

  @Builder
  SessionRow(session: Session) {
    Row() {
      Column() {
        Text(session.name || session.id.substring(0, 8))
          .fontSize(15)
          .fontColor(session.id === this.currentSessionId ? '#1890ff' : '#333333')
          .fontWeight(session.id === this.currentSessionId ? FontWeight.Bold : FontWeight.Normal)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '80%' })

        if (session.lastActivity > 0) {
          Text(this.formatTime(session.lastActivity))
            .fontSize(11)
            .fontColor('#999999')
            .margin({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.deleteMode) {
        Button('删除')
          .type(ButtonType.Normal)
          .height(30)
          .fontSize(12)
          .fontColor('#ff4d4f')
          .borderRadius(6)
          .onClick(() => {
            this.onDeleteSession(session.id);
          })
      } else if (session.id === this.currentSessionId) {
        Text('当前')
          .fontSize(11)
          .fontColor('#1890ff')
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(8)
          .backgroundColor('#e6f7ff')
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
      .fontSize(15)
      .fontColor('#ffffff')
      .backgroundColor('#52c41a')
      .borderRadius(22)
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

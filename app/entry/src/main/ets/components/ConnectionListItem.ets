import { Connection } from '../models/index';
import { connectionService } from '../services/ConnectionService';
import router from '@ohos.router';

@Component
export struct ConnectionListItem {
  @Prop connection: Connection;
  @State showActions: boolean = false;
  onDelete: (id: string) => void = () => {};

  build() {
    Row() {
      // Status indicator
      Circle({ width: 12, height: 12 })
        .fill(this.connection.isOnline ? '#52c41a' : '#d9d9d9')
        .margin({ left: 16, right: 12 })

      // Connection info
      Column() {
        Text(this.connection.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
        
        Text(`${this.connection.mode === 'direct' ? '直连' : '云转发'} - ${this.connection.host}:${this.connection.port}`)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // Action buttons
      Row() {
        Button('连接')
          .fontSize(12)
          .height(32)
          .onClick(() => {
            router.pushUrl({
              url: 'pages/ChatPage',
              params: { connectionId: this.connection.id }
            });
          })
        
        Button('删除')
          .fontSize(12)
          .height(32)
          .type(ButtonType.Normal)
          .backgroundColor('#ff4d4f')
          .margin({ left: 8 })
          .onClick(() => {
            this.deleteConnection();
          })
      }
      .padding({ right: 16 })
    }
    .width('100%')
    .height(72)
    .backgroundColor('#ffffff')
    .onClick(() => {
      router.pushUrl({
        url: 'pages/ChatPage',
        params: { connectionId: this.connection.id }
      });
    })
  }

  async deleteConnection() {
    try {
      await connectionService.delete(this.connection.id);
      this.onDelete(this.connection.id);
    } catch (e) {
      console.error('[ConnectionListItem] Delete failed:', e);
    }
  }
}

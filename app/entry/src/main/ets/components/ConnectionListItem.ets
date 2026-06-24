import { Connection } from '../models/index';
import { connectionService } from '../services/ConnectionService';
import router from '@ohos.router';
import { WX } from '../theme/WXTheme';

@Component
export struct ConnectionListItem {
  @Prop connection: Connection;
  @State showActions: boolean = false;
  onDelete: (id: string) => void = () => {};

  build() {
    Row() {
      Circle({ width: 10, height: 10 })
        .fill(this.connection.isOnline ? WX.GREEN : WX.TEXT_HINT)
        .margin({ left: 16, right: 12 })

      Column() {
        Text(this.connection.name)
          .fontSize(WX.FONT_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(WX.TEXT)

        Text(this.connection.mode === 'relay'
          ? `云转发 · ${this.connection.relayUrl || '中继'}`
          : `直连 · ${this.connection.host}:${this.connection.port}`)
          .fontSize(WX.FONT_SMALL)
          .fontColor(WX.TEXT_SUB)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row() {
        Button('连接', { type: ButtonType.Normal })
          .fontSize(WX.FONT_SMALL)
          .height(30)
          .fontColor(WX.WHITE)
          .backgroundColor(WX.GREEN)
          .borderRadius(WX.RADIUS_SM)
          .onClick(() => {
            router.pushUrl({
              url: 'pages/ChatPage',
              params: { connectionId: this.connection.id }
            });
          })

        Button('删除', { type: ButtonType.Normal })
          .fontSize(WX.FONT_SMALL)
          .height(30)
          .margin({ left: 8 })
          .fontColor(WX.DANGER)
          .backgroundColor(WX.GRAY_LIGHT)
          .borderRadius(WX.RADIUS_SM)
          .onClick(() => {
            this.deleteConnection();
          })
      }
      .padding({ right: 16 })
    }
    .width('100%')
    .height(72)
    .backgroundColor(WX.WHITE)
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

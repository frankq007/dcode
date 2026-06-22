import { Connection } from '../models/index';
import { connectionService } from '../services/ConnectionService';
import { ConnectionListItem } from '../components/ConnectionListItem';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { WX } from '../theme/WXTheme';

@Entry
@Component
struct ConnectionListPage {
  @State connections: Connection[] = [];
  @State isLoading: boolean = true;
  @State quickPublicKey: string = 'EHWxpi6m9cbgoG/tDKwdhaPP2pvjnL/v6Mr1rYmGeSU=';
  @State quickToken: string = 'dcode-dev-token-0001';

  aboutToAppear() {
    this.loadConnections();
  }

  onPageShow() {
    this.loadConnections();
  }

  async loadConnections() {
    this.isLoading = true;
    this.connections = connectionService.getAll();
    this.isLoading = false;
  }

  build() {
    Column() {
      Row() {
        Text('连接')
          .fontSize(WX.FONT_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(WX.TEXT)

        Blank()

        Row() {
          Button('手动', { type: ButtonType.Normal })
            .fontSize(WX.FONT_SMALL)
            .height(32)
            .fontColor(WX.TEXT)
            .backgroundColor(WX.GRAY_LIGHT)
            .borderRadius(WX.RADIUS_SM)
            .onClick(() => {
              router.pushUrl({ url: 'pages/ManualConnectionPage' });
            })

          Button('扫一扫', { type: ButtonType.Normal })
            .fontSize(WX.FONT_SMALL)
            .height(32)
            .margin({ left: 8 })
            .fontColor(WX.WHITE)
            .backgroundColor(WX.GREEN)
            .borderRadius(WX.RADIUS_SM)
            .onClick(() => {
              router.pushUrl({ url: 'pages/QRScannerPage' });
            })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(WX.GREEN_BG)

      if (this.connections.length === 0) {
        Column() {
          Text('暂无连接')
            .fontSize(WX.FONT_BODY)
            .fontColor(WX.TEXT_HINT)
            .margin({ top: 100 })

          Text('扫描 Gateway 生成的二维码或手动输入连接信息')
            .fontSize(WX.FONT_CAPTION)
            .fontColor(WX.TEXT_HINT)
            .margin({ top: 8 })

          Row() {
            Button('扫一扫', { type: ButtonType.Normal })
              .height(40)
              .fontSize(WX.FONT_CAPTION)
              .fontColor(WX.WHITE)
              .backgroundColor(WX.GREEN)
              .borderRadius(WX.RADIUS_SM)
              .onClick(() => {
                router.pushUrl({ url: 'pages/QRScannerPage' });
              })

            Button('手动添加', { type: ButtonType.Normal })
              .height(40)
              .fontSize(WX.FONT_CAPTION)
              .margin({ left: 12 })
              .fontColor(WX.TEXT)
              .backgroundColor(WX.GRAY_LIGHT)
              .borderRadius(WX.RADIUS_SM)
              .onClick(() => {
                router.pushUrl({ url: 'pages/ManualConnectionPage' });
              })

            Button('快速连接', { type: ButtonType.Normal })
              .height(40)
              .fontSize(WX.FONT_CAPTION)
              .margin({ left: 12 })
              .fontColor(WX.WHITE)
              .backgroundColor(WX.GREEN)
              .borderRadius(WX.RADIUS_SM)
              .onClick(() => {
                const qrData: string = '{"mode":"direct","name":"MyPC","host":"10.0.2.2","port":8765,"publicKey":"EHWxpi6m9cbgoG/tDKwdhaPP2pvjnL/v6Mr1rYmGeSU=","token":"dcode-dev-token-0001"}';
                router.pushUrl({ url: 'pages/ChatPage', params: { qrData: qrData } });
              })
          }
          .margin({ top: 24 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: false }) {
          List() {
            ForEach(this.connections, (connection: Connection) => {
              ListItem() {
                ConnectionListItem({
                  connection: connection,
                  onDelete: (id: string) => {
                    this.connections = this.connections.filter(c => c.id !== id);
                  }
                })
              }
            }, (connection: Connection) => connection.id)
          }
          .width('100%')
          .layoutWeight(1)
          .divider({ strokeWidth: 0.5, color: WX.DIVIDER })
        }
        .onRefreshing(() => {
          this.loadConnections();
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(WX.GREEN_BG)
  }
}

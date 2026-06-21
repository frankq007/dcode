import { Connection } from '../models/index';
import { connectionService } from '../services/ConnectionService';
import { ConnectionListItem } from '../components/ConnectionListItem';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct ConnectionListPage {
  @State connections: Connection[] = [];
  @State isLoading: boolean = true;
  @State quickPublicKey: string = 'p4j4BBNcGKp4Q6ogSGwpWzlBAZaKM3y8i/cB5Qto8Dg=';
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
      // Header
      Row() {
        Text('连接列表')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
        
        Blank()
        
        // Action buttons
        Row() {
          Button('手动', { type: ButtonType.Normal })
            .fontSize(13)
            .height(32)
            .onClick(() => {
              router.pushUrl({ url: 'pages/ManualConnectionPage' });
            })
          
          Button('扫一扫', { type: ButtonType.Capsule })
            .fontSize(13)
            .height(32)
            .margin({ left: 8 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/QRScannerPage' });
            })
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#ffffff')

      // Connection list
      if (this.connections.length === 0) {
        Column() {
          Text('暂无连接')
            .fontSize(16)
            .fontColor('#999999')
            .margin({ top: 100 })
          
          Text('扫描 Gateway 生成的二维码或手动输入连接信息')
            .fontSize(13)
            .fontColor('#bbbbbb')
            .margin({ top: 8 })
          
          Row() {
            Button('扫一扫', { type: ButtonType.Normal })
              .height(40)
              .onClick(() => {
                router.pushUrl({ url: 'pages/QRScannerPage' });
              })
            
            Button('手动添加', { type: ButtonType.Capsule })
              .height(40)
              .margin({ left: 12 })
              .onClick(() => {
                router.pushUrl({ url: 'pages/ManualConnectionPage' });
              })

            Button('快速连接', { type: ButtonType.Capsule })
              .height(40)
              .margin({ left: 12 })
              .backgroundColor('#52c41a')
              .onClick(() => {
                const qrData: string = '{"mode":"direct","name":"MyPC","host":"10.0.2.2","port":8765,"publicKey":"p4j4BBNcGKp4Q6ogSGwpWzlBAZaKM3y8i/cB5Qto8Dg=","token":"dcode-dev-token-0001"}';
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
                ConnectionListItem({ connection: connection })
              }
            }, (connection: Connection) => connection.id)
          }
          .width('100%')
          .layoutWeight(1)
          .divider({ strokeWidth: 1, color: '#f0f0f0' })
        }
        .onRefreshing(() => {
          this.loadConnections();
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }
}

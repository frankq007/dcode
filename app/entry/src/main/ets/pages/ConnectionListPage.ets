import { Connection } from '../models/index';
import { connectionService } from '../services/ConnectionService';
import { ConnectionListItem } from '../components/ConnectionListItem';
import router from '@ohos.router';

@Entry
@Component
struct ConnectionListPage {
  @State connections: Connection[] = [];
  @State isLoading: boolean = true;

  aboutToAppear() {
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
        
        // QR Scanner button
        Button('扫一扫', { type: ButtonType.Normal })
          .fontSize(14)
          .onClick(() => {
            router.pushUrl({ url: 'pages/QRScannerPage' });
          })
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
          
          Button('添加连接', { type: ButtonType.Capsule })
            .margin({ top: 20 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/QRScannerPage' });
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }
}

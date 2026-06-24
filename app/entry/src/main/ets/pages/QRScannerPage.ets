import { QRCodeData, Connection } from '../models/index';
import { connectionService } from '../services/ConnectionService';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';

@Entry
@Component
struct QRScannerPage {
  @State scannedData: string = '';
  @State showActionPanel: boolean = false;
  @State parsedQRData: QRCodeData | null = null;

  aboutToAppear() {
    this.startScan();
  }

  async startScan() {
    try {
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE]
      };

      const result = await scanBarcode.startScanForResult(getContext(this), options);
      this.handleScanResult(result.originalValue);
    } catch (e) {
      console.error('[QRScanner] Scan error:', e);
      promptAction.showToast({ message: '扫码失败，请重试' });
    }
  }

  handleScanResult(data: string) {
    try {
      const qrData: QRCodeData = JSON.parse(data);
      this.parsedQRData = qrData;
      this.showActionPanel = true;
    } catch (e) {
      console.error('[QRScanner] Parse error:', e);
      promptAction.showToast({ message: '无效的二维码' });
    }
  }

  async saveAndConnect() {
    if (!this.parsedQRData) return;

    const connection: Connection = {
      id: `conn_${Date.now()}`,
      name: this.parsedQRData.name,
      mode: this.parsedQRData.mode,
      host: this.parsedQRData.host,
      port: this.parsedQRData.port,
      publicKey: this.parsedQRData.publicKey,
      token: this.parsedQRData.token,
      relayUrl: this.parsedQRData.relayUrl,
      isOnline: false
    };

    try {
      await connectionService.add(connection);
      router.replaceUrl({
        url: 'pages/ChatPage',
        params: { connectionId: connection.id }
      });
    } catch (e) {
      console.error('[QRScanner] Save failed:', e);
      promptAction.showToast({ message: '保存连接失败' });
    }
  }

  connectOnce() {
    if (!this.parsedQRData) return;

    router.replaceUrl({
      url: 'pages/ChatPage',
      params: { qrData: JSON.stringify(this.parsedQRData) }
    });
  }

  build() {
    Stack() {
      Column() {
        Text('请将二维码放入框内扫描')
          .fontSize(16)
          .fontColor('#ffffff')
          .margin({ top: 100 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#000000')
      .justifyContent(FlexAlign.Center)

      Button({ type: ButtonType.Circle }) {
        Text('\u2190')
          .fontSize(24)
          .fontColor('#ffffff')
      }
      .width(48)
      .height(48)
      .backgroundColor('rgba(0,0,0,0.5)')
      .position({ left: 16, top: 16 })
      .onClick(() => {
        router.back();
      })

      if (this.showActionPanel && this.parsedQRData) {
        Column() {
          Text(this.parsedQRData.name)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: 8 })

          Text(`模式: ${this.parsedQRData.mode === 'direct' ? '直连' : '云转发'}`)
            .fontSize(14)
            .fontColor('#666666')
            .margin({ bottom: 4 })

          Text(this.parsedQRData.mode === 'relay'
            ? `地址: ${this.parsedQRData.relayUrl || '中继'}`
            : `地址: ${this.parsedQRData.host}:${this.parsedQRData.port}`)
            .fontSize(14)
            .fontColor('#666666')
            .margin({ bottom: 16 })

          Row() {
            Button('连接并保存')
              .layoutWeight(1)
              .onClick(() => this.saveAndConnect())

            Button('仅连接一次')
              .layoutWeight(1)
              .margin({ left: 12 })
              .type(ButtonType.Normal)
              .onClick(() => this.connectOnce())
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#ffffff')
        .borderRadius({ topLeft: 16, topRight: 16 })
        .position({ bottom: 0 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
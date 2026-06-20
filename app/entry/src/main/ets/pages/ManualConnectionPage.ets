import { Connection } from '../models/index';
import { connectionService } from '../services/ConnectionService';
import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';

@Entry
@Component
struct ManualConnectionPage {
  @State name: string = 'MyPC';
  @State host: string = '100.117.37.34';
  @State port: string = '8765';
  @State mode: 'direct' | 'relay' = 'direct';
  @State relayUrl: string = '';
  @State publicKey: string = '';
  @State token: string = 'dcode-dev-token-0001';

  build() {
    Column() {
      // Header
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('←')
            .fontSize(20)
        }
        .width(40)
        .height(40)
        .onClick(() => {
          router.back();
        })

        Text('手动添加连接')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#ffffff')

      // Form
      Scroll() {
        Column() {
          // Name
          Column() {
            Text('连接名称')
              .fontSize(14)
              .fontColor('#666666')
              .margin({ bottom: 8 })
            
            TextInput({ text: this.name, placeholder: '例如：我的电脑' })
              .height(44)
              .borderRadius(8)
              .backgroundColor('#f5f5f5')
              .onChange((value: string) => {
                this.name = value;
              })
          }
          .margin({ bottom: 16 })

          // Mode
          Column() {
            Text('连接模式')
              .fontSize(14)
              .fontColor('#666666')
              .margin({ bottom: 8 })
            
            Row() {
              Button('直连')
                .layoutWeight(1)
                .type(this.mode === 'direct' ? ButtonType.Capsule : ButtonType.Normal)
                .onClick(() => {
                  this.mode = 'direct';
                })
              
              Button('云转发')
                .layoutWeight(1)
                .margin({ left: 8 })
                .type(this.mode === 'relay' ? ButtonType.Capsule : ButtonType.Normal)
                .onClick(() => {
                  this.mode = 'relay';
                })
            }
          }
          .margin({ bottom: 16 })

          // Host
          Column() {
            Text('主机地址')
              .fontSize(14)
              .fontColor('#666666')
              .margin({ bottom: 8 })
            
            TextInput({ text: this.host, placeholder: '例如：192.168.1.100' })
              .height(44)
              .borderRadius(8)
              .backgroundColor('#f5f5f5')
              .onChange((value: string) => {
                this.host = value;
              })
          }
          .margin({ bottom: 16 })

          // Port
          Column() {
            Text('端口')
              .fontSize(14)
              .fontColor('#666666')
              .margin({ bottom: 8 })
            
            TextInput({ text: this.port, placeholder: '8765' })
              .height(44)
              .borderRadius(8)
              .backgroundColor('#f5f5f5')
              .type(InputType.Number)
              .onChange((value: string) => {
                this.port = value;
              })
          }
          .margin({ bottom: 16 })

          // Relay URL (only show in relay mode)
          if (this.mode === 'relay') {
            Column() {
              Text('Relay URL')
                .fontSize(14)
                .fontColor('#666666')
                .margin({ bottom: 8 })
              
              TextInput({ text: this.relayUrl, placeholder: '例如：ws://relay.example.com:8766' })
                .height(44)
                .borderRadius(8)
                .backgroundColor('#f5f5f5')
                .onChange((value: string) => {
                  this.relayUrl = value;
                })
            }
            .margin({ bottom: 16 })
          }

          // Public Key
          Column() {
            Text('公钥 (Base64)')
              .fontSize(14)
              .fontColor('#666666')
              .margin({ bottom: 8 })
            
            TextInput({ text: this.publicKey, placeholder: 'Gateway 生成的公钥' })
              .height(44)
              .borderRadius(8)
              .backgroundColor('#f5f5f5')
              .onChange((value: string) => {
                this.publicKey = value;
              })
          }
          .margin({ bottom: 16 })

          // Token
          Column() {
            Text('Token')
              .fontSize(14)
              .fontColor('#666666')
              .margin({ bottom: 8 })
            
            TextInput({ text: this.token, placeholder: '配对 Token' })
              .height(44)
              .borderRadius(8)
              .backgroundColor('#f5f5f5')
              .onChange((value: string) => {
                this.token = value;
              })
          }
          .margin({ bottom: 24 })

          // Submit button
          Button('保存并连接')
            .width('100%')
            .height(48)
            .onClick(() => {
              this.saveAndConnect();
            })
        }
        .padding(20)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  async saveAndConnect() {
    if (!this.name || !this.host || !this.port || !this.token) {
      promptAction.showToast({ message: '请填写所有必填字段' });
      return;
    }

    if (this.mode === 'relay' && !this.relayUrl) {
      promptAction.showToast({ message: '请填写 Relay URL' });
      return;
    }

    const connection: Connection = {
      id: `conn_${Date.now()}`,
      name: this.name,
      mode: this.mode,
      host: this.host,
      port: parseInt(this.port),
      publicKey: this.publicKey,
      token: this.token,
      relayUrl: this.relayUrl || undefined,
      isOnline: false
    };

    try {
      await connectionService.add(connection);
      router.replaceUrl({
        url: 'pages/ChatPage',
        params: { connectionId: connection.id }
      });
    } catch (e) {
      console.error('[ManualConnection] Save failed:', e);
      promptAction.showToast({ message: '保存失败' });
    }
  }
}

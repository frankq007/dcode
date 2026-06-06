import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  aboutToAppear() {
    router.replaceUrl({ url: 'pages/ConnectionListPage' });
  }

  build() {
    Column() {
      Text('加载中...')
        .fontSize(16)
        .fontColor('#999999')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}

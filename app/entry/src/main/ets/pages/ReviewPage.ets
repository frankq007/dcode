import { webview, Webview } from '@kit.WebKit';
import router from '@ohos.router';

interface ReviewPageParams {
  url: string;
  title?: string;
}

@Entry
@Component
struct ReviewPage {
  @State url: string = '';
  @State title: string = 'Code Review';
  @State isLoading: boolean = true;
  @State loadProgress: number = 0;
  
  private controller: WebviewController | null = null;

  aboutToAppear() {
    const params = router.getParams() as ReviewPageParams;
    if (params?.url) {
      this.url = params.url;
    }
    if (params?.title) {
      this.title = params.title;
    }
  }

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

        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 12 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Button({ type: ButtonType.Normal }) {
          Text('↻')
            .fontSize(20)
        }
        .width(40)
        .height(40)
        .onClick(() => {
          this.controller?.refresh();
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#ffffff')

      // Progress bar
      if (this.isLoading) {
        Progress({ value: this.loadProgress, total: 100 })
          .width('100%')
          .height(3)
          .color('#52c41a')
      }

      // WebView
      Web({ src: this.url, controller: this.controller })
        .width('100%')
        .layoutWeight(1)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onPageBegin(() => {
          this.isLoading = true;
        })
        .onPageEnd(() => {
          this.isLoading = false;
        })
        .onProgressChange((event) => {
          if (event) {
            this.loadProgress = event.newProgress;
          }
        })
        .onErrorReceive((event) => {
          console.error('[ReviewPage] Error:', event?.error.getErrorInfo());
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }
}

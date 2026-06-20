import webview from '@ohos.web.webview';

@Component
export struct MermaidDiagram {
  @Prop code: string = '';
  @State isLoading: boolean = true;
  private controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Stack() {
      Web({ src: this.generateMermaidHtml(), controller: this.controller })
        .width('100%')
        .height(300)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onPageEnd(() => {
          this.isLoading = false;
        })
        .onErrorReceive((event) => {
          console.error('[MermaidDiagram] Error:', event?.error.getErrorInfo());
          this.isLoading = false;
        })

      if (this.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color('#52c41a')
      }
    }
    .width('100%')
    .height(300)
    .backgroundColor('#ffffff')
    .borderRadius(8)
  }

  private generateMermaidHtml(): string {
    const escapedCode = this.code
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');

    const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="resource://rawfile/mermaid.min.js"></script>
  <style>
    body {
      margin: 0;
      padding: 16px;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
    }
    .mermaid {
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 250px;
    }
    .error {
      color: #ff4d4f;
      font-size: 14px;
      padding: 16px;
    }
  </style>
</head>
<body>
  <div class="mermaid">${escapedCode}</div>
  <script>
    mermaid.initialize({
      startOnLoad: true,
      theme: 'default',
      flowchart: {
        useMaxWidth: true,
        htmlLabels: true
      }
    });

    window.addEventListener('error', function(e) {
      document.body.innerHTML = '<div class="error">图表渲染失败: ' + e.message + '</div>';
    });
  </script>
</body>
</html>
    `.trim();

    return 'data:text/html;charset=utf-8,' + encodeURIComponent(html);
  }
}
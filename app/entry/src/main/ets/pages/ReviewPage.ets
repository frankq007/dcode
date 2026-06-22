import router from '@ohos.router';
import { FileDiff } from '../models/index';
import { WX } from '../theme/WXTheme';

interface ReviewPageParams {
  diffs?: FileDiff[];
  title?: string;
}

@Entry
@Component
struct ReviewPage {
  @State diffs: FileDiff[] = [];
  @State title: string = '代码审查';
  @State expandedFiles: string[] = [];

  aboutToAppear() {
    const params = router.getParams() as ReviewPageParams;
    if (params?.diffs) {
      this.diffs = params.diffs;
    }
    if (params?.title) {
      this.title = params.title;
    }
  }

  private toggleFile(file: string): void {
    const idx = this.expandedFiles.indexOf(file);
    if (idx >= 0) {
      this.expandedFiles.splice(idx, 1);
    } else {
      this.expandedFiles.push(file);
    }
    this.expandedFiles = [...this.expandedFiles];
  }

  private isExpanded(file: string): boolean {
    return this.expandedFiles.includes(file);
  }

  private parseDiffLines(patch: string): string[] {
    return patch.split('\n');
  }

  private isAddLine(line: string): boolean {
    return line.startsWith('+') && !line.startsWith('+++');
  }

  private isRemoveLine(line: string): boolean {
    return line.startsWith('-') && !line.startsWith('---');
  }

  private isContextLine(line: string): boolean {
    return line.startsWith(' ') || line === '';
  }

  private isHeaderLine(line: string): boolean {
    return line.startsWith('Index:') || line.startsWith('===') ||
           line.startsWith('---') || line.startsWith('+++') ||
           line.startsWith('@@');
  }

  private getFileName(path: string): string {
    const parts = path.split('/');
    return parts[parts.length - 1] || path;
  }

  private getStatusText(status: string): string {
    if (status === 'added') return '新增';
    if (status === 'modified') return '修改';
    if (status === 'deleted') return '删除';
    return status;
  }

  private getStatusColor(status: string): string {
    if (status === 'added') return WX.GREEN;
    if (status === 'modified') return WX.WARNING;
    if (status === 'deleted') return WX.DANGER;
    return WX.TEXT_SUB;
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('\u2190')
            .fontSize(20)
            .fontColor(WX.TEXT)
        }
        .width(40)
        .height(40)
        .backgroundColor(WX.GREEN_BG)
        .onClick(() => {
          router.back();
        })

        Text(this.title)
          .fontSize(WX.FONT_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(WX.TEXT)
          .layoutWeight(1)
          .margin({ left: 12 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.diffs.length > 0) {
          Text(`${this.diffs.length} 个文件`)
            .fontSize(WX.FONT_SMALL)
            .fontColor(WX.TEXT_SUB)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(WX.RADIUS_SM)
            .backgroundColor(WX.GRAY_LIGHT)
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })
      .backgroundColor(WX.GREEN_BG)

      if (this.diffs.length === 0) {
        Column() {
          Text('暂无代码变更')
            .fontSize(WX.FONT_BODY)
            .fontColor(WX.TEXT_HINT)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.diffs, (diff: FileDiff) => {
              this.DiffCard(diff)
            }, (diff: FileDiff) => diff.file + diff.status)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(WX.GREEN_BG)
  }

  @Builder
  DiffCard(diff: FileDiff) {
    Column() {
      Row() {
        Text(this.getStatusText(diff.status))
          .fontSize(WX.FONT_TINY)
          .fontColor(WX.WHITE)
          .backgroundColor(this.getStatusColor(diff.status))
          .borderRadius(WX.RADIUS_SM)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })

        Text(this.getFileName(diff.file))
          .fontSize(WX.FONT_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(WX.TEXT)
          .layoutWeight(1)
          .margin({ left: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`+${diff.additions}`)
          .fontSize(WX.FONT_TINY)
          .fontColor(WX.GREEN)

        Text(`  -${diff.deletions}`)
          .fontSize(WX.FONT_TINY)
          .fontColor(WX.DANGER)

        Text(this.isExpanded(diff.file) ? '▼' : '▶')
          .fontSize(WX.FONT_TINY)
          .fontColor(WX.TEXT_SUB)
          .margin({ left: 8 })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .onClick(() => {
        this.toggleFile(diff.file);
      })

      if (this.isExpanded(diff.file)) {
        Column() {
          ForEach(this.parseDiffLines(diff.patch), (line: string, idx: number) => {
            this.DiffLine(line, idx)
          }, (line: string, idx: number) => `${idx}_${line.substring(0, 20)}`)
        }
        .width('100%')
        .backgroundColor(WX.WHITE)
        .borderRadius({ bottomLeft: WX.RADIUS_SM, bottomRight: WX.RADIUS_SM })
        .clip(true)
      }
    }
    .width('100%')
    .backgroundColor(WX.WHITE)
    .borderRadius(WX.RADIUS_SM)
    .clip(true)
    .margin({ bottom: 8 })
  }

  @Builder
  DiffLine(line: string, idx: number) {
    if (this.isHeaderLine(line)) {
      Text(line)
        .fontSize(10)
        .fontColor(WX.TEXT_HINT)
        .fontFamily('monospace')
        .width('100%')
        .padding({ left: 12, right: 12, top: 3, bottom: 3 })
        .backgroundColor(WX.GRAY)
    } else if (this.isAddLine(line)) {
      Text(line)
        .fontSize(10)
        .fontColor(WX.GREEN)
        .fontFamily('monospace')
        .width('100%')
        .padding({ left: 12, right: 12, top: 3, bottom: 3 })
        .backgroundColor('#E8F5E9')
    } else if (this.isRemoveLine(line)) {
      Text(line)
        .fontSize(10)
        .fontColor(WX.DANGER)
        .fontFamily('monospace')
        .width('100%')
        .padding({ left: 12, right: 12, top: 3, bottom: 3 })
        .backgroundColor('#FFEBEE')
    } else {
      Text(line.length > 0 ? line : ' ')
        .fontSize(10)
        .fontColor(WX.TEXT_SUB)
        .fontFamily('monospace')
        .width('100%')
        .padding({ left: 12, right: 12, top: 3, bottom: 3 })
    }
  }
}

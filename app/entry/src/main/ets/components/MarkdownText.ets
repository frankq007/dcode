interface SpanStyle {
  fontSize?: number;
  fontColor?: string;
  fontWeight?: FontWeight;
  fontStyle?: FontStyle;
  fontFamily?: string;
  textDecoration?: TextDecorationType;
  backgroundColor?: string;
  padding?: number;
  borderRadius?: number;
}

interface Span {
  text: string;
  style: SpanStyle;
}

interface Pattern {
  regex: RegExp;
  style: SpanStyle;
}

interface Match {
  start: number;
  end: number;
  text: string;
  style: SpanStyle;
}

interface Block {
  type: string;
  code: string;
  spans: Span[];
}

@Component
export struct MarkdownText {
  @Prop @Watch('onMarkdownChange') markdown: string = '';
  @State blocks: Block[] = [];

  aboutToAppear() {
    this.parseMarkdown();
  }

  onMarkdownChange() {
    this.parseMarkdown();
  }

  private parseMarkdown() {
    if (!this.markdown) {
      this.blocks = [];
      return;
    }

    const blocks: Block[] = [];
    const lines = this.markdown.split('\n');
    let inCodeBlock = false;
    let codeContent = '';
    let pendingParagraphLines: string[] = [];

    const flushParagraph = () => {
      if (pendingParagraphLines.length === 0) {
        return;
      }
      const spans: Span[] = [];
      for (let i = 0; i < pendingParagraphLines.length; i++) {
        this.parseInlineFormatting(pendingParagraphLines[i], spans);
        const emptyStyle: SpanStyle = {};
        spans.push({ text: '\n', style: emptyStyle });
      }
      if (spans.length > 0) {
        spans.pop();
      }
      const paragraphBlock: Block = { type: 'paragraph', code: '', spans: spans };
      blocks.push(paragraphBlock);
      pendingParagraphLines = [];
    };

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          const code: string = codeContent.replace(/\n$/, '');
          const codeBlock: Block = { type: 'code', code: code, spans: [] };
          blocks.push(codeBlock);
          codeContent = '';
          inCodeBlock = false;
        } else {
          flushParagraph();
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeContent += line + '\n';
        continue;
      }

      pendingParagraphLines.push(line);
    }

    flushParagraph();

    this.blocks = blocks;
  }

  private parseInlineFormatting(line: string, spans: Span[]) {
    const patterns: Pattern[] = [
      { regex: /\*\*(.+?)\*\*/g, style: { fontWeight: FontWeight.Bold } as SpanStyle },
      { regex: /\*(.+?)\*/g, style: { fontStyle: FontStyle.Italic } as SpanStyle },
      { regex: /`(.+?)`/g, style: { fontFamily: 'monospace', backgroundColor: '#f0f0f0' } as SpanStyle },
      { regex: /\[(.+?)\]\((.+?)\)/g, style: { fontColor: '#1890ff', textDecoration: TextDecorationType.Underline } as SpanStyle }
    ];

    let lastIndex = 0;
    const matches: Match[] = [];

    for (let p = 0; p < patterns.length; p++) {
      const pattern = patterns[p];
      let match: RegExpExecArray | null;
      while ((match = pattern.regex.exec(line)) !== null) {
        matches.push({
          start: match.index,
          end: match.index + match[0].length,
          text: match[1],
          style: pattern.style
        });
      }
    }

    matches.sort((a: Match, b: Match) => a.start - b.start);

    for (let m = 0; m < matches.length; m++) {
      const match = matches[m];
      if (match.start > lastIndex) {
        const emptyStyle: SpanStyle = {};
        spans.push({
          text: line.substring(lastIndex, match.start),
          style: emptyStyle
        });
      }
      spans.push({
        text: match.text,
        style: match.style
      });
      lastIndex = match.end;
    }

    if (lastIndex < line.length) {
      const emptyStyle: SpanStyle = {};
      spans.push({
        text: line.substring(lastIndex),
        style: emptyStyle
      });
    }

    if (matches.length === 0) {
      const emptyStyle: SpanStyle = {};
      spans.push({
        text: line,
        style: emptyStyle
      });
    }
  }

  build() {
    Column() {
      if (this.blocks.length === 0) {
        Text(this.markdown)
          .fontSize(14)
          .fontColor('#333333')
          .lineHeight(20)
          .width('100%')
      } else {
        ForEach(this.blocks, (block: Block) => {
          if (block.type === 'code') {
            Scroll() {
              Text(block.code)
                .fontSize(13)
                .fontFamily('monospace')
                .fontColor('#333333')
                .backgroundColor('#f5f5f5')
                .padding(8)
                .borderRadius(4)
                .lineHeight(18)
            }
            .scrollable(ScrollDirection.Horizontal)
            .constraintSize({ maxWidth: '100%' })
            .margin({ top: 4, bottom: 4 })
          } else {
            Text() {
              ForEach(block.spans, (span: Span) => {
                Span(span.text)
                  .fontSize(span.style.fontSize || 14)
                  .fontColor(span.style.fontColor || '#333333')
                  .fontWeight(span.style.fontWeight || FontWeight.Normal)
                  .fontStyle(span.style.fontStyle || FontStyle.Normal)
                  .fontFamily(span.style.fontFamily || 'sans-serif')
                  .decoration({ type: span.style.textDecoration || TextDecorationType.None })
                  .backgroundColor(span.style.backgroundColor || 'transparent')
              })
            }
            .constraintSize({ maxWidth: '100%' })
            .lineHeight(20)
          }
        })
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: '100%' })
    .clip(true)
  }
}

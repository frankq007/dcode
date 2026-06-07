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

@Component
export struct MarkdownText {
  @Prop markdown: string = '';
  @State renderedText: Span[] = [];

  aboutToAppear() {
    this.parseMarkdown();
  }

  private parseMarkdown() {
    if (!this.markdown) {
      this.renderedText = [];
      return;
    }

    const spans: Span[] = [];
    const lines = this.markdown.split('\n');
    let inCodeBlock = false;
    let codeContent = '';

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          const codeStyle: SpanStyle = {
            fontFamily: 'monospace',
            backgroundColor: '#f5f5f5',
            padding: 8,
            borderRadius: 4
          };
          spans.push({
            text: '\n' + codeContent + '\n',
            style: codeStyle
          });
          codeContent = '';
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeContent += line + '\n';
        continue;
      }

      this.parseInlineFormatting(line, spans);
      const emptyStyle: SpanStyle = {};
      spans.push({ text: '\n', style: emptyStyle });
    }

    this.renderedText = spans;
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
      if (this.renderedText.length === 0) {
        Text(this.markdown)
          .fontSize(14)
          .fontColor('#333333')
          .lineHeight(20)
      } else {
        Text() {
          ForEach(this.renderedText, (span: Span) => {
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
        .width('100%')
        .lineHeight(20)
      }
    }
  }
}
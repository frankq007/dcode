// @keepTs
// @ts-nocheck
import { CodeTheme } from '../constant/CodeTheme';
import { CodeHighlight } from '../model/CodeHighlight';
import { MermaidSecurityLevel } from '../utils/MermaidHtmlBuilder';
import componentUtils from "@ohos.arkui.componentUtils";
import image from "@ohos.multimedia.image";
/**
 * @description Markdown 组件的控制器，可以将此对象绑定至 Markdown 组件，然后通过它控制 Markdown 组件的自定义样式。同一个控制器可以控制多个 Markdown 组件，多个 API 支持链式调用语法。
 */
@ObservedV2
export declare class MarkdownController {
    private union;
    private titleColor;
    private titleSize;
    private titleLineHeight;
    private titleFontWeight;
    private titleFontStyle;
    private titleFontFamily;
    private textColor;
    private textLineHeight;
    private textSize;
    private textFontFamily;
    private inlineCodeColor;
    private inlineCodeBackgroundColor;
    private inlineCodeBackgroundRadius;
    private quoteTextColor;
    private quoteBorderColor;
    private quoteBorderWidth;
    private quoteBackgroundColor;
    private quoteBorderRadius;
    private quotePadding;
    private codeBlockTheme;
    private codeBlockIdxState;
    private codeBlockBorderRadius;
    private codeHighlight;
    private codeCopyListener;
    private imageWidth;
    private imageMaxWidth;
    private imageHeight;
    private imageMaxHeight;
    private imageBorderRadius;
    private imageClickListener;
    private imageLoadProxy;
    private hyperlinkTextColor;
    private hyperlinkTextSize;
    private hyperlinkUnderlineState;
    private hyperlinkBackgroundColor;
    private hyperlinkBackgroundRadius;
    private hyperlinkClickListener;
    private tableBackgroundColor;
    private tableTitleBackgroundColor;
    private tableTitleTextColor;
    private tableInterleaveTextColor;
    private tableNormalTextColor;
    private tableInterleaveBackgroundColor;
    private tableBorderRadius;
    private tableOuterBorderColor;
    private tableOuterBorderWidth;
    private tableInnerBorderColor;
    private tableInnerBorderWidth;
    private tableAlign;
    private todoSelectedColor;
    private todoSelectSize;
    private ulPointSize;
    private ulPointColor;
    private footnoteTextColor;
    private lineColor;
    private latexMathTextSize;
    private latexMathTextColor;
    private latexClickListener;
    private mermaidEnable;
    private mermaidTheme;
    private mermaidSecurityLevel;
    private setextHeadingEnable;
    private threadRenderEnable;
    private lazyRender;
    private lazyPreloadBlockCount;
    private copyOption;
    private textSelectionEnable;
    private textSelectionCopyListener;
    private blockSpacing;
    constructor();
    getUnion(): string;
    /**
     * 设置标题-颜色
     * @param color
     * @version 3.2.2
     */
    setTitleColor(c44: ResourceColor | [
        ResourceColor,
        ResourceColor,
        ResourceColor,
        ResourceColor,
        ResourceColor,
        ResourceColor
    ]): this;
    getTitleColor(): ResourceColor | [
        ResourceColor,
        ResourceColor,
        ResourceColor,
        ResourceColor,
        ResourceColor,
        ResourceColor
    ];
    /**
     * 设置标题-字号（1-6级）
     * @param titleSize
     */
    setTitleSize(b44: [
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number
    ]): this;
    getTitleSize(): [
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number
    ];
    /**
     * 设置标题-行高（1-6级）
     * @param lineHeights
     */
    setTitleLineHeight(a44: [
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number
    ]): this;
    getTitleLineHeight(): [
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number,
        ResourceStr | number
    ];
    /**
     * 设置标题-字体粗细
     * @param fontWeight
     * @version 3.2.2
     */
    setTitleFontWeight(z43: FontWeight | [
        FontWeight,
        FontWeight,
        FontWeight,
        FontWeight,
        FontWeight,
        FontWeight
    ]): this;
    getTitleFontWeight(): FontWeight | [
        FontWeight,
        FontWeight,
        FontWeight,
        FontWeight,
        FontWeight,
        FontWeight
    ];
    /**
     * 设置标题-字体样式
     * @param fontStyle
     * @version 3.2.2
     */
    setTitleFontStyle(y43: FontStyle | [
        FontStyle,
        FontStyle,
        FontStyle,
        FontStyle,
        FontStyle,
        FontStyle
    ]): this;
    getTitleFontStyle(): FontStyle | [
        FontStyle,
        FontStyle,
        FontStyle,
        FontStyle,
        FontStyle,
        FontStyle
    ];
    /**
     * 设置标题-字体族（自定义字体）
     * @description 支持给指定级别的标题设置自定义字体。设置数组格式则为指定级别的标题设置自定义字体，设置唯一自定义字体，则1-6级标题全部生效。
     * @param fontFamily
     * @version 3.2.4
     */
    setTitleFontFamily(x43: ResourceStr | [
        ResourceStr,
        ResourceStr,
        ResourceStr,
        ResourceStr,
        ResourceStr,
        ResourceStr
    ]): this;
    getTitleFontFamily(): ResourceStr | [
        ResourceStr,
        ResourceStr,
        ResourceStr,
        ResourceStr,
        ResourceStr,
        ResourceStr
    ];
    /**
     * 设置普通文本-颜色
     * @param textColor
     */
    setTextColor(w43: ResourceColor): this;
    getTextColor(): ResourceColor;
    /**
     * 设置普通文本-行高
     * @param textLineHeight
     */
    setTextLineHeight(v43: ResourceStr | number): this;
    getTextLineHeight(): number | ResourceStr;
    /**
     * 设置普通文本-字号
     * @param textSize
     */
    setTextSize(u43: ResourceStr | number): this;
    getTextSize(): number | ResourceStr;
    /**
     * 设置普通文本-字体族（自定义字体）
     * @param textSize
     */
    setTextFontFamily(t43: ResourceStr): this;
    getTextFontFamily(): ResourceStr;
    /**
     * 设置行内代码-颜色
     * @param inlineCodeColor
     */
    setInlineCodeColor(s43: ResourceColor): this;
    getInlineCodeColor(): ResourceColor;
    /**
     * 设置行内代码-背景颜色
     * @param inlineCodeBackgroundColor
     */
    setInlineCodeBackgroundColor(r43: ResourceColor): this;
    getInlineCodeBackgroundColor(): ResourceColor;
    /**
     * 设置行内代码-背景圆角
     * @param inlineCodeBackgroundRadius
     */
    setInlineCodeBackgroundRadius(q43: Dimension): this;
    getInlineCodeBackgroundRadius(): Dimension;
    /**
     * 设置引用块-文本颜色
     * @param color
     * @returns
     */
    setQuoteTextColor(p43: ResourceColor): this;
    getQuoteTextColor(): ResourceColor;
    /**
     * 设置引用块-左边颜色
     * @param quoteBorderColor
     * @returns
     */
    setQuoteBorderColor(o43: ResourceColor): this;
    getQuoteBorderColor(): ResourceColor;
    /**
     * 设置引用块-背景颜色
     * @param quoteBackgroundColor
     */
    setQuoteBackgroundColor(n43: ResourceColor): this;
    getQuoteBackgroundColor(): ResourceColor;
    /**
     * 设置引用块-圆角
     * @param radius
     * @version 3.2.2
     */
    setQuoteBorderRadius(m43: ResourceStr | number): this;
    getQuoteBorderRadius(): number | ResourceStr;
    /**
     * 设置引用块-左边宽度
     * @param size
     * @version 3.2.2
     */
    setQuoteBorderWidth(l43: ResourceStr | number): this;
    getQuoteBorderWidth(): number | ResourceStr;
    /**
     * 设置引用块-内边距
     * @param radius
     * @version 3.3.0
     */
    setQuotePadding(k43: Padding | Length | LocalizedPadding): this;
    getQuotePadding(): Padding | Length | LocalizedPadding;
    /**
     * 设置代码块-主题
     * @param codeBlockTheme
     */
    setCodeBlockTheme(j43: CodeTheme): this;
    getCodeBlockTheme(): CodeTheme;
    /**
     * 设置代码块-索引展示状态
     * @param codeBlockIdxState
     */
    setCodeBlockIdxState(i43: boolean): this;
    getCodeBlockIdxState(): boolean;
    /**
     * 设置代码块-圆角
     * @param radius
     * @version 3.2.2
     */
    setCodeBlockBorderRadius(h43: number | ResourceStr): this;
    getCodeBlockBorderRadius(): number | ResourceStr;
    /**
     * 设置代码高亮着色
     * @param codeHighlight
     */
    setCodeHighlight(g43: CodeHighlight): this;
    getCodeHighlight(): CodeHighlight;
    /**
     * 设置代码块-点击复制监听
     * @param event
     * @returns
     */
    setCodeCopyListener(f43: (text: string) => void): this;
    getCodeCopyListener(e43: string): void;
    /**
     * 获取图片-宽度
     * @param imageWidth
     */
    setImageWidth(d43: ResourceStr | number | null): this;
    getImageWidth(): number | ResourceStr;
    /**
     * 设置图片-最大宽度
     * @param imageMaxWidth
     */
    setImageMaxWidth(c43: ResourceStr | number | null): this;
    getImageMaxWidth(): number | ResourceStr;
    /**
     * 获取图片-高度
     * @param imageWidth
     */
    setImageHeight(b43: ResourceStr | number | null): this;
    getImageHeight(): number | ResourceStr;
    /**
     * 设置图片-最大高度
     * @param imageMaxWidth
     */
    setImageMaxHeight(a43: ResourceStr | number | null): this;
    getImageMaxHeight(): number | ResourceStr;
    /**
     * 设置图片-圆角
     * @param radius
     * @version 3.2.2
     */
    setImageBorderRadius(z42: ResourceStr | number): this;
    getImageBorderRadius(): number | ResourceStr;
    /**
     * 设置图片-点击监听
     * @param event
     * @returns
     */
    setImageClickListener(y42: (src: string) => boolean): this;
    getImageClickListener(): (src: string) => boolean;
    /**
     * 设置图片加载代理
     * @param event
     * @returns
     */
    setImageLoadProxy(x42: (src: string) => string): this;
    getImageLoadProxy(w42: string): string;
    /**
     * 设置超链接-文字颜色
     * @param hyperlinkTextColor
     */
    setHyperlinkTextColor(v42: ResourceColor): this;
    getHyperlinkTextColor(): ResourceColor;
    /**
     * 设置超链接-文字字号
     * @param size
     * @version 3.2.2
     */
    setHyperlinkTextSize(u42: ResourceStr | number): this;
    getHyperlinkTextSize(): number | ResourceStr;
    /**
     * 设置超链接-背景颜色
     * @param inlineCodeBackgroundColor
     */
    setHyperlinkBackgroundColor(t42: ResourceColor): this;
    getHyperlinkBackgroundColor(): ResourceColor;
    /**
     * 设置超链接-背景圆角
     * @param radius
     */
    setHyperlinkBackgroundRadius(s42: Dimension): this;
    getHyperlinkBackgroundRadius(): Dimension;
    /**
     * 设置超链接-下划线展示状态
     * @param hyperlinkUnderlineState
     */
    setHyperlinkUnderlineState(r42: boolean): this;
    getHyperlinkUnderlineState(): boolean;
    /**
     * 设置超链接-点击监听
     * @param event
     * @returns
     */
    setHyperlinkClickListener(q42: (title: string, src: string, anchorInfo?: componentUtils.ComponentInfo) => boolean): this;
    getHyperlinkClickListener(): (title: string, src: string, anchorInfo?: componentUtils.ComponentInfo) => boolean;
    /**
     * 设置表格背景色
     * @param tableBackgroundColor
     */
    setTableBackgroundColor(p42: ResourceColor): this;
    getTableBackgroundColor(): ResourceColor;
    /**
     * 设置表格表头文本颜色
     */
    setTableTitleTextColor(o42: ResourceColor): this;
    getTableTitleTextColor(): ResourceColor;
    /**
     * 设置表格-错行文本颜色
     */
    setTableInterleaveTextColor(n42: ResourceColor): void;
    getTableInterleaveTextColor(): ResourceColor;
    /**
     * 设置表格-非错行文本颜色
     */
    setTableNormalTextColor(m42: ResourceColor): void;
    getTableNormalTextColor(): ResourceColor;
    /**
     * 设置表格-表头背景色
     * @param tableTitleBackgroundColor
     */
    setTableTitleBackgroundColor(l42: ResourceColor): this;
    getTableTitleBackgroundColor(): ResourceColor;
    /**
     * 设置表格-错行背景色
     * @param tableInterleaveBackgroundColor
     */
    setTableInterleaveBackgroundColor(k42: ResourceColor): this;
    getTableInterleaveBackgroundColor(): ResourceColor;
    /**
     * 设置表格-圆角
     * @param radius
     * @version 3.2.2
     */
    setTableBorderRadius(j42: ResourceStr | number): this;
    getTableBorderRadius(): number | ResourceStr;
    /**
     * 设置表格-外边框颜色
     * @param color
     * @version 3.2.2
     */
    setTableOuterBorderColor(i42: ResourceColor): this;
    getTableOuterBorderColor(): ResourceColor;
    /**
     * 设置表格-外边框宽度
     * @param width
     * @version 3.2.2
     */
    setTableOuterBorderWidth(h42: ResourceStr | number): this;
    getTableOuterBorderWidth(): number | ResourceStr;
    /**
     * 设置表格-内边框颜色
     * @param color
     * @version 3.2.2
     */
    setTableInnerBorderColor(g42: ResourceColor): this;
    getTableInnerBorderColor(): ResourceColor;
    /**
     * 设置表格-内边框宽度
     * @param width
     * @version 3.2.2
     */
    setTableInnerBorderWidth(f42: ResourceStr | number): this;
    getTableInnerBorderWidth(): number | ResourceStr;
    /**
     * 设置表格-屏幕对齐方式
     * @param flexAlign 对齐方式
     * @version 3.2.2
     */
    setTableAlign(e42: FlexAlign): this;
    getTableAlign(): FlexAlign;
    /**
     * 设置任务列表-选中颜色
     * @param todoSelectedColor
     */
    setTodoSelectedColor(d42: ResourceColor): this;
    getTodoSelectedColor(): ResourceColor;
    /**
     * 设置任务列表-选项大小
     * @param todoSelectSize
     */
    setTodoSelectSize(c42: ResourceStr | number): this;
    getTodoSelectSize(): number | ResourceStr;
    /**
     * 设置无序列表-指示点大小
     * @param size
     * @version 3.2.2
     */
    setUlPointSize(b42: ResourceStr | number): this;
    getUlPointSize(): number | ResourceStr;
    /**
     * 设置无序列表-指示点颜色
     * @param color
     * @version 3.2.2
     */
    setUlPointColor(a42: ResourceColor): this;
    getUlPointColor(): ResourceColor;
    /**
     * 设置脚注-文字颜色
     * @param footnoteTextColor
     */
    setFootnoteTextColor(z41: ResourceColor): this;
    getFootnoteTextColor(): ResourceColor;
    /**
     * 设置分割线-颜色
     * @param lineColor
     * @returns
     */
    setLineColor(y41: ResourceColor): this;
    getLineColor(): ResourceColor;
    /**
     * 设置数学公式-字体大小
     * @param size
     * @returns
     */
    setLatexMathTextSize(x41: number): this;
    getLatexMathTextSize(): number;
    /**
     * 数学公式-字体颜色（十六进制）
     * @param color
     * @returns
     */
    setLatexMathTextColor(w41: number): this;
    getLatexMathTextColor(): number;
    /**
     * 设置数学公式-点击监听
     * @param event
     * @returns
     */
    setLatexClickListener(v41: (text: string, pixelMap: image.PixelMap) => boolean): this;
    getLatexClickListener(): (text: string, pixelMap: image.PixelMap) => boolean;
    /**
     * 设置是否开启 mermaid 渲染
     * @param enable
     */
    setMermaidEnable(u41: boolean): this;
    getMermaidEnable(): boolean;
    /**
     * 设置 Mermaid 深浅色主题
     * @param theme
     */
    setMermaidTheme(t41: CodeTheme): this;
    getMermaidTheme(): CodeTheme;
    /**
     * 设置 Mermaid 预览安全级别
     * @param securityLevel
     */
    setMermaidSecurityLevel(s41: MermaidSecurityLevel): this;
    getMermaidSecurityLevel(): MermaidSecurityLevel;
    /**
     * 设置是否开启线程加载模式（默认开启）
     * @param enable
     */
    setThreadRenderEnable(r41: boolean): this;
    getThreadRenderEnable(): boolean;
    /**
     * 设置是否开启 Setext 标题解析
     * @description 默认 false。开启后，文本下方的 ===== 或 ----- 会解析为一级或二级标题。
     * @param enable
     */
    setSetextHeadingEnable(q41: boolean): this;
    getSetextHeadingEnable(): boolean;
    /**
     * 设置是否开启可见区域懒渲染
     * @description 默认 false。开启后屏幕外块先以轻量占位渲染，进入可见区域附近后再渲染真实内容。
     * @param enable
     */
    setLazyRender(p41: boolean): this;
    getLazyRender(): boolean;
    /**
     * 设置懒渲染预渲染块数量
     * @description 默认 3。实际渲染会按内部懒渲染分组折算。
     * @param count
     */
    setLazyPreloadBlockCount(o41: number): this;
    getLazyPreloadBlockCount(): number;
    /**
     * 设置剪贴板复制范围选项
     * @description 默认 CopyOptions.LocalDevice（支持复制后在所有应用内粘贴）。从 3.3.1 版本开始，该接口不再维护，调用后不再生效，请使用 setTextSelectionEnable() 与 setTextSelectionEnable() 实现文本选择复制功能。
     * @param copyOption
     * @deprecated 3.3.1
     */
    setCopyOption(n41: CopyOptions): void;
    getCopyOption(): CopyOptions;
    /**
     * 设置是否开启跨 Text 文本选择能力
     * @description 默认 false
     * @param enable
     * @version 3.3.2
     */
    setTextSelectionEnable(m41: boolean): this;
    getTextSelectionEnable(): boolean;
    /**
     * 设置跨 Text 文本选择复制监听
     * @param event
     * @version 3.3.2
     */
    setTextSelectionCopyListener(l41: (text: string) => void): this;
    getTextSelectionCopyListener(): (text: string) => void;
    /**
     * 设置块级元素间距
     * @description 默认 10vp。
     * @param copyOption
     * @version 3.3.0
     */
    setBlockSpacing(k41: number | ResourceStr): void;
    getBlockSpacing(): number | ResourceStr;
}

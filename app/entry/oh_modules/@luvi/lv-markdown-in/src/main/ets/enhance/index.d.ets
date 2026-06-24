// @keepTs
// @ts-nocheck
import { MarkdownController } from './controller/MarkdonwController';
import { MarkdownPlugin } from './model/MarkdownPlugin';
import { MdCallback } from './model/MdCallback';
/**
 * 承载 Markdown 内容渲染的组件。
 *
 * @controller 通过 MarkdownController 可以控制 Markdown 组件各种行为，如：自定义样式、设置图片点击拦截、设置超链接点击拦截等。
 * @text markdown 文本内容。
 * @mode Markdown 组件加载模式，支持纯文本加载、沙箱文件加载、资源文件加载，不填默认为 "text"。
 * @context mode 字段设置为 rawfile 时， context 为必填项。
 * @rawfilePath mode 字段设置为 rawfile 时， rawfilePath 为必填项，需传入 resources/rawfile 目录下对应的 rawfile 文件路径。
 * @sandboxPath mode 字段设置为 sandbox 时， sandboxPath 为必填项，需传入沙箱 text/md 文件的完整沙箱路径。例：getContext().getApplicationContext().filesDir + "/t2/text.md"。
 * @call callback回调方法，Markdown 组件加载状态结果告知。用于组件加载完成时，组件加载失败时回调，并返回错误码 code，错误信息 message，可用于问题分析。
 */
@Component
export declare struct Markdown {
    controller: MarkdownController;
    @Provide
    markdownUnion: string;
    @Provide
    selectionUnion: string;
    @Provide
    pluginUnion: string;
    /** 纯文本数据，mode：text */
    @Prop
    text: string;
    plugins: MarkdownPlugin[];
    /** 加载模式：
     * text：纯文本模式
     * rawfile：rawfile资源文件模式
     * sandbox：本地沙箱路径文件模式
     */
    @Prop
    mode: "text" | "rawfile" | "sandbox";
    /**
     * 资源文件path
     */
    @Prop
    rawfilePath: string;
    /**
     * 沙箱文件path
     */
    @Prop
    sandboxPath: string;
    /**
     * 应用上下文
     */
    context: Context | undefined;
    /**
     * 增强node集合
     */
    @State
    private treeNode;
    private startCaretInfo;
    private endCaretInfo;
    @State
    private selectedTextInfos;
    @State
    private selectionActive;
    @State
    private selectionActionBarVisible;
    @State
    private startCaretX;
    @State
    private startCaretY;
    @State
    private endCaretX;
    @State
    private endCaretY;
    private selectedRangeStartOrder;
    private selectedRangeEndOrder;
    private lastSelectionUpdateTime;
    private readonly selectionUpdateInterval;
    private readonly selectionVisualSyncInterval;
    private readonly initialSelectionLength;
    private readonly selectionActionBarWidth;
    private readonly selectionActionBarHeight;
    private readonly selectionActionBarSpacing;
    private readonly selectionActionBarEdgeInset;
    private selectionVisualSyncTimer;
    private lastSelectionRootScreenX;
    private lastSelectionRootScreenY;
    private workerManager;
    private workerUnion;
    private workerRegistered;
    private selectionRootId;
    private selectionSettings;
    private selectionContext;
    private rectRangeCache;
    @State
    private selectionLayerWidth;
    @State
    private selectionLayerHeight;
    /**
     * 事件回调
     */
    callback: MdCallback;
    private baseCallback;
    aboutToAppear(): void;
    aboutToDisappear(): void;
    private clearSelection;
    private shouldUseLazyRender;
    private registerPlugins;
    private ensureWorkerRegistered;
    private handleWorkerMessage;
    private collectLatexTexts;
    private preloadTreeLatex;
    private applyTreeNode;
    private renderTreeNodeWithLatex;
    private handleLodeType;
    private _loadRawfile;
    private _loadSandbox;
    private _parseMarkdown;
    private getTextIndex;
    private getLayoutTextLength;
    private getRectsForRange;
    private loadRectsForRange;
    private getCaretInfo;
    private buildSelectedTextInfo;
    private rebuildSelectedTextInfos;
    private updateSelectedTextInfoAtOrder;
    private refreshSelectedTextInfosComponentInfo;
    private hasSelectionGeometryChanged;
    private startSelectionVisualSync;
    private stopSelectionVisualSync;
    private collectSelectedTextInfos;
    private updateCaretPositions;
    private updateSelectionByOrderedCaret;
    private paintSelection;
    private startSelection;
    private updateCaretByGesture;
    private triggerTextSelectionCopy;
    private triggerTextSelectionSelectAll;
    private showSelectionActionBar;
    private hideSelectionActionBar;
    private getSelectionBounds;
    private getSelectionActionBarPosition;
    private refreshSelectionVisuals;
    private updateSelectionLayerSize;
    private selectionActionItem;
    private selectionActionBar;
    build(): void;
}

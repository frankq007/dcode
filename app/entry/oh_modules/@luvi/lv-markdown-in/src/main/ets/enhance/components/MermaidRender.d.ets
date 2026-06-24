// @keepTs
// @ts-nocheck
import { CodeBlockNode } from '../model/TreeNode';
type MermaidTab = "preview" | "code";
@Component
export declare struct MermaidRender {
    @Consume
    markdownUnion: string;
    @State
    base: CodeBlockNode | undefined;
    @State
    loading: boolean;
    @State
    activeTab: MermaidTab;
    @State
    previewLoading: boolean;
    @State
    previewSrc: string;
    @State
    previewError: string;
    @State
    themeVersion: number;
    controller: WebviewController;
    private previewFilePath;
    private previewQueued;
    private componentAlive;
    private previewVersion;
    aboutToAppear(): void;
    aboutToDisappear(): void;
    private mermaidThemeChangeListener;
    private getRenderTheme;
    private isDarkTheme;
    private getActiveTabBackgroundColor;
    private getTabTextColor;
    private getLoadingColor;
    private resolveMermaidTheme;
    private enqueueInlinePreview;
    private loadInlinePreview;
    private writeHtmlToCache;
    private openPreview;
    build(): void;
}
export {};

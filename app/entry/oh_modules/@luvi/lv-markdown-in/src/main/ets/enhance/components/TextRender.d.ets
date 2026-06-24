// @keepTs
// @ts-nocheck
import { TreeNode } from '../model/TreeNode';
@Component
export declare struct TextRender {
    @Consume
    markdownUnion: string;
    @Consume
    selectionUnion: string;
    @Consume
    pluginUnion: string;
    @State
    base: TreeNode | undefined;
    @State
    private inlinePluginPlacements;
    @State
    private inlinePluginRects;
    private textController;
    private selectionId;
    private inlinePluginRefreshTimer;
    aboutToAppear(): void;
    private prepareInlinePluginPlacements;
    private refreshInlinePluginRects;
    private refreshInlinePluginRectsSoon;
    private clearInlinePluginRefreshTimer;
    private handleTextAreaChange;
    private syncSelectionBlock;
    build(): void;
}

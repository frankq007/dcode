// @keepTs
// @ts-nocheck
import { TreeNode } from '../model/TreeNode';
@Component
export declare struct ParagraphRender {
    @Consume
    markdownUnion: string;
    @Consume
    selectionUnion: string;
    @Consume
    pluginUnion: string;
    @State
    base: TreeNode | undefined;
    @State
    private latexRefreshTick;
    @State
    private inlinePluginPlacements;
    @State
    private inlinePluginRects;
    private latexLoadingSet;
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
    private collectLatexNodes;
    private loadParagraphLatex;
    private hasLatexNode;
    private getParagraphLineHeight;
    build(): void;
}

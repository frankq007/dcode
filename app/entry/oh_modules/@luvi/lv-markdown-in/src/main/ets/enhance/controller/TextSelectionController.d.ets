// @keepTs
// @ts-nocheck
import componentUtils from "@ohos.arkui.componentUtils";
import { BlockHitInfo, BlockSelectionStartInfo, RegisteredTextBlock, TextSelectionSegment } from '../model/TextSelectionInfo';
export declare class TextSelectionController {
    private static controllerMap;
    private static activeMarkdownUnion?;
    private markdownUnion;
    private blocks;
    private orderedBlocksCache;
    private blockRectCache;
    private layoutCacheValid;
    private nextOrder;
    private readonly HIT_SLOP;
    private startSelectionHandler?;
    private clearSelectionHandler?;
    private constructor();
    static getInstance(j47: string): TextSelectionController;
    static destroy(i47: string): void;
    registerBlock(b47: string, c47: TextController, d47: TextSelectionSegment[]): void;
    unregisterBlock(a47: string): void;
    clear(): void;
    setStartSelectionHandler(z46?: (info: BlockSelectionStartInfo) => void): void;
    setClearSelectionHandler(y46?: () => void): void;
    releaseActiveSelection(): void;
    triggerStartSelection(w46: BlockSelectionStartInfo): void;
    getOrderedBlocks(): RegisteredTextBlock[];
    private refreshLayoutSnapshot;
    getBlockByOrder(m46: number): RegisteredTextBlock | undefined;
    getBlockById(l46: string): RegisteredTextBlock | undefined;
    getBlockInfoByPoint(a46: number, b46: number): BlockHitInfo | undefined;
    getBlockRect(x45: string, y45?: boolean): componentUtils.ComponentInfo | undefined;
    invalidateLayoutCache(): void;
    private refreshBlockRects;
    private loadBlockRect;
    buildCopyText(e45: number, f45: number, g45: number, h45: number): string;
    private extractBlockCopyText;
}

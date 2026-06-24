// @keepTs
// @ts-nocheck
import common2D from "@ohos.graphics.common2D";
import { InlinePluginLayout } from '../model/MarkdownPlugin';
import { PluginNode, TreeNode } from '../model/TreeNode';
export declare class InlinePluginPlacement {
    node: PluginNode;
    start: number;
    end: number;
    layout: InlinePluginLayout;
    constructor(i90: PluginNode, j90: number, k90: number, l90: InlinePluginLayout);
}
export declare class InlinePluginRect {
    node: PluginNode;
    start: number;
    end: number;
    left: number;
    top: number;
    width: number;
    height: number;
    constructor(g90: InlinePluginPlacement, h90: common2D.Rect);
}
export declare function isSameInlinePluginRects(d90: InlinePluginRect[], e90: InlinePluginRect[]): boolean;
export declare function buildParagraphInlinePluginPlacements(v88: string, w88: string, x88: TreeNode | undefined): InlinePluginPlacement[];
export declare function buildTextInlinePluginPlacements(r88: string, s88: string, t88: TreeNode | undefined): InlinePluginPlacement[];
export declare function buildInlinePluginRects(i88: TextController, j88: InlinePluginPlacement[], k88: UIContext): InlinePluginRect[];

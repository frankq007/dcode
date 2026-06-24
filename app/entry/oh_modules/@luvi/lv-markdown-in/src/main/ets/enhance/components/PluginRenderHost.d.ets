// @keepTs
// @ts-nocheck
import { InlinePluginLayout } from '../model/MarkdownPlugin';
import { PluginNode } from '../model/TreeNode';
@Component
export declare struct PluginBlockRenderHost {
    @Prop
    node: PluginNode;
    @BuilderParam
    renderer: (node: PluginNode) => void;
    build(): void;
}
@Component
export declare struct PluginInlineRenderHost {
    @Prop
    node: PluginNode;
    @BuilderParam
    renderer: (node: PluginNode) => void;
    build(): void;
}
export declare function getPluginRenderer(v27: string, w27: PluginNode): ((node: PluginNode) => void) | undefined;
export declare function getPluginInlineLayout(s27: string, t27: PluginNode): InlinePluginLayout | undefined;
export declare function hasPluginInlineOverlay(q27: string, r27: PluginNode): boolean;
export declare function getPluginInlinePlaceholderWidth(o27: string, p27: PluginNode): number;
export declare function getPluginInlinePlaceholderHeight(m27: string, n27: PluginNode): number;
@Builder
export declare function PluginInlinePlaceholderSpan(d27: string, e27: PluginNode): void;

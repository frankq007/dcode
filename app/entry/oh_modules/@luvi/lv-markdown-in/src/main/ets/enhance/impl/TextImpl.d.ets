// @keepTs
// @ts-nocheck
import { BaseNode, FootnoteRefNode, LinkNode, TextNode, TreeNode } from '../model/TreeNode';
export declare namespace TextImpl {
    function handleFontColor(q58: string, r58: ESObject, s58?: TreeNode | undefined): ResourceColor;
    function handleBackgroundColor(o58: string, p58: ESObject): ResourceColor;
    function handleBackgroundRadius(l58: string, m58: ESObject): Dimension;
    function handleDecoration(j58: string, k58: ESObject): DecorationStyleInterface;
    function handleText(h58: string, i58: TreeNode | TextNode | FootnoteRefNode | LinkNode): string;
    function handleFontWeight(d58: string, e58: ESObject, f58?: TreeNode | undefined): FontWeight | null;
    function handleFontStyle(z57: string, a58: ESObject, b58?: TreeNode | undefined): FontStyle;
    function handleLineHeight(w57: string, x57?: TreeNode): ResourceStr | number;
    function handleFontSize(q57: string, r57?: BaseNode | undefined, s57?: TreeNode | undefined): number | ResourceStr;
    function handleFontFamily(l57: string, m57?: BaseNode | undefined, n57?: TreeNode | undefined): ResourceStr;
    function handleClick(c57: string, d57: ESObject): void;
    function handleSpanId(y56: string, z56: ESObject): string;
    function handleCopyOption(v56: string): CopyOptions;
}

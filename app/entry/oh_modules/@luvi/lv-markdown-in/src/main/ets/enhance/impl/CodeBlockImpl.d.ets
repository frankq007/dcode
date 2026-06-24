// @keepTs
// @ts-nocheck
import { CodeTheme } from '../constant/CodeTheme';
import { TreeNode } from '../model/TreeNode';
export declare namespace CodeBlockImpl {
    function handleBackgroundColor(z54: CodeTheme): "#181A1F" | "#F9FAFB";
    function handleThemeChange(x54: string, y54: CodeTheme): void;
    function copyText(v54: string, w54: string): Promise<void>;
    function handleCodeBlockBorderRadius(u54: string): number | ResourceStr;
    function handleCodeHighlight(s54: string, t54: CodeTheme): void;
    function setExtend(p54: TreeNode, ...q54: [
        string,
        ESObject
    ][]): void;
}

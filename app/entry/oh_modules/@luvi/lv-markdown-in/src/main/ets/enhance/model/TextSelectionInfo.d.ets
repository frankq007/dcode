// @keepTs
// @ts-nocheck
import common2D from "@ohos.graphics.common2D";
import componentUtils from "@ohos.arkui.componentUtils";
export declare class TextSelectionSegment {
    renderedLength: number;
    copyText: string;
    constructor(x74: number, y74: string);
}
export declare class RegisteredTextBlock {
    id: string;
    order: number;
    controller: TextController;
    segments: TextSelectionSegment[];
    renderedLength: number;
    constructor(r74: string, s74: number, t74: TextController, u74: TextSelectionSegment[]);
}
export declare class SelectedTextInfo {
    block: RegisteredTextBlock;
    componentInfo: componentUtils.ComponentInfo;
    rects: common2D.Rect[];
    startIndex: number;
    endIndex: number;
    constructor(m74: RegisteredTextBlock, n74: componentUtils.ComponentInfo, o74: common2D.Rect[], p74: number, q74: number);
    getCaretPosition(h74: componentUtils.ComponentInfo, i74?: boolean): Position | undefined;
}
export declare class BlockHitInfo {
    block: RegisteredTextBlock;
    info: componentUtils.ComponentInfo;
    constructor(f74: RegisteredTextBlock, g74: componentUtils.ComponentInfo);
}
export declare class BlockSelectionStartInfo {
    blockId: string;
    localX: number;
    localY: number;
    constructor(c74: string, d74: number, e74: number);
}
export declare class CaretInfo {
    blockOrder: number;
    caretIndex: number;
    lessThan(b74: CaretInfo): boolean;
    reset(): void;
}

// @keepTs
// @ts-nocheck
export type WebDialogMode = "url" | "html" | "text";
export declare class WebDialogController {
    private static instance;
    private baseContentNode;
    title: string;
    src: string;
    mode: WebDialogMode;
    /**
     * 打开模态框
     */
    openBindSheet(t47: string, u47: string): Promise<void>;
    openHtmlBindSheet(r47: string, s47: string): Promise<void>;
    openTextBindSheet(p47: string, q47: string): Promise<void>;
    private openSheet;
    /**
     * 关闭模态弹窗
     */
    closeBindSheet(): Promise<void>;
    static getInstance(): WebDialogController;
}

// @keepTs
// @ts-nocheck
export declare class CodeDialogController {
    private static instance;
    private baseContentNode;
    markdownUnion: string;
    lang: string;
    text: string;
    openBindSheet(y40: string, z40: string, a41: string): Promise<void>;
    closeBindSheet(): Promise<void>;
    static getInstance(): CodeDialogController;
}

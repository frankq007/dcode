// @keepTs
// @ts-nocheck
import { HighlightNode } from '../model/highlightNode';
import { CodeBlockNode } from '../model/TreeNode';
@Component
export declare struct CodeRender {
    @Consume
    markdownUnion: string;
    @State
    base: CodeBlockNode | undefined;
    @State
    highlightNode: HighlightNode[];
    @State
    MAX_ROWS: number;
    BASE_ROWS: number;
    aboutToAppear(): void;
    aboutToDisappear(): void;
    codeThemeChangeListener(): void;
    getHighlightNode(): void;
    showMore(): void;
    private openCodeDialog;
    private isMermaidCodeBlock;
    build(): void;
}

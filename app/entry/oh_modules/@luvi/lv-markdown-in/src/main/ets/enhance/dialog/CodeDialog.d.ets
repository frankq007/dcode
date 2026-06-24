// @keepTs
// @ts-nocheck
import { HighlightNode } from '../model/highlightNode';
@Builder
export declare function CodeDialogBuilder(): void;
@Component
export declare struct CodeDialog {
    @State
    highlightNode: HighlightNode[];
    aboutToAppear(): void;
    private getMarkdownUnion;
    private isDarkTheme;
    private getHighlightNode;
    build(): void;
}

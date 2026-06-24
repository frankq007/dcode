// @keepTs
// @ts-nocheck
@Component
export declare struct lvTableComponent {
    @State
    text: string;
    @State
    dialogController: CustomDialogController | null;
    @State
    cellWidthArrayIndexed: number[];
    build(): void;
    @Builder
    lvTableHeadBuilder(v118: string, w118: CustomDialogController | null): void;
    @Builder
    lvTableRowBuilder(a118: string, b118: number, c118: CustomDialogController | null): void;
}

// @keepTs
// @ts-nocheck
@Observed
declare class LvText {
    private textSize;
    private textColor;
    private textMarkBackground;
    private textLineHeight;
    setTextSize(e96: number | string): void;
    setTextColor(d96: string): void;
    setTextMarkBackground(c96: string): void;
    setTextLineHeight(b96: string): void;
    getTextSize(): number | string;
    getTextColor(): string;
    getTextMarkBackground(): string;
    getTextLineHeight(): string | number;
}
declare const lvText: LvText;
export { lvText, LvText };

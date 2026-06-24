// @keepTs
// @ts-nocheck
@Observed
declare class LvLink {
    private textSize;
    private textColor;
    private textUnderline;
    private linkUrl;
    setTextSize(y95: number | string): void;
    setTextColor(x95: string): void;
    setTextUnderline(w95: boolean): void;
    setLinkUrl(v95: string): void;
    getTextSize(): number | string;
    getTextColor(): string;
    getTextUnderline(): boolean;
    getLinkUrl(): string;
}
declare const lvLink: LvLink;
export { lvLink, LvLink };

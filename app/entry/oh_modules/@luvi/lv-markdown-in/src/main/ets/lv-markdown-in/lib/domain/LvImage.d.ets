// @keepTs
// @ts-nocheck
@Observed
declare class LvImage {
    private imgWidth;
    private imgHeight;
    private confGlobal;
    private imgUrl;
    setImgWidth(u95: string): void;
    setImgHeight(t95: string): void;
    setConfGlobal(s95: boolean): void;
    setImgUrl(r95: string): void;
    getImgWidth(): number | string;
    getImgHeight(): number | string | null;
    getConfGlobal(): boolean;
    getImgUrl(): string;
}
declare const lvImage: LvImage;
export { lvImage, LvImage };

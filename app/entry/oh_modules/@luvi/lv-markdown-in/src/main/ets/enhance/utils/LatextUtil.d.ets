// @keepTs
// @ts-nocheck
import image from "@ohos.multimedia.image";
export interface LatexInfo {
    pixelMap: image.PixelMap;
    width: number;
    height: number;
}
export declare namespace LatexUtil {
    function latexToPixelMap(r90: string, s90: number, t90: number, u90: UIContext): Promise<LatexInfo>;
    function getCachedLatex(o90: string, p90: number, q90: number): LatexInfo | undefined;
    function clearCache(): void;
}

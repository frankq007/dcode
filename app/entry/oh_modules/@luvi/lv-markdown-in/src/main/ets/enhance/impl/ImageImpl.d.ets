// @keepTs
// @ts-nocheck
import { ImageNode } from '../model/TreeNode';
export declare namespace ImageImpl {
    function handleImageSrc(s55: string, t55?: string): ResourceStr;
    function handleRawfileImage(o55?: string): Resource | "";
    function handleClick(l55: string, m55: string): void;
    function handleImageWidth(j55: string, k55?: ImageNode): number | ResourceStr | null;
    function handleImageMaxWidth(h55: string, i55?: ImageNode): number | ResourceStr | null;
    function handleImageHeight(f55: string, g55?: ImageNode): number | ResourceStr | null;
    function handleImageMaxHeight(d55: string, e55?: ImageNode): number | ResourceStr | null;
    function handleImageBorderRadius(c55: string): number | ResourceStr;
}

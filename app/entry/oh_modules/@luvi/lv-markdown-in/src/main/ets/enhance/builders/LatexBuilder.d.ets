// @keepTs
// @ts-nocheck
import { LatexInfo } from '../utils/LatextUtil';
export declare function getLatexText(b2: ESObject): string;
export declare function preloadLatexImage(y1: string, z1: string, a2: UIContext): Promise<void>;
export declare function getCachedLatexImage(w1: string, x1: string): LatexInfo | undefined;
@Builder
export declare function LatexBlockSpanBuilder(n1: string, o1: string, p1: LatexInfo, q1: UIContext): void;
@Builder
export declare function LatexInlineSpanBuilder(i1: string, j1: string, k1: LatexInfo, l1: UIContext): void;
@Builder
export declare function LatexTextFallbackSpanBuilder(c1: string): void;
@Builder
export declare function LatexImageSpanBuilder(v: string, w: string, x: LatexInfo, y: UIContext): void;

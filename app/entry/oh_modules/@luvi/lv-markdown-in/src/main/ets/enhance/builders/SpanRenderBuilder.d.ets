// @keepTs
// @ts-nocheck
import { TreeNode } from '../model/TreeNode';
/**
 * ParagraphRender need use
 * @param data
 */
@Builder
export declare function SpanRenderBuilder(n2: string, o2: string, p2: ESObject, q2: UIContext, r2?: number): void;
/**
 * 根文本渲染
 * @param data 节点数据
 * @param baseType 根节点类型
 */
@Builder
export declare function BaseSpanRenderBuilder(f2: string, g2: ESObject, h2?: TreeNode): void;

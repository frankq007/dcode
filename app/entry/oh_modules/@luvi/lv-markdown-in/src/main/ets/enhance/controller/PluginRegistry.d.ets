// @keepTs
// @ts-nocheck
import { MarkdownPlugin } from '../model/MarkdownPlugin';
export declare class MarkdownPluginRegistry {
    private static pluginMap;
    static registerPlugins(n44: string, o44: MarkdownPlugin[]): void;
    static getPlugin(l44: string, m44: string): MarkdownPlugin | undefined;
    static destroy(k44: string): void;
}

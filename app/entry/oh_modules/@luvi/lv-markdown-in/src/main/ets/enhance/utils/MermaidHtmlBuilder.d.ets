// @keepTs
// @ts-nocheck
import { CodeTheme } from '../constant/CodeTheme';
export type MermaidTheme = "default" | "dark" | "forest" | "neutral";
export type MermaidSecurityLevel = "strict" | "loose" | "antiscript" | "sandbox";
export declare function buildMermaidHtml(e93: Context, f93: string, g93: MermaidTheme, h93: MermaidSecurityLevel, i93?: CodeTheme): Promise<string>;
export declare function buildMermaidMissingHtml(y92?: CodeTheme): string;

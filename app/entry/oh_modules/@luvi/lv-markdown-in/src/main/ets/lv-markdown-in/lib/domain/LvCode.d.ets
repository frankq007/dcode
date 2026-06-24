// @keepTs
// @ts-nocheck
type Theme = "light" | "dark";
@Observed
declare class LvCode {
    private theme;
    private indexState;
    setTheme(q95: Theme): void;
    setIndexState(p95: boolean): void;
    getTheme(): string;
    getIndexState(): boolean;
}
declare const lvCode: LvCode;
export { lvCode, LvCode };

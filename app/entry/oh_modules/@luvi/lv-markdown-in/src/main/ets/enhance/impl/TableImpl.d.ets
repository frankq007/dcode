// @keepTs
// @ts-nocheck
export declare namespace TableImpl {
    let tableWidthsList: number[][];
    let tableWidthsUnionList: string[];
    function handleTableBackgroundColor(t56: string): ResourceColor;
    function handleTableTitleBackgroundColor(s56: string): ResourceColor;
    function handleTableTitleTextColor(r56: string): ResourceColor;
    function handleTableInterleaveTextColor(q56: string): ResourceColor;
    function handleTableNormalTextColor(p56: string): ResourceColor;
    function handleTableInterleaveBackgroundColor(o56: string): ResourceColor;
    function handleTableBorderRadius(n56: string): ResourceStr | number;
    function handleTableOuterBorderColor(m56: string): ResourceColor | null;
    function handleTableOuterBorderWidth(l56: string): ResourceStr | number;
    function handleTableInnerBorderColor(k56: string): ResourceColor | null;
    function handleTableInnerBorderWidth(j56: string): ResourceStr | number;
    function handleTableAlign(i56: string): FlexAlign;
    function handleTextAlign(h56: "none" | "left" | "center" | "right" | string | undefined): HorizontalAlign;
}

// @keepTs
// @ts-nocheck
@ObservedV2
export declare class ScreenUtil {
    private static instance;
    private notificationBarHeight;
    private navigationBarHeight;
    windowBreakPoint: string;
    setNotificationBarHeight(l94: number): void;
    setNavigationBarHeight(k94: number): void;
    getNotificationBarHeight(): number;
    getNavigationBarHeight(): number;
    getScreenHeight(): number;
    getScreenWidth(): number;
    /**
     * 检查是否是大屏设备
     * @returns
     */
    checkIsLargeScreen(): boolean;
    init(): Promise<void>;
    static getInstance(): ScreenUtil;
}

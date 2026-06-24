// @keepTs
// @ts-nocheck
/**
 * 日志级别枚举
 */
export declare enum LogLevel {
    DEBUG = 3,
    INFO = 4,
    WARN = 5,
    ERROR = 6,
    FATAL = 7
}
/**
 * HiLog工具类 - 支持长日志换行、多级别日志和强制打印
 */
export declare class LogUtil {
    private static MAX_LOG_LENGTH;
    private isForcePrint;
    /**
     * 打印DEBUG级别日志 - 支持多参数
     * @param tag 日志标签
     * @param messages 日志内容参数列表   */
    debug(w92: string, ...x92: ESObject[]): void;
    /**
     * 打印INFO级别日志 - 支持多参数
     * @param tag 日志标签
     * @param messages 日志内容参数列表
     */
    info(u92: string, ...v92: ESObject[]): void;
    /**
     * 打印WARN级别日志 - 支持多参数
     * @param tag 日志标签
     * @param messages 日志内容参数列表
     */
    warn(s92: string, ...t92: ESObject[]): void;
    /**
     * 打印ERROR级别日志 - 支持多参数
     * @param tag 日志标签
     * @param messages 日志内容参数列表
     */
    error(q92: string, ...r92: ESObject[]): void;
    /**
     * 打印FATAL级别日志 - 支持多参数
     * @param tag 日志标签
     * @param messages 日志内容参数列表
     */
    fatal(o92: string, ...p92: ESObject[]): void;
    /**
     * 强制打印日志（无视release环境限制）- 支持多参数
     * @param tag 日志标签
     * @param messages 日志内容参数列表
     */
    infoForce(m92: string, ...n92: ESObject[]): void;
    /**
     * 强制打印日志（无视release环境限制）- 支持多参数
     * @param tag 日志标签
     * @param messages 日志内容参数列表
     */
    errorForce(k92: string, ...l92: ESObject[]): void;
    /**
     * 核心日志打印方法
     * @param level 日志级别
     * @param tag 日志标签
     * @param messages 日志内容参数列表
     * @param force 是否强制打印
     */
    private printLog;
    /**
     * 将多个参数格式化为单个日志字符串
     * @param messages 参数列表
     */
    private formatMessages;
    /**
     * 打印单条日志
     * @param level 日志级别
     * @param tag 日志标签
     * @param message 日志内容
     */
    private printSingleLog;
    /**
     * 获取调用者信息
     * @returns 调用者类名和方法名
     */
    private getCallerInfo;
    setDebugState(j91: boolean): void;
}
export declare const Logger: LogUtil;

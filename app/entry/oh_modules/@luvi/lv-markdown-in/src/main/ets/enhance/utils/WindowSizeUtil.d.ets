// @keepTs
// @ts-nocheck
import window from "@ohos.window";
/**
 * Animate the execution of a function
 * @param fn：Callback functions to be executed within the animation, usually fn will change the state variable
 * @param duration：Animation duration
 * @param curve：Animation area line
 */
export declare function runWithAnimation(c95: Function, d95?: number, // Scale the duration of the animation
e95?: Curve): void;
declare class WindowSizeManager {
    private size;
    constructor();
    get(): window.Size;
}
export declare const windowSizeManager: WindowSizeManager;
export {};

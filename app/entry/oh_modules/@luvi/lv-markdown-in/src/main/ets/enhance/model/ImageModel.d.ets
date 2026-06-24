// @keepTs
// @ts-nocheck
import matrix4 from "@ohos.matrix4";
import window from "@ohos.window";
import image from "@ohos.multimedia.image";
@Observed
export declare class ImageModel {
    matrix: matrix4.Matrix4Transit;
    curScale: number;
    curOffsetX: number;
    curOffsetY: number;
    lastScale: number;
    lastOffsetX: number;
    lastOffsetY: number;
    minScale: number;
    maxScale: number;
    defaultScaleValue: number;
    maxOffsetX: number;
    minOffsetX: number;
    maxOffsetY: number;
    minOffsetY: number;
    centerX: number;
    centerY: number;
    center: number[];
    componentHeight: number;
    componentWidth: number;
    imageWidth: number;
    imageHeight: number | undefined;
    isDisableSwipe: boolean;
    constructor(c73?: matrix4.Matrix4Transit, d73?: number, e73?: number, f73?: number, g73?: number, h73?: number, i73?: number, j73?: number, k73?: number, l73?: number, m73?: number, n73?: number, o73?: number, p73?: number, q73?: number, r73?: number, s73?: [
        number,
        number
    ], t73?: number, u73?: number, v73?: number, w73?: number | undefined, x73?: boolean);
    gestureEnd(): void;
    imageReset(): void;
    offsetReset(): void;
    windowSize(): void;
    pictureScaling(y72: number): void;
    evaluateOffsetRange(): void;
    evaluateCenter(q72: number, r72: number): [
        number,
        number
    ];
    calcFitScaleRatio(n72: image.Size, o72: window.Size): number;
    panGestureUpdate(m72: GestureEvent): boolean;
    pinchGestureStart(l72: GestureEvent): void;
    pictureBoundaryRestriction(): void;
    pinchGestureUpdate(k72: GestureEvent): boolean;
    pinchGestureEnd(): void;
    doubleTapGesture(i72: GestureEvent): boolean;
    onScale(f72: number, g72: number, h72: number): void;
}
/**
 * Status bar title and icon.
 */
export declare class ImageInfo {
    icon?: Resource;
    name?: Resource;
    constructor(d72: Resource, e72: Resource);
}

// @keepTs
// @ts-nocheck
import { WorkerParam, WorkerParseReq, WorkerStringResp, WorkerTreeNodeResp } from '../model/WorkerParam';
type WorkerMessage = WorkerTreeNodeResp | WorkerStringResp;
type WorkerTask = WorkerParam | WorkerStringResp | WorkerParseReq;
type WorkerListener = (message: WorkerMessage) => void;
export declare class WorkerManager {
    private static instance;
    private workerInstance;
    private listeners;
    private workerCloseTimer;
    private readonly WORKER_IDLE_TIME;
    private constructor();
    static getInstance(): WorkerManager;
    register(n95: string, o95: WorkerListener): void;
    unregister(m95: string): void;
    postMessage(l95: WorkerTask): void;
    private ensureWorkerAlive;
    private createWorker;
    private clearCloseTimer;
    private resetWorkerCloseTimer;
    private terminateWorker;
}
export {};

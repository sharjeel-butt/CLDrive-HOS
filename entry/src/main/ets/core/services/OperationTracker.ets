import {
  Operation,
  OperationStatus,
  OperationType,
  OperationItemKind,
  RetryPayload,
  createOperation,
  isActiveStatus,
  isFinishedStatus
} from '../models/Operation';
import { OperationStore } from './OperationStore';
import { Logger } from '../../utils/Logger';

const TAG: string = 'OperationTracker';

type Listener = (ops: Operation[]) => void;

export class OperationTracker {
  private static instance: OperationTracker = new OperationTracker();

  private operations: Operation[] = [];
  private listeners: Listener[] = [];
  private nextId: number = 1;

  private static readonly MAX_FINISHED = 500;
  private static readonly SAVE_DEBOUNCE_MS: number = 400;

  private saveTimerId: number = -1;

  static get(): OperationTracker {
    return OperationTracker.instance;
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /**
   * Load persisted task history. Call once during app startup, before
   * any UI subscribes.
   */
  async loadPersisted(): Promise<void> {
    try {
      const saved: Operation[] = await OperationStore.load();
      this.operations = saved;
      this.notify();
      Logger.info(TAG, `Loaded ${saved.length} persisted task(s).`);
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `loadPersisted failed: ${err.message}`);
    }
  }

  /**
   * Debounced save. Multiple rapid mutations coalesce into a single
   * disk write, so progress updates during downloads don't thrash the
   * preferences store.
   */
  private scheduleSave(): void {
    if (this.saveTimerId >= 0) {
      clearTimeout(this.saveTimerId);
    }
    this.saveTimerId = setTimeout(() => {
      this.saveTimerId = -1;
      OperationStore.save(this.operations)
        .catch((e: Error) => {
          Logger.warn(TAG, `save failed: ${e.message}`);
        });
    }, OperationTracker.SAVE_DEBOUNCE_MS);
  }

  // ---------------------------------------------------------------------------
  // Subscription
  // ---------------------------------------------------------------------------

  subscribe(listener: Listener): void {
    this.listeners.push(listener);
    listener(this.operations.slice());
  }

  unsubscribe(listener: Listener): void {
    const idx: number = this.listeners.indexOf(listener);
    if (idx >= 0) {
      const next: Listener[] = this.listeners.slice();
      next.splice(idx, 1);
      this.listeners = next;
    }
  }

  private notify(): void {
    const snapshot: Operation[] = this.operations.slice();
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i](snapshot);
    }
    this.scheduleSave();
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  getAll(): Operation[] {
    return this.operations.slice();
  }

  getById(id: string): Operation | null {
    for (let i = 0; i < this.operations.length; i++) {
      if (this.operations[i].id === id) return this.operations[i];
    }
    return null;
  }

  activeCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.operations.length; i++) {
      if (isActiveStatus(this.operations[i].status)) n++;
    }
    return n;
  }

  hasActive(): boolean {
    return this.activeCount() > 0;
  }

  hasCompleted(): boolean {
    for (let i = 0; i < this.operations.length; i++) {
      if (this.operations[i].status === OperationStatus.SUCCESS) return true;
    }
    return false;
  }

  hasFinished(): boolean {
    for (let i = 0; i < this.operations.length; i++) {
      if (isFinishedStatus(this.operations[i].status)) return true;
    }
    return false;
  }

  hasAny(): boolean {
    return this.operations.length > 0;
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  register(
    type: OperationType,
    itemName: string,
    itemId: string = '',
    itemKind: OperationItemKind = OperationItemKind.UNKNOWN,
    batchIndex: number = 0,
    batchTotal: number = 0,
    retryPayload?: RetryPayload
  ): string {
    const id: string = `op_${this.nextId++}_${Date.now()}`;
    const op: Operation = createOperation(
      id, type, itemName, itemId, itemKind, batchIndex, batchTotal, retryPayload
    );
    this.operations = [op, ...this.operations];
    this.notify();
    Logger.info(TAG, `Registered ${type} for "${itemName}" (${id})`);
    return id;
  }

  markRunning(id: string): void {
    this.update(id, OperationStatus.RUNNING, -1, '');
  }

  updateProgress(id: string, progress: number): void {
    this.update(id, OperationStatus.RUNNING, progress, '');
  }

  markSuccess(id: string): void {
    this.update(id, OperationStatus.SUCCESS, 100, '');
    this.trimFinished();
  }

  markFailed(id: string, errorMessage: string): void {
    this.update(id, OperationStatus.FAILED, -1, errorMessage);
    this.trimFinished();
  }

  markCancelled(id: string): void {
    this.update(id, OperationStatus.CANCELLED, -1, '');
    this.trimFinished();
  }

  private update(
    id: string,
    status: OperationStatus,
    progress: number,
    errorMessage: string
  ): void {
    let changed: boolean = false;
    const next: Operation[] = [];
    for (let i = 0; i < this.operations.length; i++) {
      const op = this.operations[i];
      if (op.id === id) {
        next.push({
          id: op.id,
          type: op.type,
          itemName: op.itemName,
          itemId: op.itemId,
          itemKind: op.itemKind,
          status,
          progress,
          startedAt: op.startedAt,
          completedAt: isFinishedStatus(status) ? Date.now() : op.completedAt,
          batchIndex: op.batchIndex,
          batchTotal: op.batchTotal,
          errorMessage,
          retryPayload: op.retryPayload
        });
        changed = true;
      } else {
        next.push(op);
      }
    }
    if (changed) {
      this.operations = next;
      this.notify();
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  clearCompleted(): void {
    const kept: Operation[] = [];
    for (let i = 0; i < this.operations.length; i++) {
      const op = this.operations[i];
      if (op.status !== OperationStatus.SUCCESS) kept.push(op);
    }
    this.operations = kept;
    this.notify();
    Logger.info(TAG, 'Cleared completed operations.');
  }

  clearFinished(): void {
    const kept: Operation[] = [];
    for (let i = 0; i < this.operations.length; i++) {
      if (isActiveStatus(this.operations[i].status)) kept.push(this.operations[i]);
    }
    this.operations = kept;
    this.notify();
    Logger.info(TAG, 'Cleared finished operations.');
  }

  forceClearAll(): void {
    this.operations = [];
    this.notify();
    Logger.info(TAG, 'Force-cleared ALL operations.');
  }

  private trimFinished(): void {
    let finished: number = 0;
    const kept: Operation[] = [];
    for (let i = 0; i < this.operations.length; i++) {
      const op = this.operations[i];
      if (isActiveStatus(op.status)) {
        kept.push(op);
      } else if (finished < OperationTracker.MAX_FINISHED) {
        kept.push(op);
        finished++;
      }
    }
    if (kept.length !== this.operations.length) {
      this.operations = kept;
      this.notify();
    }
  }
}
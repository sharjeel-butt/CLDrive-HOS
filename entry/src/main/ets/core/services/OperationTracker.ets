import {
  createOperation,
  isActiveStatus,
  isFinishedStatus,
  Operation,
  OperationItemKind,
  OperationStatus,
  OperationType
} from '../models/Operation';
import { Logger } from '../../utils/Logger';

const TAG: string = 'OperationTracker';

type Listener = (ops: Operation[]) => void;


/**
 * Application-wide registry of in-flight and recent operations.
 * Singleton so that background work (downloads via request.agent,
 * batch move/copy loops) outlives any individual page.
 */
export class OperationTracker {
  private static instance: OperationTracker = new OperationTracker();
  private static readonly MAX_FINISHED = 30;
  private operations: Operation[] = [];
  private listeners: Listener[] = [];
  private nextId: number = 1;

  static get(): OperationTracker {
    return OperationTracker.instance;
  }

  // ---------------------------------------------------------------------------
  // Subscription
  // ---------------------------------------------------------------------------

  subscribe(listener: Listener): void {
    this.listeners.push(listener);
    listener(this.operations.slice());
  }

  unsubscribe(listener: Listener): void {
    const idx = this.listeners.indexOf(listener);
    if (idx >= 0) {
      const next = this.listeners.slice();
      next.splice(idx, 1);
      this.listeners = next;
    }
  }

  getAll(): Operation[] {
    return this.operations.slice();
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  activeCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.operations.length; i++) {
      if (isActiveStatus(this.operations[i].status)) {
        n++;
      }
    }
    return n;
  }

  hasActive(): boolean {
    return this.activeCount() > 0;
  }

  hasCompleted(): boolean {
    for (let i = 0; i < this.operations.length; i++) {
      if (this.operations[i].status === OperationStatus.SUCCESS) {
        return true;
      }
    }
    return false;
  }

  hasFinished(): boolean {
    for (let i = 0; i < this.operations.length; i++) {
      if (isFinishedStatus(this.operations[i].status)) {
        return true;
      }
    }
    return false;
  }

  hasAny(): boolean {
    return this.operations.length > 0;
  }

  register(
    type: OperationType,
    itemName: string,
    itemId: string = '',
    itemKind: OperationItemKind = OperationItemKind.UNKNOWN,
    batchIndex: number = 0,
    batchTotal: number = 0
  ): string {
    const id: string = `op_${this.nextId++}_${Date.now()}`;
    const op: Operation = createOperation(
      id, type, itemName, itemId, itemKind, batchIndex, batchTotal
    );
    this.operations = [op, ...this.operations];
    this.notify();
    Logger.info(TAG, `Registered ${type} for "${itemName}" (${id})`);
    return id;
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

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

  /**
   * Remove operations that completed successfully.
   * Failed and cancelled entries stay so the user can see them.
   */
  clearCompleted(): void {
    const kept: Operation[] = [];
    for (let i = 0; i < this.operations.length; i++) {
      const op = this.operations[i];
      if (op.status !== OperationStatus.SUCCESS) {
        kept.push(op);
      }
    }
    this.operations = kept;
    this.notify();
    Logger.info(TAG, 'Cleared completed operations.');
  }

  /**
   * Remove every finished operation (success, failed, cancelled).
   * Active operations are preserved.
   */
  clearFinished(): void {
    const kept: Operation[] = [];
    for (let i = 0; i < this.operations.length; i++) {
      if (isActiveStatus(this.operations[i].status)) {
        kept.push(this.operations[i]);
      }
    }
    this.operations = kept;
    this.notify();
    Logger.info(TAG, 'Cleared finished operations.');
  }

  // ---------------------------------------------------------------------------
  // Cleanup — three variants
  // ---------------------------------------------------------------------------

  /**
   * Nuke everything, including still-running operations.
   * The actual background work will continue (request.agent tasks aren't
   * cancelled by this) but they will no longer appear in the tracker.
   * Callers should confirm with the user first.
   */
  forceClearAll(): void {
    this.operations = [];
    this.notify();
    Logger.info(TAG, 'Force-cleared ALL operations.');
  }

  private notify(): void {
    const snapshot = this.operations.slice();
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i](snapshot);
    }
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
          errorMessage
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
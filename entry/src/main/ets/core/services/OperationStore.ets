import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Operation, OperationStatus } from '../models/Operation';
import { Logger } from '../../utils/Logger';

const TAG: string = 'OperationStore';

/**
 * Persistent registry of task history.
 *
 * Tasks in QUEUED or RUNNING state are converted to FAILED when saved,
 * because the underlying work cannot survive an app restart. The user
 * sees them with a clear "Interrupted by app restart" message and a
 * retry button (if the task carries a retry payload).
 */
export class OperationStore {
  private static readonly STORE_NAME = 'cl_drive_operations';
  private static readonly KEY = 'operations';

  private static prefs: preferences.Preferences | null = null;

  static async init(context: common.Context): Promise<void> {
    if (OperationStore.prefs !== null) return;
    OperationStore.prefs = await preferences.getPreferences(
      context, OperationStore.STORE_NAME
    );
    Logger.info(TAG, 'OperationStore initialised.');
  }

  private static ensure(): preferences.Preferences {
    if (OperationStore.prefs === null) {
      throw new Error('OperationStore.init(context) must be called before use.');
    }
    return OperationStore.prefs;
  }

  static async load(): Promise<Operation[]> {
    const p = OperationStore.ensure();
    const raw = await p.get(OperationStore.KEY, '[]');
    const str: string = typeof raw === 'string' ? raw : '[]';
    try {
      return JSON.parse(str) as Operation[];
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `parse failed: ${err.message}`);
      return [];
    }
  }

  static async save(ops: Operation[]): Promise<void> {
    const p = OperationStore.ensure();

    // Sanitize: any still-running task is dead after a restart.
    const sanitized: Operation[] = [];
    for (let i = 0; i < ops.length; i++) {
      const op: Operation = ops[i];
      if (op.status === OperationStatus.QUEUED
        || op.status === OperationStatus.RUNNING) {
        sanitized.push({
          id: op.id,
          type: op.type,
          itemName: op.itemName,
          itemId: op.itemId,
          itemKind: op.itemKind,
          status: OperationStatus.FAILED,
          progress: -1,
          startedAt: op.startedAt,
          completedAt: Date.now(),
          batchIndex: op.batchIndex,
          batchTotal: op.batchTotal,
          errorMessage: 'Interrupted by app restart',
          retryPayload: op.retryPayload
        });
      } else {
        sanitized.push(op);
      }
    }

    await p.put(OperationStore.KEY, JSON.stringify(sanitized));
    await p.flush();
  }

  static async clear(): Promise<void> {
    const p = OperationStore.ensure();
    await p.put(OperationStore.KEY, '[]');
    await p.flush();
  }
}
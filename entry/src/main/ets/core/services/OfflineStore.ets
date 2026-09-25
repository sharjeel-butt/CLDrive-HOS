import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Logger } from '../../utils/Logger';
import { fileIo as fs } from '@kit.CoreFileKit';

const TAG: string = 'OfflineStore';

export interface OfflineFileRecord {
  cloudId: string;
  accountId: string;
  provider: string;
  name: string;
  localPath: string;
  mimeType: string;
  size: number;
  downloadedAt: number;
}

export interface CacheInfo {
  fileCount: number;
  totalBytes: number;
}

/**
 * Persistent registry of files marked "available offline".
 *
 * Files are stored under `<context.filesDir>/offline/`, which persists
 * across app restarts (unlike cacheDir, which the system can evict).
 */
export class OfflineStore {
  private static readonly STORE_NAME = 'cl_drive_offline';
  private static readonly KEY = 'offline_files';

  private static prefs: preferences.Preferences | null = null;

  static async init(context: common.Context): Promise<void> {
    if (OfflineStore.prefs !== null) return;
    OfflineStore.prefs = await preferences.getPreferences(
      context, OfflineStore.STORE_NAME
    );
    Logger.info(TAG, 'OfflineStore initialised.');
  }

  private static ensure(): preferences.Preferences {
    if (OfflineStore.prefs === null) {
      throw new Error('OfflineStore.init(context) must be called before use.');
    }
    return OfflineStore.prefs;
  }

  static async getAll(): Promise<OfflineFileRecord[]> {
    const p = OfflineStore.ensure();
    const raw = await p.get(OfflineStore.KEY, '[]');
    const str: string = typeof raw === 'string' ? raw : '[]';
    try {
      return JSON.parse(str) as OfflineFileRecord[];
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `parse offline list failed: ${err.message}`);
      return [];
    }
  }

  static async getById(cloudId: string): Promise<OfflineFileRecord | null> {
    const all = await OfflineStore.getAll();
    for (let i = 0; i < all.length; i++) {
      if (all[i].cloudId === cloudId) return all[i];
    }
    return null;
  }

  static async add(record: OfflineFileRecord): Promise<void> {
    const all = await OfflineStore.getAll();
    const filtered: OfflineFileRecord[] = [];
    for (let i = 0; i < all.length; i++) {
      if (all[i].cloudId !== record.cloudId) filtered.push(all[i]);
    }
    filtered.push(record);
    await OfflineStore.save(filtered);
    Logger.info(TAG, `Registered offline: ${record.name}`);
  }

  static async remove(cloudId: string): Promise<void> {
    const all = await OfflineStore.getAll();
    const filtered: OfflineFileRecord[] = [];
    for (let i = 0; i < all.length; i++) {
      if (all[i].cloudId !== cloudId) filtered.push(all[i]);
    }
    await OfflineStore.save(filtered);
  }

  static async replaceAll(records: OfflineFileRecord[]): Promise<void> {
    await OfflineStore.save(records);
  }

  private static async save(records: OfflineFileRecord[]): Promise<void> {
    const p = OfflineStore.ensure();
    await p.put(OfflineStore.KEY, JSON.stringify(records));
    await p.flush();
  }

  /**
   * Compute total size and count of cached offline files.
   * Uses fs.statSync per record; silently skips records whose files
   * are missing (they'll be pruned on next loadOfflineIds anyway).
   */
  static async getCacheInfo(): Promise<CacheInfo> {
    const records = await OfflineStore.getAll();
    let totalBytes: number = 0;
    let fileCount: number = 0;

    for (let i = 0; i < records.length; i++) {
      try {
        const stat = fs.statSync(records[i].localPath);
        totalBytes += stat.size;
        fileCount++;
      } catch (_) {
        // File missing — skip; will be pruned elsewhere.
      }
    }
    return { fileCount, totalBytes };
  }

  /**
   * Delete every cached offline file and clear the registry.
   */
  static async clearAll(): Promise<void> {
    const records = await OfflineStore.getAll();
    for (let i = 0; i < records.length; i++) {
      try {
        fs.unlinkSync(records[i].localPath);
      } catch (_) { /* already gone */ }
    }
    await OfflineStore.save([]);
    Logger.info(TAG, 'Cleared all offline files.');
  }
}
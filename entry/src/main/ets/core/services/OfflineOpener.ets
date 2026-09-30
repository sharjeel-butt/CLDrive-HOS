import { common, Want, wantConstant } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { OfflineStore, OfflineFileRecord } from './OfflineStore';
import { resolveMimeType } from '../../utils/MimeUtils';
import { Logger } from '../../utils/Logger';

const TAG: string = 'OfflineOpener';

export enum OfflineOpenResult {
  OK = 'ok',
  /** No offline record exists for the cloud ID. */
  MISSING = 'missing',
  /** A record exists but the cached file has been deleted. */
  GONE = 'gone',
  /** The system rejected startAbility. */
  FAILED = 'failed'
}

export interface OpenOutcome {
  result: OfflineOpenResult;
  message?: string;
}

/**
 * Hand an offline-cached file to the system's default viewer.
 *
 * The MIME type is resolved in this order:
 *   1. The MIME stored in the offline record (from the provider).
 *   2. A MIME derived from the file's extension.
 *   3. application/octet-stream.
 *
 * Google-native MIMEs (application/vnd.google-apps.*) are skipped
 * because no installed viewer recognises them, so a Drive document
 * cached under that MIME falls back to its extension.
 */
export class OfflineOpener {
  static async open(
    ctx: common.UIAbilityContext,
    cloudId: string
  ): Promise<OpenOutcome> {
    const record: OfflineFileRecord | null =
      await OfflineStore.getById(cloudId);
    if (record === null) {
      return { result: OfflineOpenResult.MISSING };
    }

    try {
      fs.accessSync(record.localPath);
    } catch (_) {
      // The record is stale — prune it so subsequent loads don't
      // keep promising a file that isn't there.
      await OfflineStore.remove(cloudId);
      return { result: OfflineOpenResult.GONE };
    }

    const mime: string = resolveMimeType(record.mimeType, record.name);

    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: `file://${record.localPath}`,
        type: mime,
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
      };
      await ctx.startAbility(want);
      Logger.info(TAG, `Opened ${record.name} as ${mime}`);
      return { result: OfflineOpenResult.OK };
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(
        TAG,
        `startAbility failed for ${record.name} (mime=${mime}): ${err.message}`
      );
      return { result: OfflineOpenResult.FAILED, message: err.message };
    }
  }
}
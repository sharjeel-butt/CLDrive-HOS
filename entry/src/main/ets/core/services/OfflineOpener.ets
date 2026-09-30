import { common, Want, wantConstant } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { fileUri } from '@kit.CoreFileKit';
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
 * The URI is built via fileUri.getUriFromPath(), which produces a
 * URI of the form
 *   file://<bundleName>/data/storage/el2/base/haps/entry/files/foo.pdf
 * The bundle name is the URI authority and is what the OS uses to
 * grant cross-sandbox read access. A hand-built `file://` + raw
 * path has an empty authority and the receiving app cannot resolve
 * it — which surfaces as "preview failed, the file may be moved".
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

    // Build the URI with the bundle name as authority. This is what
    // lets the receiving app request a read grant on a sandbox file.
    let uriString: string = '';
    try {
      uriString = fileUri.getUriFromPath(record.localPath);
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(
        TAG,
        `getUriFromPath failed for ${record.localPath}: ${err.message}`
      );
      // Fallback to the naive construction — will likely fail on
      // cross-sandbox access, but keeps the diagnostic path open.
      uriString = `file://${record.localPath}`;
    }

    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: uriString,
        type: mime,
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
      };
      await ctx.startAbility(want);
      Logger.info(TAG, `Opened ${record.name} as ${mime} (uri=${uriString})`);
      return { result: OfflineOpenResult.OK };
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(
        TAG,
        `startAbility failed for ${record.name} (mime=${mime}, uri=${uriString}): ${err.message}`
      );
      return { result: OfflineOpenResult.FAILED, message: err.message };
    }
  }
}
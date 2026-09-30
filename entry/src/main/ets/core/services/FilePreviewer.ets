import { common, Want, wantConstant } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { fileUri } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { CloudItem } from '../models/CloudItem';
import { CloudItemType } from '../models/CloudItemType';
import { DownloadInfo } from '../models/DownloadInfo';
import { ICloudProvider } from '../interfaces/ICloudProvider';
import { OfflineStore, OfflineFileRecord } from './OfflineStore';
import { LocalFileService } from '../../utils/FileUtil';
import { resolveMimeType } from '../../utils/MimeUtils';
import { Logger } from '../../utils/Logger';

const TAG: string = 'FilePreviewer';

/**
 * Open a cloud file in the system's default viewer.
 *
 * Resolution order:
 *   1. If the item is available offline and the cached file exists,
 *      open that copy directly.
 *   2. Otherwise download to <cacheDir>/preview and open that copy.
 *
 * Preview cache is keyed by cloud item ID, so repeated opens of the
 * same file reuse the download. The OS may evict cacheDir at any
 * time, in which case the next open simply downloads again.
 *
 * Throws on any failure. Callers catch and show a localized toast.
 */
export class FilePreviewer {
  static async open(
    ctx: common.UIAbilityContext,
    item: CloudItem,
    provider: ICloudProvider
  ): Promise<void> {
    if (item.type !== CloudItemType.FILE) {
      throw new Error('FilePreviewer.open only accepts files');
    }

    // 1. Prefer the offline copy if one exists.
    const record: OfflineFileRecord | null =
      await OfflineStore.getById(item.id);
    if (record !== null) {
      try {
        fs.accessSync(record.localPath);
        await FilePreviewer.launch(
          ctx, record.localPath, item.name, record.mimeType
        );
        return;
      } catch (_) {
        // Stale record — prune and fall through to download.
        Logger.warn(TAG, `Pruning stale offline record for ${item.name}`);
        await OfflineStore.remove(item.id);
      }
    }

    // 2. Download to the preview cache.
    const previewDir: string = `${ctx.cacheDir}/preview`;
    LocalFileService.ensureDir(previewDir);

    const safeId: string = item.id
      .replace(/[^a-zA-Z0-9_-]/g, '_')
      .substring(0, 40);
    const safeName: string = item.name
      .replace(/[^a-zA-Z0-9._-]/g, '_')
      .substring(0, 100);
    const cachePath: string = `${previewDir}/${safeId}_${safeName}`;

    if (!FilePreviewer.cacheExists(cachePath)) {
      const info: DownloadInfo = await provider.getDownloadInfo(item.id);
      const bytes: ArrayBuffer =
        await FilePreviewer.fetchBytes(info, item.name);

      const f = fs.openSync(
        cachePath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC
      );
      try {
        fs.writeSync(f.fd, bytes);
      } finally {
        fs.closeSync(f);
      }
      Logger.info(
        TAG,
        `Preview cached ${item.name} (${bytes.byteLength} bytes) → ${cachePath}`
      );
    } else {
      Logger.info(TAG, `Reusing cached preview for ${item.name}`);
    }

    await FilePreviewer.launch(
      ctx, cachePath, item.name,
      item.mimeType !== undefined ? item.mimeType : ''
    );
  }

  /**
   * Delete every cached preview file. Safe to call from Settings.
   */
  static clearCache(ctx: common.UIAbilityContext): void {
    const dir: string = `${ctx.cacheDir}/preview`;
    try {
      fs.accessSync(dir);
    } catch (_) {
      return;
    }
    let names: string[] = [];
    try {
      names = fs.listFileSync(dir);
    } catch (_) {
      return;
    }
    for (let i = 0; i < names.length; i++) {
      try { fs.unlinkSync(`${dir}/${names[i]}`); } catch (_) { /* ignore */ }
    }
    Logger.info(TAG, 'Preview cache cleared.');
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  private static async launch(
    ctx: common.UIAbilityContext,
    localPath: string,
    fileName: string,
    providedMime: string
  ): Promise<void> {
    let uriString: string = '';
    try {
      uriString = fileUri.getUriFromPath(localPath);
    } catch (e) {
      const err: Error = e as Error;
      Logger.warn(
        TAG,
        `getUriFromPath failed for ${localPath}: ${err.message}`
      );
      uriString = `file://${localPath}`;
    }

    const mime: string = resolveMimeType(providedMime, fileName);

    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: uriString,
      type: mime,
      flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
    };
    await ctx.startAbility(want);
    Logger.info(TAG, `Opened ${fileName} as ${mime}`);
  }

  private static cacheExists(path: string): boolean {
    try {
      return fs.statSync(path).size > 0;
    } catch (_) {
      return false;
    }
  }

  private static async fetchBytes(
    info: DownloadInfo,
    label: string
  ): Promise<ArrayBuffer> {
    const request = http.createHttp();
    try {
      const headerObj: Record<string, string> = {};
      info.headers.forEach((value: string, key: string): void => {
        Reflect.set(headerObj, key, value);
      });

      const opts: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: headerObj,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: 120_000,
        connectTimeout: 30_000
      };

      const response = await request.request(info.url, opts);
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode} for ${label}`);
      }
      return response.result as ArrayBuffer;
    } finally {
      request.destroy();
    }
  }
}
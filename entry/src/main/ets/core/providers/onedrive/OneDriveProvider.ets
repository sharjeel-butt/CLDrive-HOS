import { ICloudProvider } from '../../interfaces/ICloudProvider';
import { CloudItem } from '../../models/CloudItem';
import { UserProfile } from '../../models/UserProfile';
import { CloudProviderType } from '../../models/CloudProviderType';
import { DownloadInfo } from '../../models/DownloadInfo';
import {
  OneDriveApiClient,
  UploadSessionResponse
} from './OneDriveApiClient';
import { OneDriveAuthProvider } from './OneDriveAuthProvider';
import { OneDriveMapper, GraphUser } from './OneDriveMapper';
import { TokenRefresher } from '../../auth/TokenRefresher';
import { LocalFileService } from '../../../utils/FileUtil';
import { OneDriveConfig } from '../../../config/OneDriveConfig';
import { Logger } from '../../../utils/Logger';

const TAG: string = 'OneDriveProvider';

export class OneDriveProvider implements ICloudProvider {
  readonly providerType: string = CloudProviderType.ONEDRIVE;

  private accountId: string;
  private api: OneDriveApiClient;
  private auth: OneDriveAuthProvider;

  constructor(accountId: string) {
    this.accountId = accountId;
    this.api = new OneDriveApiClient();
    this.auth = new OneDriveAuthProvider();
  }

  getDownloadUrl(itemId: string): Promise<string> {
    throw new Error('Method not implemented.');
  }

  private run<T>(op: (token: string) => Promise<T>): Promise<T> {
    return TokenRefresher.withAutoRefresh(this.accountId, this.auth, op);
  }

  // ===========================================================================
  // Identity
  // ===========================================================================

  async getCurrentUser(): Promise<UserProfile> {
    const me: GraphUser = await this.run(t => this.api.getMe(t));

    const displayName: string =
      me.displayName !== undefined && me.displayName.length > 0
        ? me.displayName
        : 'OneDrive User';

    let email: string | undefined = undefined;
    if (me.mail !== undefined && me.mail.length > 0) {
      email = me.mail;
    } else if (me.userPrincipalName !== undefined) {
      email = me.userPrincipalName;
    }

    const profile: UserProfile = {
      id: me.id,
      displayName: displayName,
      email: email,
      avatarUrl: undefined,
      provider: this.providerType
    };
    return profile;
  }

  // ===========================================================================
  // Listing
  // ===========================================================================

  async listChildren(parentId: string): Promise<CloudItem[]> {
    if (!parentId || parentId === 'root') {
      const items = await this.run(t => this.api.listRootChildren(t));
      return OneDriveMapper.toCloudItems(items);
    }
    const items = await this.run(t => this.api.listChildren(t, parentId));
    return OneDriveMapper.toCloudItems(items);
  }

  async getItem(itemId: string): Promise<CloudItem> {
    const item = await this.run(t => this.api.getItem(t, itemId));
    return OneDriveMapper.toCloudItem(item);
  }

  async search(query: string): Promise<CloudItem[]> {
    const items = await this.run(t => this.api.search(t, query));
    return OneDriveMapper.toCloudItems(items);
  }

  // ===========================================================================
  // Mutations
  // ===========================================================================

  async createFolder(parentId: string, name: string): Promise<CloudItem> {
    const item = await this.run(t => this.api.createFolder(t, parentId, name));
    return OneDriveMapper.toCloudItem(item);
  }

  async renameItem(itemId: string, newName: string): Promise<CloudItem> {
    const item = await this.run(t => this.api.renameItem(t, itemId, newName));
    return OneDriveMapper.toCloudItem(item);
  }

  async moveItem(
    itemId: string,
    newParentId: string,
    newName?: string
  ): Promise<CloudItem> {
    const item = await this.run(t =>
    this.api.moveItem(t, itemId, newParentId, newName)
    );
    return OneDriveMapper.toCloudItem(item);
  }

  async copyItem(
    itemId: string,
    newParentId: string,
    newName?: string
  ): Promise<string | null> {
    return this.run(t => this.api.copyItem(t, itemId, newParentId, newName));
  }

  async deleteItem(itemId: string): Promise<void> {
    await this.run(t => this.api.deleteItem(t, itemId));
  }

  // ===========================================================================
  // Upload
  // ===========================================================================

  async uploadFile(
    parentId: string,
    fileName: string,
    localPath: string
  ): Promise<CloudItem> {
    // ---- Defensive guards ----
    if (fileName === undefined || fileName === null || fileName.length === 0) {
      throw new Error('uploadFile: fileName is required');
    }
    if (localPath === undefined || localPath === null || localPath.length === 0) {
      throw new Error('uploadFile: localPath is required');
    }
    const safeParentId: string =
      (parentId !== undefined && parentId !== null && parentId.length > 0)
        ? parentId
        : 'root';

    Logger.info(
      TAG,
      `uploadFile: parentId=${safeParentId} fileName="${fileName}" ` +
        `localPath=${localPath}`
    );

    // ---- Determine size ----
    let size: number = 0;
    try {
      size = await LocalFileService.getSize(localPath);
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(
        TAG,
        `Failed to get size for "${fileName}": ${err.message}`
      );
      throw new Error(
        `Cannot read local file "${fileName}": ${err.message}`
      );
    }

    Logger.info(TAG, `uploadFile: "${fileName}" size=${size} bytes`);

    // ---- Route to the appropriate upload path ----
    if (size <= OneDriveConfig.SIMPLE_UPLOAD_MAX_BYTES) {
      return await this.uploadSmall(safeParentId, fileName, localPath);
    }
    return await this.uploadLarge(safeParentId, fileName, localPath, size);
  }

  // ---------------------------------------------------------------------------
  // Simple upload (single PUT, files ≤ 4 MB)
  // ---------------------------------------------------------------------------

  private async uploadSmall(
    parentId: string,
    fileName: string,
    localPath: string
  ): Promise<CloudItem> {
    let content: ArrayBuffer;
    try {
      content = await LocalFileService.readAll(localPath);
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(
        TAG,
        `readAll failed for "${fileName}": ${err.message}`
      );
      throw new Error(`Cannot read "${fileName}": ${err.message}`);
    }

    Logger.info(
      TAG,
      `uploadSmall: "${fileName}" read ${content.byteLength} bytes from disk`
    );

    try {
      const item = await this.run(t =>
      this.api.uploadSmall(t, parentId, fileName, content)
      );
      Logger.info(
        TAG,
        `uploadSmall: "${fileName}" uploaded successfully`
      );
      return OneDriveMapper.toCloudItem(item);
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(
        TAG,
        `uploadSmall API call failed for "${fileName}": ${err.message}`
      );
      throw err;
    }
  }

  // ---------------------------------------------------------------------------
  // Resumable upload (chunked PUTs, files > 4 MB)
  // ---------------------------------------------------------------------------

  private async uploadLarge(
    parentId: string,
    fileName: string,
    localPath: string,
    totalSize: number
  ): Promise<CloudItem> {
    // ---- 1. Create the upload session ----
    let session: UploadSessionResponse;
    try {
      session = await this.run(t =>
      this.api.createUploadSession(t, parentId, fileName)
      );
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(
        TAG,
        `createUploadSession failed for "${fileName}": ${err.message}`
      );
      throw err;
    }

    Logger.info(
      TAG,
      `uploadLarge: session created for "${fileName}", ` +
        `uploadUrl=${session.uploadUrl}`
    );

    const chunkSize: number = OneDriveConfig.UPLOAD_CHUNK_BYTES;
    let offset: number = 0;
    let lastItem: CloudItem | null = null;
    let chunkIndex: number = 0;

    // ---- 2. Upload chunks ----
    while (offset < totalSize) {
      const end: number = Math.min(offset + chunkSize, totalSize);
      const chunkLength: number = end - offset;

      let chunk: ArrayBuffer;
      try {
        chunk = await LocalFileService.readRange(
          localPath, offset, chunkLength
        );
      } catch (e) {
        const err: Error = e as Error;
        Logger.error(
          TAG,
          `readRange failed at offset=${offset} for "${fileName}": ` +
            `${err.message}`
        );
        throw new Error(
          `Cannot read chunk at offset ${offset} from "${fileName}": ` +
            `${err.message}`
        );
      }

      Logger.info(
        TAG,
        `uploadLarge: chunk ${chunkIndex} ` +
          `range ${offset}-${end - 1}/${totalSize} (${chunkLength} bytes)`
      );

      try {
        const result = await this.api.uploadChunk(
          session.uploadUrl,
          chunk,
          offset,
          end - 1,
          totalSize
        );

        if (result !== null) {
          lastItem = OneDriveMapper.toCloudItem(result);
          Logger.info(
            TAG,
            `uploadLarge: "${fileName}" chunk ${chunkIndex} returned DriveItem`
          );
        } else {
          Logger.info(
            TAG,
            `uploadLarge: "${fileName}" chunk ${chunkIndex} accepted (more to go)`
          );
        }
      } catch (e) {
        const err: Error = e as Error;
        Logger.error(
          TAG,
          `uploadChunk failed at offset=${offset} for "${fileName}": ` +
            `${err.message}`
        );
        throw new Error(
          `Chunk upload failed at offset ${offset}: ${err.message}`
        );
      }

      offset = end;
      chunkIndex++;
    }

    // ---- 3. Validate we received the final DriveItem ----
    if (lastItem === null) {
      throw new Error(
        `Upload session for "${fileName}" completed without a DriveItem ` +
          `response. This usually means the final chunk did not include ` +
          `the closing byte range.`
      );
    }

    Logger.info(
      TAG,
      `uploadLarge: "${fileName}" uploaded successfully`
    );
    return lastItem;
  }

  // ===========================================================================
  // Download
  // ===========================================================================

  async downloadFile(itemId: string, localPath: string): Promise<void> {
    const buffer = await this.run(t => this.api.downloadContent(t, itemId));
    await LocalFileService.writeAll(localPath, buffer);
  }

  async getDownloadInfo(itemId: string): Promise<DownloadInfo> {
    const url: string = await this.run(t => this.api.getDownloadUrl(t, itemId));
    const result: DownloadInfo = {
      url: url,
      headers: new Map<string, string>()
    };
    return result;
  }
}
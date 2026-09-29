import { ICloudProvider } from '../../interfaces/ICloudProvider';
import { CloudItem } from '../../models/CloudItem';
import { CloudItemType } from '../../models/CloudItemType';
import { UserProfile } from '../../models/UserProfile';
import { CloudProviderType } from '../../models/CloudProviderType';
import { DownloadInfo } from '../../models/DownloadInfo';
import { DropboxApiClient } from './DropboxApiClient';
import { DropboxAuthProvider } from './DropboxAuthProvider';
import {
  DropboxMapper, DropboxMetadata, DropboxCurrentAccount
} from './DropboxMapper';
import { TokenRefresher } from '../../auth/TokenRefresher';
import { LocalFileService } from '../../../utils/FileUtil';
import { formatError } from '../../../utils/ErrorFormatter';
import { DropboxConfig } from '../../../config/DropboxConfig';
import { Logger } from '../../../utils/Logger';

const TAG: string = 'DropboxProvider';

export class DropboxProvider implements ICloudProvider {
  readonly providerType: string = CloudProviderType.DROPBOX;

  private accountId: string;
  private api: DropboxApiClient;
  private auth: DropboxAuthProvider;

  constructor(accountId: string) {
    this.accountId = accountId;
    this.api = new DropboxApiClient();
    this.auth = new DropboxAuthProvider();
  }

  private run<T>(op: (token: string) => Promise<T>): Promise<T> {
    return TokenRefresher.withAutoRefresh(this.accountId, this.auth, op);
  }

  // ===========================================================================
  // Identity
  // ===========================================================================

  async getCurrentUser(): Promise<UserProfile> {
    const account: DropboxCurrentAccount =
      await this.run(t => this.api.getCurrentAccount(t));

    const displayName: string =
      account.name !== undefined
        && account.name.display_name !== undefined
        && account.name.display_name.length > 0
        ? account.name.display_name
        : 'Dropbox User';

    const profile: UserProfile = {
      id: account.account_id,
      displayName: displayName,
      email: account.email,
      avatarUrl: account.profile_photo_url,
      provider: this.providerType
    };
    return profile;
  }

  // ===========================================================================
  // Listing
  // ===========================================================================

  async listChildren(parentId: string): Promise<CloudItem[]> {
    const path: string = (!parentId || parentId === 'root')
      ? DropboxConfig.ROOT_PATH
      : parentId;

    const entries: DropboxMetadata[] =
      await this.run(t => this.api.listFolder(t, path));
    return DropboxMapper.toCloudItems(entries);
  }

  async getItem(itemId: string): Promise<CloudItem> {
    const meta: DropboxMetadata =
      await this.run(t => this.api.getMetadata(t, itemId));
    return DropboxMapper.toCloudItem(meta);
  }

  async search(query: string): Promise<CloudItem[]> {
    const entries: DropboxMetadata[] =
      await this.run(t => this.api.search(t, query));
    return DropboxMapper.toCloudItems(entries);
  }

  // ===========================================================================
  // Mutations
  // ===========================================================================

  async createFolder(parentId: string, name: string): Promise<CloudItem> {
    const parent: string = (!parentId || parentId === 'root')
      ? DropboxConfig.ROOT_PATH
      : parentId;

    const meta: DropboxMetadata =
      await this.run(t => this.api.createFolder(t, parent, name));
    return DropboxMapper.toCloudItem(meta);
  }

  async renameItem(itemId: string, newName: string): Promise<CloudItem> {
    // Dropbox renames via move: same parent, new name.
    const parent: string | undefined = DropboxMapper.parentPathOf(itemId);
    const parentPath: string = parent !== undefined ? parent : '';
    const newPath: string = DropboxApiClient.joinPath(parentPath, newName);

    const meta: DropboxMetadata =
      await this.run(t => this.api.moveItem(t, itemId, newPath));
    return DropboxMapper.toCloudItem(meta);
  }

  async moveItem(
    itemId: string,
    newParentId: string,
    newName?: string
  ): Promise<CloudItem> {
    const parent: string = (!newParentId || newParentId === 'root')
      ? DropboxConfig.ROOT_PATH
      : newParentId;

    let name: string;
    if (newName !== undefined && newName.length > 0) {
      name = newName;
    } else {
      const slash: number = itemId.lastIndexOf('/');
      name = slash >= 0 ? itemId.substring(slash + 1) : itemId;
    }

    const newPath: string = DropboxApiClient.joinPath(parent, name);
    const meta: DropboxMetadata =
      await this.run(t => this.api.moveItem(t, itemId, newPath));
    return DropboxMapper.toCloudItem(meta);
  }

  async copyItem(
    itemId: string,
    newParentId: string,
    newName?: string
  ): Promise<string | null> {
    const parent: string = (!newParentId || newParentId === 'root')
      ? DropboxConfig.ROOT_PATH
      : newParentId;

    let name: string;
    if (newName !== undefined && newName.length > 0) {
      name = newName;
    } else {
      const slash: number = itemId.lastIndexOf('/');
      name = slash >= 0 ? itemId.substring(slash + 1) : itemId;
    }

    const newPath: string = DropboxApiClient.joinPath(parent, name);
    await this.run(t => this.api.copyItem(t, itemId, newPath));
    // Dropbox copy is synchronous — return null so the caller marks
    // the operation as immediately successful.
    return null;
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
    if (fileName === undefined || fileName === null || fileName.length === 0) {
      throw new Error('uploadFile: fileName is required');
    }
    if (localPath === undefined || localPath === null || localPath.length === 0) {
      throw new Error('uploadFile: localPath is required');
    }

    const parent: string = (!parentId || parentId === 'root')
      ? DropboxConfig.ROOT_PATH
      : parentId;
    const fullPath: string = DropboxApiClient.joinPath(parent, fileName);

    let size: number;
    try {
      size = await LocalFileService.getSize(localPath);
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `Failed to stat "${fileName}": ${readable}`);
      throw new Error(`Cannot read local file: ${readable}`);
    }

    Logger.info(TAG, `uploadFile: "${fileName}" size=${size} → ${fullPath}`);

    if (size <= DropboxConfig.SIMPLE_UPLOAD_MAX_BYTES) {
      let content: ArrayBuffer;
      try {
        content = await LocalFileService.readAll(localPath);
      } catch (e) {
        const readable: string = formatError(e as Error);
        throw new Error(`Cannot read "${fileName}": ${readable}`);
      }

      const meta: DropboxMetadata = await this.run(t =>
      this.api.uploadSmall(t, fullPath, content)
      );
      return DropboxMapper.toCloudItem(meta);
    }

    return this.uploadLarge(fullPath, localPath, size);
  }

  private async uploadLarge(
    fullPath: string,
    localPath: string,
    totalSize: number
  ): Promise<CloudItem> {
    const chunkSize: number = DropboxConfig.UPLOAD_CHUNK_BYTES;
    let offset: number = 0;
    let chunkIndex: number = 0;

    // ---- 1. First chunk — starts the session ----
    const firstEnd: number = Math.min(chunkSize, totalSize);
    const firstChunk: ArrayBuffer = await LocalFileService.readRange(
      localPath, 0, firstEnd
    );
    const sessionId: string = await this.run(t =>
    this.api.uploadSessionStart(t, firstChunk)
    );
    offset = firstEnd;
    chunkIndex = 1;

    Logger.info(
      TAG,
      `uploadLarge: session ${sessionId}, uploaded ${offset}/${totalSize}`
    );

    // ---- 2. Middle chunks ----
    while (offset < totalSize) {
      const end: number = Math.min(offset + chunkSize, totalSize);
      const chunk: ArrayBuffer = await LocalFileService.readRange(
        localPath, offset, end - offset
      );

      // Final chunk goes through /finish, not /append_v2.
      if (end >= totalSize) {
        const meta: DropboxMetadata = await this.run(t =>
        this.api.uploadSessionFinish(t, sessionId, offset, fullPath)
        );
        return DropboxMapper.toCloudItem(meta);
      }

      // 4-argument call — matches DropboxApiClient.uploadSessionAppend.
      await this.run(t =>
      this.api.uploadSessionAppend(t, sessionId, offset, chunk)
      );

      offset = end;
      chunkIndex++;
      Logger.info(
        TAG,
        `uploadLarge: chunk ${chunkIndex}, ${offset}/${totalSize}`
      );
    }

    throw new Error('Upload finished without reaching final chunk.');
  }

  // ===========================================================================
  // Download
  // ===========================================================================

  async downloadFile(itemId: string, localPath: string): Promise<void> {
    const buffer: ArrayBuffer =
      await this.run(t => this.api.downloadContent(t, itemId));
    await LocalFileService.writeAll(localPath, buffer);
  }

  async getDownloadInfo(itemId: string): Promise<DownloadInfo> {
    return this.run(async (token: string): Promise<DownloadInfo> => {
      return await this.api.getDownloadInfo(token, itemId);
    });
  }
}
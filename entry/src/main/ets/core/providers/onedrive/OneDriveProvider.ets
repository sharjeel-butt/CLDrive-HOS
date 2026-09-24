import { ICloudProvider } from '../../interfaces/ICloudProvider';
import { CloudItem, createFolderItem } from '../../models/CloudItem';
import { UserProfile } from '../../models/UserProfile';
import { CloudProviderType } from '../../models/CloudProviderType';
import { OneDriveApiClient } from './OneDriveApiClient';
import { OneDriveAuthProvider } from './OneDriveAuthProvider';
import { OneDriveMapper, GraphUser } from './OneDriveMapper';
import { TokenRefresher } from '../../auth/TokenRefresher';
import { LocalFileService } from '../../../utils/FileUtil';
import { OneDriveConfig } from '../../../config/OneDriveConfig';
import { Logger } from '../../../utils/Logger';
import { DownloadInfo } from '../../models/DownloadInfo';

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

  // ---- Identity ----

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

    return {
      id: me.id,
      displayName: displayName,
      email: email,
      avatarUrl: undefined,
      provider: this.providerType
    };
  }

  // ---- Listing ----

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

  // ---- Mutations ----

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

  /**
   * Copy an item. Returns a Graph monitor URL when the operation is async
   * (always for folders, occasionally for very large files), or null when
   * the copy completes inline.
   */
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

  // ---- Transfers ----

  async uploadFile(
    parentId: string,
    fileName: string,
    localPath: string
  ): Promise<CloudItem> {
    const size = await LocalFileService.getSize(localPath);

    if (size <= OneDriveConfig.SIMPLE_UPLOAD_MAX_BYTES) {
      const content = await LocalFileService.readAll(localPath);
      const item = await this.run(t =>
      this.api.uploadSmall(t, parentId, fileName, content)
      );
      return OneDriveMapper.toCloudItem(item);
    }

    return this.uploadLarge(parentId, fileName, localPath, size);
  }

  private async uploadLarge(
    parentId: string,
    fileName: string,
    localPath: string,
    totalSize: number
  ): Promise<CloudItem> {
    const session = await this.run(t =>
    this.api.createUploadSession(t, parentId, fileName)
    );
    const chunkSize: number = OneDriveConfig.UPLOAD_CHUNK_BYTES;
    let offset: number = 0;
    let lastItem: CloudItem | null = null;

    while (offset < totalSize) {
      const end = Math.min(offset + chunkSize, totalSize);
      const chunk = await LocalFileService.readRange(localPath, offset, end - offset);
      const result = await this.api.uploadChunk(
        session.uploadUrl, chunk, offset, end - 1, totalSize
      );
      if (result !== null) lastItem = OneDriveMapper.toCloudItem(result);
      offset = end;
      Logger.info('OneDriveProvider', `Uploaded ${offset}/${totalSize} bytes`);
    }

    if (lastItem === null) {
      throw new Error('Upload session completed without a DriveItem response.');
    }
    return lastItem;
  }

  async downloadFile(itemId: string, localPath: string): Promise<void> {
    const buffer = await this.run(t => this.api.downloadContent(t, itemId));
    await LocalFileService.writeAll(localPath, buffer);
  }

  async getDownloadInfo(itemId: string): Promise<DownloadInfo> {
    const url: string = await this.run(t => this.api.getDownloadUrl(t, itemId));
    // OneDrive returns a pre-authenticated URL — no headers needed.
    return { url: url, headers: new Map<string, string>() };
  }
}
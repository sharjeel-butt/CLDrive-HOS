import { ICloudProvider } from '../../interfaces/ICloudProvider';
import { CloudItem, createFolderItem } from '../../models/CloudItem';
import { CloudItemType } from '../../models/CloudItemType';
import { UserProfile } from '../../models/UserProfile';
import { CloudProviderType } from '../../models/CloudProviderType';
import { GoogleDriveApiClient } from './GoogleDriveApiClient';
import { GoogleDriveAuthProvider } from './GoogleDriveAuthProvider';
import {
  GoogleDriveMapper, GoogleAbout, GoogleFile, GoogleUser
} from './GoogleDriveMapper';
import { TokenRefresher } from '../../auth/TokenRefresher';
import { LocalFileService } from '../../../utils/FileUtil';
import { GoogleDriveConfig } from '../../../config/GoogleDriveConfig';
import { Logger } from '../../../utils/Logger';
import { DownloadInfo } from '../../models/DownloadInfo';

const TAG: string = 'GoogleDriveProvider';

export class GoogleDriveProvider implements ICloudProvider {
  readonly providerType: string = CloudProviderType.GOOGLE_DRIVE;

  private accountId: string;
  private api: GoogleDriveApiClient;
  private auth: GoogleDriveAuthProvider;

  constructor(accountId: string) {
    this.accountId = accountId;
    this.api = new GoogleDriveApiClient();
    this.auth = new GoogleDriveAuthProvider();
  }

  getDownloadUrl(itemId: string): Promise<string> {
    throw new Error('Method not implemented.');
  }

  private run<T>(op: (token: string) => Promise<T>): Promise<T> {
    return TokenRefresher.withAutoRefresh(this.accountId, this.auth, op);
  }

  // ---- Identity ----

  async getCurrentUser(): Promise<UserProfile> {
    const about: GoogleAbout = await this.run(t => this.api.getAbout(t));
    const user: GoogleUser = about.user !== undefined ? about.user : {};

    const displayName: string =
      user.displayName !== undefined && user.displayName.length > 0
        ? user.displayName
        : 'Google User';

    return {
      id: user.emailAddress !== undefined ? user.emailAddress : '',
      displayName: displayName,
      email: user.emailAddress,
      avatarUrl: user.photoLink,
      provider: this.providerType
    };
  }

  // ---- Listing ----

  async listChildren(parentId: string): Promise<CloudItem[]> {
    const files = await this.run(t => this.api.listChildren(t, parentId));
    return GoogleDriveMapper.toCloudItems(files);
  }

  async getItem(itemId: string): Promise<CloudItem> {
    const file = await this.run(t => this.api.getFile(t, itemId));
    return GoogleDriveMapper.toCloudItem(file);
  }

  async search(query: string): Promise<CloudItem[]> {
    const files = await this.run(t => this.api.search(t, query));
    return GoogleDriveMapper.toCloudItems(files);
  }

  // ---- Mutations ----

  async createFolder(parentId: string, name: string): Promise<CloudItem> {
    const file = await this.run(t =>
    this.api.createFolder(t, parentId, name)
    );
    return GoogleDriveMapper.toCloudItem(file);
  }

  async renameItem(itemId: string, newName: string): Promise<CloudItem> {
    const file = await this.run(t =>
    this.api.renameFile(t, itemId, newName)
    );
    return GoogleDriveMapper.toCloudItem(file);
  }

  async moveItem(
    itemId: string,
    newParentId: string,
    newName?: string
  ): Promise<CloudItem> {
    // Google requires the current parent to remove it during a move.
    const current = await this.run(t => this.api.getFile(t, itemId));
    const oldParent: string =
      current.parents !== undefined && current.parents.length > 0
        ? current.parents[0]
        : '';

    const file = await this.run(t =>
    this.api.moveFile(t, itemId, oldParent, newParentId, newName)
    );
    return GoogleDriveMapper.toCloudItem(file);
  }

  /**
   * Google Drive copies are synchronous for regular files but asynchronous
   * for folders containing many items. The returned file has a `name` of
   * "Copy of X" until the copy completes. The Activity panel will show the
   * operation as done as soon as the API returns.
   */
  async copyItem(
    itemId: string,
    newParentId: string,
    newName?: string
  ): Promise<string | null> {
    await this.run(t =>
    this.api.copyFile(t, itemId, newParentId, newName)
    );
    // Google doesn't return a monitor URL; caller marks success on return.
    return null;
  }

  async deleteItem(itemId: string): Promise<void> {
    await this.run(t => this.api.deleteFile(t, itemId));
  }

  // ---- Transfers ----

  async uploadFile(
    parentId: string,
    fileName: string,
    localPath: string
  ): Promise<CloudItem> {
    const size: number = await LocalFileService.getSize(localPath);
    const mimeType: string = GoogleDriveProvider.mimeTypeFor(fileName);

    const sessionUrl: string = await this.run(t =>
    this.api.initiateResumableUpload(t, parentId, fileName, mimeType, size)
    );

    if (size <= GoogleDriveConfig.SIMPLE_UPLOAD_MAX_BYTES) {
      // Single-chunk upload.
      const content = await LocalFileService.readAll(localPath);
      const result = await this.api.uploadChunk(sessionUrl, content, 0, size - 1, size);
      if (result === null) {
        throw new Error('Upload completed without a file response.');
      }
      return GoogleDriveMapper.toCloudItem(result);
    }

    return this.uploadLarge(sessionUrl, localPath, size);
  }

  private async uploadLarge(
    sessionUrl: string,
    localPath: string,
    totalSize: number
  ): Promise<CloudItem> {
    const chunkSize: number = GoogleDriveConfig.UPLOAD_CHUNK_BYTES;
    let offset: number = 0;
    let lastFile: CloudItem | null = null;

    while (offset < totalSize) {
      const end: number = Math.min(offset + chunkSize, totalSize);
      const chunk: ArrayBuffer = await LocalFileService.readRange(
        localPath, offset, end - offset
      );

      const result = await this.api.uploadChunk(
        sessionUrl, chunk, offset, end - 1, totalSize
      );

      if (result !== null) {
        lastFile = GoogleDriveMapper.toCloudItem(result);
      }
      offset = end;
      Logger.info(TAG, `Uploaded ${offset}/${totalSize} bytes`);
    }

    if (lastFile === null) {
      throw new Error('Upload completed without a file response.');
    }
    return lastFile;
  }

  async downloadFile(itemId: string, localPath: string): Promise<void> {
    const buffer = await this.run(t => this.api.downloadContent(t, itemId));
    await LocalFileService.writeAll(localPath, buffer);
  }

  async getDownloadInfo(itemId: string): Promise<DownloadInfo> {
    // Fetch a fresh access token via the TokenRefresher.
    // We use getFile() here just to force the token refresh path; the file
    // metadata itself isn't needed for the download.
    return this.run(async (token: string): Promise<DownloadInfo> => {
      const url =
        `${GoogleDriveConfig.DRIVE_API}/files/${encodeURIComponent(itemId)}?alt=media`;

      const headers = new Map<string, string>();
      headers.set('Authorization', `Bearer ${token}`);
      // Google's CDN rejects requests without a User-Agent.
      headers.set(
        'User-Agent',
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 ' +
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36'
      );
      // Some Google endpoints require a permissive Accept header.
      headers.set('Accept', '*/*');

      return { url: url, headers: headers };
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  private static mimeTypeFor(fileName: string): string {
    const dot = fileName.lastIndexOf('.');
    if (dot < 0) return 'application/octet-stream';
    const ext = fileName.substring(dot + 1).toLowerCase();

    if (ext === 'pdf') return 'application/pdf';
    if (ext === 'jpg' || ext === 'jpeg') return 'image/jpeg';
    if (ext === 'png') return 'image/png';
    if (ext === 'gif') return 'image/gif';
    if (ext === 'webp') return 'image/webp';
    if (ext === 'svg') return 'image/svg+xml';
    if (ext === 'txt' || ext === 'log' || ext === 'md') return 'text/plain';
    if (ext === 'csv') return 'text/csv';
    if (ext === 'json') return 'application/json';
    if (ext === 'xml') return 'application/xml';
    if (ext === 'html' || ext === 'htm') return 'text/html';
    if (ext === 'zip') return 'application/zip';
    if (ext === 'tar') return 'application/x-tar';
    if (ext === 'gz') return 'application/gzip';
    if (ext === 'doc') return 'application/msword';
    if (ext === 'docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (ext === 'xls') return 'application/vnd.ms-excel';
    if (ext === 'xlsx') return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (ext === 'ppt') return 'application/vnd.ms-powerpoint';
    if (ext === 'pptx') return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    if (ext === 'mp3') return 'audio/mpeg';
    if (ext === 'wav') return 'audio/wav';
    if (ext === 'mp4') return 'video/mp4';
    if (ext === 'mov') return 'video/quicktime';
    if (ext === 'webm') return 'video/webm';

    return 'application/octet-stream';
  }
}
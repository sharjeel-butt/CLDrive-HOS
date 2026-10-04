import { CloudItem } from '../models/CloudItem';
import { UserProfile } from '../models/UserProfile';
import { DownloadInfo } from '../models/DownloadInfo';
import { StorageInfo } from '../models/StorageInfo';

export interface ICloudProvider {
  readonly providerType: string;

  // ---------------------------------------------------------------------------
  // Identity
  // ---------------------------------------------------------------------------
  getCurrentUser(): Promise<UserProfile>;

  /**
   * Fetch the account's cloud storage quota. Returns used and total
   * bytes; total <= 0 indicates the provider reports unlimited or
   * does not expose quota.
   */
  getStorageInfo(): Promise<StorageInfo>;

  // ---------------------------------------------------------------------------
  // Listing
  // ---------------------------------------------------------------------------
  listChildren(parentId: string): Promise<CloudItem[]>;
  getItem(itemId: string): Promise<CloudItem>;
  search(query: string): Promise<CloudItem[]>;

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------
  createFolder(parentId: string, name: string): Promise<CloudItem>;
  renameItem(itemId: string, newName: string): Promise<CloudItem>;
  moveItem(
    itemId: string,
    newParentId: string,
    newName?: string
  ): Promise<CloudItem>;

  /**
   * Copy an item. Returns a monitor URL when the copy is async
   * (OneDrive folders, Google Drive folders), or null when it
   * completes inline (Dropbox, OneDrive small files).
   */
  copyItem(
    itemId: string,
    newParentId: string,
    newName?: string
  ): Promise<string | null>;

  deleteItem(itemId: string): Promise<void>;

  // ---------------------------------------------------------------------------
  // Upload
  // ---------------------------------------------------------------------------
  uploadFile(
    parentId: string,
    fileName: string,
    localPath: string
  ): Promise<CloudItem>;

  // ---------------------------------------------------------------------------
  // Download
  // ---------------------------------------------------------------------------

  /**
   * Return the URL and any required headers for downloading an item.
   *
   * Replaces the old getDownloadUrl() method, which could not carry
   * authentication headers. Some providers (OneDrive) return a
   * pre-authenticated URL with no headers; others (Google Drive,
   * Dropbox) require an Authorization Bearer token, and Dropbox also
   * requires a Dropbox-API-Arg header.
   */
  getDownloadInfo(itemId: string): Promise<DownloadInfo>;

  /**
   * Download the item's raw content directly to a local path.
   * Used by offline caching and other flows where the caller
   * writes bytes rather than handing off to request.agent.
   */
  downloadFile(itemId: string, localPath: string): Promise<void>;
}
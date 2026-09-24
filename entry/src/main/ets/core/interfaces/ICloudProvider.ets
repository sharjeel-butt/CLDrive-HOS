import { CloudItem } from '../models/CloudItem';
import { UserProfile } from '../models/UserProfile';
import { DownloadInfo } from '../models/DownloadInfo';

export interface ICloudProvider {
  readonly providerType: string;

  // Identity
  getCurrentUser(): Promise<UserProfile>;

  // Listing
  listChildren(parentId: string): Promise<CloudItem[]>;

  getItem(itemId: string): Promise<CloudItem>;

  search(query: string): Promise<CloudItem[]>;

  // Mutations
  createFolder(parentId: string, name: string): Promise<CloudItem>;

  renameItem(itemId: string, newName: string): Promise<CloudItem>;

  moveItem(itemId: string, newParentId: string, newName?: string): Promise<CloudItem>;

  copyItem(itemId: string, newParentId: string, newName?: string): Promise<string | null>;

  deleteItem(itemId: string): Promise<void>;

  // Transfers
  uploadFile(parentId: string, fileName: string, localPath: string): Promise<CloudItem>;

  downloadFile(itemId: string, localPath: string): Promise<void>;

  getDownloadUrl(itemId: string): Promise<string>;

  getDownloadInfo(itemId: string): Promise<DownloadInfo>;
}
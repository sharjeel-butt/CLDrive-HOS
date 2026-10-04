import { CloudItemType } from './CloudItemType';

export interface CloudItem {
  id: string;
  provider: string;
  name: string;
  type: CloudItemType;
  size?: number;
  childCount?: number;
  mimeType?: string;
  modifiedAt: number;
  createdAt?: number;
  parentId?: string;
  downloadUrl?: string;
  webUrl?: string;
  thumbnailUrl?: string;
  etag?: string;
  rawMetadata?: object;
  isShared?: boolean;
  canDownload?: boolean;
}

export function createFolderItem(
  id: string,
  name: string,
  provider: string,
  parentId?: string
): CloudItem {
  return {
    id,
    provider,
    name,
    type: CloudItemType.FOLDER,
    modifiedAt: Date.now(),
    parentId
  };
}
import { CloudItem } from '../../models/CloudItem';
import { CloudItemType } from '../../models/CloudItemType';
import { CloudProviderType } from '../../models/CloudProviderType';
import { ensureFileExtension } from '../../../utils/MimeUtils';

// ---------------------------------------------------------------------------
// Graph DTOs
// ---------------------------------------------------------------------------

export interface GraphFolderFacet {
  childCount: number;
}

export interface GraphFileHashes {
  quickXorHash?: string;
  sha1Hash?: string;
}

export interface GraphFileFacet {
  mimeType?: string;
  hashes?: GraphFileHashes;
}

export interface GraphParentReference {
  id?: string;
  driveId?: string;
  path?: string;
}

export interface GraphThumbnailSize {
  url: string;
  width?: number;
  height?: number;
}

export interface GraphThumbnail {
  small?: GraphThumbnailSize;
  medium?: GraphThumbnailSize;
  large?: GraphThumbnailSize;
}

/**
 * A Microsoft Graph DriveItem.
 *
 * The "@microsoft.graph.downloadUrl" annotation is declared here so the
 * interface reflects the JSON shape. Access it via getGraphDownloadUrl()
 * below — ArkTS forbids bracket access on interface fields, even with a
 * quoted string literal.
 */
export interface GraphDriveItem {
  id: string;
  name: string;
  size?: number;
  folder?: GraphFolderFacet;
  file?: GraphFileFacet;
  createdDateTime?: string;
  lastModifiedDateTime?: string;
  parentReference?: GraphParentReference;
  webUrl?: string;
  thumbnails?: GraphThumbnail[];
  eTag?: string;
  '@microsoft.graph.downloadUrl'?: string;
}

export interface GraphUser {
  id: string;
  displayName?: string;
  mail?: string;
  userPrincipalName?: string;
}

// ---------------------------------------------------------------------------
// Annotation accessor
// ---------------------------------------------------------------------------

/**
 * Read the "@microsoft.graph.downloadUrl" annotation from a DriveItem.
 * ArkTS requires Reflect.get for property names that aren't valid identifiers.
 */
export function getGraphDownloadUrl(item: GraphDriveItem): string | undefined {
  const value = Reflect.get(item, '@microsoft.graph.downloadUrl') as string | undefined;
  return value;
}

// ---------------------------------------------------------------------------
// Mapper
// ---------------------------------------------------------------------------

export class OneDriveMapper {
  static toCloudItem(item: GraphDriveItem): CloudItem {
    const isFolder: boolean = item.folder !== undefined;

    const mimeType: string = item.file?.mimeType !== undefined
      ? item.file.mimeType
      : '';

    const displayName: string = isFolder
      ? item.name
      : ensureFileExtension(item.name, mimeType, '');

    return {
      id: item.id,
      provider: CloudProviderType.ONEDRIVE,
      name: displayName,
      type: isFolder ? CloudItemType.FOLDER : CloudItemType.FILE,
      size: item.size,
      childCount: item.folder !== undefined ? item.folder.childCount : undefined,
      mimeType: item.file?.mimeType,
      modifiedAt: item.lastModifiedDateTime
        ? Date.parse(item.lastModifiedDateTime)
        : Date.now(),
      createdAt: item.createdDateTime ? Date.parse(item.createdDateTime) : undefined,
      parentId: item.parentReference?.id,
      downloadUrl: getGraphDownloadUrl(item),
      webUrl: item.webUrl,
      thumbnailUrl: item.thumbnails?.[0]?.small?.url,
      etag: item.eTag,
      rawMetadata: item
    };
  }

  static toCloudItems(items: GraphDriveItem[]): CloudItem[] {
    return items.map(OneDriveMapper.toCloudItem);
  }
}
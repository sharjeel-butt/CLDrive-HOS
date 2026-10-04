import { CloudItem } from '../../models/CloudItem';
import { CloudItemType } from '../../models/CloudItemType';
import { CloudProviderType } from '../../models/CloudProviderType';
import { ensureFileExtension } from '../../../utils/MimeUtils';

// ---------------------------------------------------------------------------
// Dropbox DTOs
// ---------------------------------------------------------------------------

/**
 * Dropbox's Metadata entry. Uses a `'.tag'` discriminator whose name
 * contains a dot — an invalid identifier — so we read it via
 * Reflect.get() in the mapper.
 */
export interface DropboxMetadata {
  '.tag': string;                   // "file" | "folder" | "deleted"
  name: string;
  id?: string;                      // stable ID like "id:xyz"
  path_lower?: string;              // lowercased path
  path_display?: string;            // original-cased path
  size?: number;                    // files only
  client_modified?: string;         // RFC 3339
  server_modified?: string;         // RFC 3339
  rev?: string;
  content_hash?: string;
}



export interface DropboxListFolderResponse {
  entries: DropboxMetadata[];
  cursor: string;
  has_more: boolean;
}

export interface DropboxListFolderContinueResponse {
  entries: DropboxMetadata[];
  cursor: string;
  has_more: boolean;
}

export interface DropboxSearchMatchMetadata {
  metadata: DropboxMetadata;
}

export interface DropboxSearchMatch {
  match_type: Record<string, string>;
  metadata: DropboxSearchMatchMetadata;
}

export interface DropboxSearchResponse {
  matches: DropboxSearchMatch[];
  has_more: boolean;
}

/**
 * Nested name object on the current-account response. Extracted to a
 * named interface because ArkTS forbids object literals used as types.
 */
export interface DropboxAccountName {
  display_name: string;
  given_name?: string;
  surname?: string;
}

export interface DropboxCurrentAccount {
  account_id: string;
  name: DropboxAccountName;
  email: string;
  email_verified: boolean;
  profile_photo_url?: string;
}

export interface DropboxSpaceAllocation {
  '.tag': string;      // 'individual' | 'team'
  allocated?: number;
}

export interface DropboxSpaceUsage {
  used: number;
  allocation: DropboxSpaceAllocation;
}

// ---------------------------------------------------------------------------
// Mapper
// ---------------------------------------------------------------------------

export class DropboxMapper {
  static toCloudItem(meta: DropboxMetadata): CloudItem {
    // The '.tag' field name contains a dot, so ArkTS treats direct
    // access as indexed lookup. Reflect.get is the sanctioned way to
    // read it.
    const tag: string = Reflect.get(meta, '.tag') as string;
    const isFolder: boolean = tag === 'folder';

    // Use the display path as the item ID. Dropbox uses paths as the
    // canonical reference for every operation.
    const id: string = meta.path_display !== undefined
      && meta.path_display.length > 0
      ? meta.path_display
      : (meta.path_lower !== undefined && meta.path_lower.length > 0
        ? meta.path_lower
        : (meta.id !== undefined ? meta.id : meta.name));

    // Files with no extension get one derived from the MIME type.
    // Dropbox does not send a mimeType, so we pass an empty string.
    const displayName: string = isFolder
      ? meta.name
      : ensureFileExtension(meta.name, '', '');

    const modifiedAt: number = meta.server_modified !== undefined
      ? Date.parse(meta.server_modified)
      : (meta.client_modified !== undefined
        ? Date.parse(meta.client_modified)
        : Date.now());

    const createdAt: number | undefined = meta.client_modified !== undefined
      ? Date.parse(meta.client_modified)
      : undefined;

    const parentId: string | undefined = DropboxMapper.parentPathOf(id);

    const result: CloudItem = {
      id: id,
      provider: CloudProviderType.DROPBOX,
      name: displayName,
      type: isFolder ? CloudItemType.FOLDER : CloudItemType.FILE,
      size: meta.size,
      mimeType: undefined,
      modifiedAt: modifiedAt,
      createdAt: createdAt,
      parentId: parentId,
      downloadUrl: undefined,
      webUrl: undefined,
      thumbnailUrl: undefined,
      etag: meta.rev,
      rawMetadata: meta
    };
    return result;
  }

  static toCloudItems(metas: DropboxMetadata[]): CloudItem[] {
    const out: CloudItem[] = [];
    for (let i = 0; i < metas.length; i++) {
      out.push(DropboxMapper.toCloudItem(metas[i]));
    }
    return out;
  }

  /**
   * Given "/Photos/2024/img.jpg", return "/Photos/2024".
   * Given "/Photos", return "" (root).
   * Given "" (root), return undefined.
   */
  static parentPathOf(path: string): string | undefined {
    if (path.length === 0) return undefined;
    const slash: number = path.lastIndexOf('/');
    if (slash < 0) return '';
    return path.substring(0, slash);
  }
}
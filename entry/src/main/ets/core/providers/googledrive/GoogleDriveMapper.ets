import { CloudItem } from '../../models/CloudItem';
import { CloudItemType } from '../../models/CloudItemType';
import { CloudProviderType } from '../../models/CloudProviderType';
import { ensureFileExtension } from '../../../utils/MimeUtils';

// ---------------------------------------------------------------------------
// Google Drive DTOs
// ---------------------------------------------------------------------------

export interface GoogleUser {
  displayName?: string;
  emailAddress?: string;
  photoLink?: string;
}

export interface GoogleAbout {
  user?: GoogleUser;
}

export interface GoogleOwner {
  me?: boolean;
  emailAddress?: string;
  displayName?: string;
}

export interface GoogleShortcutDetails {
  targetId: string;
  targetMimeType: string;
}

export interface GoogleCapabilities {
  canDownload?: boolean;
  canEdit?: boolean;
  canRename?: boolean;
  canDelete?: boolean;
  canCopy?: boolean;
}

export interface GoogleStorageQuota {
  limit?: string;
  usage?: string;
  usageInDrive?: string;
  usageInDriveTrash?: string;
}

export interface GoogleAboutQuota {
  storageQuota?: GoogleStorageQuota;
}

export interface GoogleFile {
  id: string;
  name: string;
  mimeType: string;
  size?: string;
  createdTime?: string;
  modifiedTime?: string;
  parents?: string[];
  webViewLink?: string;
  webContentLink?: string;
  thumbnailLink?: string;
  iconLink?: string;
  trashed?: boolean;
  explicitlyTrashed?: boolean;
  ownedByMe?: boolean;
  shared?: boolean;
  owners?: GoogleOwner[];
  shortcutDetails?: GoogleShortcutDetails;
  capabilities?: GoogleCapabilities;
  fileExtension?: string;
  fullFileExtension?: string;
}

export interface GoogleFileListResponse {
  files?: GoogleFile[];
  nextPageToken?: string;
}

// ---------------------------------------------------------------------------
// Google Drive native MIME types
// ---------------------------------------------------------------------------

export const MIME_FOLDER: string = 'application/vnd.google-apps.folder';
export const MIME_GOOGLE_DOC: string = 'application/vnd.google-apps.document';
export const MIME_GOOGLE_SHEET: string = 'application/vnd.google-apps.spreadsheet';
export const MIME_GOOGLE_SLIDE: string = 'application/vnd.google-apps.presentation';
export const MIME_GOOGLE_DRAWING: string = 'application/vnd.google-apps.drawing';
export const MIME_GOOGLE_FORM: string = 'application/vnd.google-apps.form';
export const MIME_GOOGLE_SHORTCUT: string = 'application/vnd.google-apps.shortcut';

const GOOGLE_NATIVE_PREFIX: string = 'application/vnd.google-apps.';

export function isGoogleNativeFormat(mimeType: string): boolean {
  return mimeType.startsWith(GOOGLE_NATIVE_PREFIX)
    && mimeType !== MIME_FOLDER;
}

export function isFolderMime(mimeType: string): boolean {
  return mimeType === MIME_FOLDER;
}

// ---------------------------------------------------------------------------
// Mapper
// ---------------------------------------------------------------------------

export class GoogleDriveMapper {

  static toCloudItem(file: GoogleFile): CloudItem {
    // Shortcuts are pointers. Resolve them to the target resource so
    // downloads and folder listings reach real content.
    let shortcut: GoogleShortcutDetails | undefined = undefined;
    if (file.mimeType === MIME_GOOGLE_SHORTCUT) {
      shortcut = file.shortcutDetails;
    }

    let effectiveId: string = file.id;
    let effectiveMime: string = file.mimeType;

    if (shortcut !== undefined) {
      effectiveId = shortcut.targetId;
      effectiveMime = shortcut.targetMimeType;
    }

    const isFolder: boolean = isFolderMime(effectiveMime);

    const displayName: string = isFolder
      ? file.name
      : GoogleDriveMapper.resolveDisplayName(file.name, effectiveMime,
        file.fileExtension);

    let size: number | undefined = undefined;
    if (!isFolder && file.size !== undefined && file.size.length > 0) {
      const parsed: number = parseInt(file.size, 10);
      if (!isNaN(parsed)) size = parsed;
    }

    const modifiedAt: number = file.modifiedTime !== undefined
      ? Date.parse(file.modifiedTime)
      : Date.now();

    let createdAt: number | undefined = undefined;
    if (file.createdTime !== undefined) {
      createdAt = Date.parse(file.createdTime);
    }

    let parentId: string | undefined = undefined;
    if (file.parents !== undefined && file.parents.length > 0) {
      parentId = file.parents[0];
    }

    // Shared = someone else owns it. ownedByMe is authoritative.
    let isShared: boolean = false;
    if (file.ownedByMe !== undefined) {
      isShared = file.ownedByMe === false;
    } else if (file.owners !== undefined && file.owners.length > 0) {
      const me: boolean | undefined = file.owners[0].me;
      if (me !== undefined) isShared = me === false;
    }

    // canDownload is undefined unless the provider reports it.
    let canDownload: boolean | undefined = undefined;
    if (file.capabilities !== undefined
      && file.capabilities.canDownload !== undefined) {
      canDownload = file.capabilities.canDownload;
    }

    const result: CloudItem = {
      id: effectiveId,
      provider: CloudProviderType.GOOGLE_DRIVE,
      name: displayName,
      type: isFolder ? CloudItemType.FOLDER : CloudItemType.FILE,
      size: size,
      mimeType: effectiveMime,
      modifiedAt: modifiedAt,
      createdAt: createdAt,
      parentId: parentId,
      downloadUrl: undefined,
      webUrl: file.webViewLink,
      thumbnailUrl: file.thumbnailLink,
      etag: undefined,
      rawMetadata: file,
      isShared: isShared,
      canDownload: canDownload
    };
    return result;
  }

  static toCloudItems(files: GoogleFile[]): CloudItem[] {
    const out: CloudItem[] = [];
    for (let i = 0; i < files.length; i++) {
      out.push(GoogleDriveMapper.toCloudItem(files[i]));
    }
    return out;
  }

  /**
   * Build the display name with an extension when appropriate.
   * Uses the effective MIME (a shortcut's target MIME, not the
   * shortcut MIME) plus Google's own fileExtension if reported.
   */
  private static resolveDisplayName(
    name: string,
    effectiveMime: string,
    fileExtension: string | undefined
  ): string {
    let preferredExt: string = '';
    if (fileExtension !== undefined && fileExtension.length > 0) {
      preferredExt = fileExtension;
    }
    return ensureFileExtension(name, effectiveMime, preferredExt);
  }
}
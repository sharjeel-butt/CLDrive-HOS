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

export interface GoogleFile {
  id: string;
  name: string;
  mimeType: string;
  size?: string;            // string in Drive API (may exceed 2^53)
  createdTime?: string;     // RFC 3339
  modifiedTime?: string;    // RFC 3339
  parents?: string[];
  webViewLink?: string;
  webContentLink?: string;
  thumbnailLink?: string;
  iconLink?: string;
  trashed?: boolean;
  explicitlyTrashed?: boolean;
  shortcutDetails?: GoogleShortcutDetails;
  capabilities?: GoogleCapabilities;
  // Google Drive's authoritative extension fields.
  fileExtension?: string;
  fullFileExtension?: string;
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
    const isFolder: boolean = isFolderMime(file.mimeType);

    // Google Drive's own extension field is authoritative.
    // Fall back to a MIME-derived extension only if Google didn't supply one.
    const displayName: string = isFolder
      ? file.name
      : GoogleDriveMapper.resolveDisplayName(file);

    let size: number | undefined = undefined;
    if (!isFolder && file.size !== undefined && file.size.length > 0) {
      const parsed: number = parseInt(file.size, 10);
      if (!isNaN(parsed)) size = parsed;
    }

    const modifiedAt: number = file.modifiedTime
      ? Date.parse(file.modifiedTime)
      : Date.now();

    const createdAt: number | undefined = file.createdTime
      ? Date.parse(file.createdTime)
      : undefined;

    const parentId: string | undefined =
      file.parents !== undefined && file.parents.length > 0
        ? file.parents[0]
        : undefined;

    return {
      id: file.id,
      provider: CloudProviderType.GOOGLE_DRIVE,
      name: displayName,
      type: isFolder ? CloudItemType.FOLDER : CloudItemType.FILE,
      size: size,
      mimeType: file.mimeType,
      modifiedAt: modifiedAt,
      createdAt: createdAt,
      parentId: parentId,
      downloadUrl: undefined,
      webUrl: file.webViewLink,
      thumbnailUrl: file.thumbnailLink,
      etag: undefined,
      rawMetadata: file
    };
  }

  static toCloudItems(files: GoogleFile[]): CloudItem[] {
    return files.map(GoogleDriveMapper.toCloudItem);
  }

  /**
   * Build the display name, ensuring it carries the extension.
   *
   * Priority order:
   *   1. If Google reports a `fileExtension`, use it.
   *   2. Otherwise, derive it from the MIME type as a last resort.
   *   3. Google native formats (Docs/Sheets/Slides) have no extension
   *      and are returned as-is.
   */
  private static resolveDisplayName(file: GoogleFile): string {
    const preferredExt: string =
      file.fileExtension !== undefined && file.fileExtension.length > 0
        ? file.fileExtension
        : '';

    return ensureFileExtension(file.name, file.mimeType, preferredExt);
  }

  private static extensionFromMime(mimeType: string): string {
    const mime = mimeType.toLowerCase();
    if (mime.startsWith('application/vnd.google-apps.')) return '';
    if (mime === 'application/pdf') return 'pdf';
    if (mime === 'application/zip') return 'zip';
    if (mime === 'application/json') return 'json';
    if (mime === 'application/xml') return 'xml';
    if (mime === 'application/msword') return 'doc';
    if (mime.indexOf('wordprocessingml') >= 0) return 'docx';
    if (mime === 'application/vnd.ms-excel') return 'xls';
    if (mime.indexOf('spreadsheetml') >= 0) return 'xlsx';
    if (mime === 'application/vnd.ms-powerpoint') return 'ppt';
    if (mime.indexOf('presentationml') >= 0) return 'pptx';
    if (mime === 'text/plain') return 'txt';
    if (mime === 'text/csv') return 'csv';
    if (mime === 'text/html') return 'html';
    if (mime === 'image/jpeg') return 'jpg';
    if (mime === 'image/png') return 'png';
    if (mime === 'image/gif') return 'gif';
    if (mime === 'image/webp') return 'webp';
    if (mime === 'image/svg+xml') return 'svg';
    if (mime === 'audio/mpeg') return 'mp3';
    if (mime === 'video/mp4') return 'mp4';
    if (mime === 'video/quicktime') return 'mov';
    return '';
  }

}
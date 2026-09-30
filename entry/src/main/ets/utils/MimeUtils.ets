/**
 * Convert a MIME type to a canonical file extension (without the dot).
 * Returns an empty string if the MIME type isn't recognized.
 */
export function extensionFromMimeType(mimeType: string | undefined | null): string {
  if (mimeType === undefined || mimeType === null || mimeType.length === 0) {
    return '';
  }
  const mime = mimeType.toLowerCase();

  if (mime.startsWith('application/vnd.google-apps.')) return '';
  if (mime === 'application/pdf') return 'pdf';
  if (mime === 'application/zip') return 'zip';
  if (mime === 'application/x-tar') return 'tar';
  if (mime === 'application/gzip') return 'gz';
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
  if (mime === 'text/markdown') return 'md';
  if (mime === 'image/jpeg') return 'jpg';
  if (mime === 'image/png') return 'png';
  if (mime === 'image/gif') return 'gif';
  if (mime === 'image/webp') return 'webp';
  if (mime === 'image/svg+xml') return 'svg';
  if (mime === 'image/bmp') return 'bmp';
  if (mime === 'image/tiff') return 'tiff';
  if (mime === 'image/heic') return 'heic';
  if (mime === 'audio/mpeg') return 'mp3';
  if (mime === 'audio/wav') return 'wav';
  if (mime === 'audio/flac') return 'flac';
  if (mime === 'audio/ogg') return 'ogg';
  if (mime === 'video/mp4') return 'mp4';
  if (mime === 'video/quicktime') return 'mov';
  if (mime === 'video/webm') return 'webm';
  if (mime === 'video/x-matroska') return 'mkv';
  return '';
}

/**
 * Convert a file extension (without the dot) to a canonical MIME type.
 * Returns an empty string when the extension isn't recognized.
 *
 * This is the inverse of extensionFromMimeType and is used when a
 * provider hands us a file without a MIME — most notably Dropbox,
 * which doesn't expose one.
 */
export function mimeTypeForExtension(ext: string | undefined | null): string {
  if (ext === undefined || ext === null || ext.length === 0) return '';
  const e = ext.toLowerCase();

  if (e === 'pdf') return 'application/pdf';
  if (e === 'zip') return 'application/zip';
  if (e === 'tar') return 'application/x-tar';
  if (e === 'gz') return 'application/gzip';
  if (e === 'json') return 'application/json';
  if (e === 'xml') return 'application/xml';
  if (e === 'doc') return 'application/msword';
  if (e === 'docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  if (e === 'xls') return 'application/vnd.ms-excel';
  if (e === 'xlsx') return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  if (e === 'ppt') return 'application/vnd.ms-powerpoint';
  if (e === 'pptx') return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
  if (e === 'txt') return 'text/plain';
  if (e === 'md') return 'text/markdown';
  if (e === 'csv') return 'text/csv';
  if (e === 'html' || e === 'htm') return 'text/html';
  if (e === 'jpg' || e === 'jpeg') return 'image/jpeg';
  if (e === 'png') return 'image/png';
  if (e === 'gif') return 'image/gif';
  if (e === 'webp') return 'image/webp';
  if (e === 'svg') return 'image/svg+xml';
  if (e === 'bmp') return 'image/bmp';
  if (e === 'tif' || e === 'tiff') return 'image/tiff';
  if (e === 'heic') return 'image/heic';
  if (e === 'ico') return 'image/x-icon';
  if (e === 'mp3') return 'audio/mpeg';
  if (e === 'wav') return 'audio/wav';
  if (e === 'flac') return 'audio/flac';
  if (e === 'm4a') return 'audio/mp4';
  if (e === 'aac') return 'audio/aac';
  if (e === 'ogg') return 'audio/ogg';
  if (e === 'wma') return 'audio/x-ms-wma';
  if (e === 'mp4') return 'video/mp4';
  if (e === 'mov') return 'video/quicktime';
  if (e === 'webm') return 'video/webm';
  if (e === 'mkv') return 'video/x-matroska';
  if (e === 'avi') return 'video/x-msvideo';
  if (e === 'wmv') return 'video/x-ms-wmv';
  if (e === 'm4v') return 'video/x-m4v';
  return '';
}

/**
 * Derive a MIME type from a file name's extension.
 * Returns an empty string when nothing can be inferred.
 */
export function mimeTypeForFileName(
  name: string | undefined | null
): string {
  if (name === undefined || name === null || name.length === 0) return '';
  const dot = name.lastIndexOf('.');
  if (dot <= 0 || dot === name.length - 1) return '';
  return mimeTypeForExtension(name.substring(dot + 1));
}

/**
 * Best-effort MIME resolution for a locally stored file.
 *
 * Order of preference:
 *   1. The provider-supplied MIME, if it's a real one. Google-native
 *      MIMEs like `application/vnd.google-apps.document` are skipped
 *      because no local viewer recognises them.
 *   2. The file extension derived from the file name.
 *   3. `application/octet-stream` as a last resort.
 */
export function resolveMimeType(
  providedMime: string | undefined | null,
  fileName: string | undefined | null
): string {
  if (providedMime !== undefined && providedMime !== null
    && providedMime.length > 0
    && providedMime !== 'application/octet-stream'
    && !providedMime.startsWith('application/vnd.google-apps.')) {
    return providedMime;
  }

  const fromExt: string = mimeTypeForFileName(fileName);
  if (fromExt.length > 0) return fromExt;

  return 'application/octet-stream';
}

/**
 * Return true if the name ends with a plausible file extension.
 */
export function hasFileExtension(name: string | undefined | null): boolean {
  if (name === undefined || name === null || name.length === 0) {
    return false;
  }
  const dot = name.lastIndexOf('.');
  if (dot <= 0 || dot === name.length - 1) return false;
  const ext = name.substring(dot + 1);
  if (ext.length < 1 || ext.length > 5) return false;
  return /^[a-zA-Z0-9]+$/.test(ext);
}

/**
 * Ensure the file name carries an extension. Null-safe: if `name` is
 * missing entirely, returns an empty string rather than crashing.
 */
export function ensureFileExtension(
  name: string | undefined | null,
  mimeType: string | undefined | null,
  preferredExtension: string | undefined | null
): string {
  if (name === undefined || name === null || name.length === 0) {
    return '';
  }

  const safeMime: string =
    mimeType !== undefined && mimeType !== null ? mimeType.toLowerCase() : '';
  const safeExt: string =
    preferredExtension !== undefined && preferredExtension !== null
      ? preferredExtension
      : '';

  if (safeMime === 'application/vnd.google-apps.document') {
    return appendIfMissing(name, 'docx');
  }
  if (safeMime === 'application/vnd.google-apps.spreadsheet') {
    return appendIfMissing(name, 'xlsx');
  }
  if (safeMime === 'application/vnd.google-apps.presentation') {
    return appendIfMissing(name, 'pptx');
  }
  if (safeMime === 'application/vnd.google-apps.drawing') {
    return appendIfMissing(name, 'png');
  }
  if (safeMime === 'application/vnd.google-apps.form') {
    return appendIfMissing(name, 'zip');
  }
  if (safeMime.startsWith('application/vnd.google-apps.')) {
    return name;
  }

  if (safeExt.length > 0) {
    if (name.toLowerCase().endsWith(`.${safeExt.toLowerCase()}`)) {
      return name;
    }
    if (!hasFileExtension(name)) {
      return `${name}.${safeExt}`;
    }
    return name;
  }

  if (hasFileExtension(name)) return name;
  const derived = extensionFromMimeType(safeMime);
  if (derived.length === 0) return name;
  return `${name}.${derived}`;
}

function appendIfMissing(name: string, ext: string): string {
  if (name.toLowerCase().endsWith(`.${ext}`)) return name;
  if (hasFileExtension(name)) return name;
  return `${name}.${ext}`;
}
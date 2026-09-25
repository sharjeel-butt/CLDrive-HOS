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
 * Return true if the name ends with a plausible file extension.
 * Null-safe: returns false for undefined / null / empty inputs.
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
  // Guard against a missing name — the callers will fall back to a
  // placeholder when they see an empty result.
  if (name === undefined || name === null || name.length === 0) {
    return '';
  }

  const safeMime: string =
    mimeType !== undefined && mimeType !== null ? mimeType.toLowerCase() : '';
  const safeExt: string =
    preferredExtension !== undefined && preferredExtension !== null
      ? preferredExtension
      : '';

  // Google native formats — give them a familiar extension.
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
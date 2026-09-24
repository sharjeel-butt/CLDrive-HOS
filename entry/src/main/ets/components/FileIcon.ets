/**
 * FileIcon
 * ----------------------------------------------------------------------------
 * A colored badge representing a file's type. The badge shows a short label
 * (PDF, DOC, XLS, IMG, VID, AUD, ZIP, </>, etc.) on a type-specific color.
 *
 * Works at any size — from a 36 vp row icon to a 120 vp detail-page badge.
 *
 * Usage:
 *   FileIcon({ fileName: item.name, mimeType: item.mimeType ?? '', badgeSize: 36 })
 *
 * Note: props are strings and numbers only (no interface props) to stay
 * compatible with @Prop's strict ArkTS typing.
 */

export interface FileIconInfo {
  label: string;
  color: string;
}

function extensionOf(name: string): string {
  const dot: number = name.lastIndexOf('.');
  if (dot < 0 || dot === name.length - 1) {
    return '';
  }
  return name.substring(dot + 1).toLowerCase();
}

export function fileIconInfo(fileName: string, mimeType: string): FileIconInfo {
  const mime: string = mimeType.toLowerCase();
  const ext: string = extensionOf(fileName);

  // ---- PDF ----
  if (mime === 'application/pdf' || ext === 'pdf') {
    return { label: 'PDF', color: '#E53935' };
  }

  // ---- Word ----
  if (mime.indexOf('word') >= 0 || mime.indexOf('opendocument.text') >= 0
    || ext === 'doc' || ext === 'docx' || ext === 'odt' || ext === 'rtf') {
    return { label: 'DOC', color: '#1E88E5' };
  }

  // ---- Excel / Spreadsheet ----
  if (mime.indexOf('excel') >= 0 || mime.indexOf('spreadsheet') >= 0
    || ext === 'xls' || ext === 'xlsx' || ext === 'ods' || ext === 'csv') {
    return { label: 'XLS', color: '#43A047' };
  }

  // ---- PowerPoint ----
  if (mime.indexOf('powerpoint') >= 0 || mime.indexOf('presentation') >= 0
    || ext === 'ppt' || ext === 'pptx' || ext === 'odp') {
    return { label: 'PPT', color: '#EF6C00' };
  }

  // ---- Image ----
  if (mime.indexOf('image/') === 0
    || ext === 'png' || ext === 'jpg' || ext === 'jpeg' || ext === 'gif'
    || ext === 'webp' || ext === 'bmp' || ext === 'svg' || ext === 'heic'
    || ext === 'tiff' || ext === 'ico') {
    return { label: 'IMG', color: '#8E24AA' };
  }

  // ---- Video ----
  if (mime.indexOf('video/') === 0
    || ext === 'mp4' || ext === 'mov' || ext === 'avi' || ext === 'mkv'
    || ext === 'webm' || ext === 'flv' || ext === 'wmv' || ext === 'm4v') {
    return { label: 'VID', color: '#D81B60' };
  }

  // ---- Audio ----
  if (mime.indexOf('audio/') === 0
    || ext === 'mp3' || ext === 'wav' || ext === 'flac' || ext === 'm4a'
    || ext === 'aac' || ext === 'ogg' || ext === 'wma') {
    return { label: 'AUD', color: '#00897B' };
  }

  // ---- Archive ----
  if (ext === 'zip' || ext === 'rar' || ext === '7z' || ext === 'tar'
    || ext === 'gz' || ext === 'bz2' || ext === 'xz'
    || mime.indexOf('zip') >= 0 || mime.indexOf('compressed') >= 0) {
    return { label: 'ZIP', color: '#616161' };
  }

  // ---- Code ----
  if (ext === 'js' || ext === 'ts' || ext === 'ets' || ext === 'py'
    || ext === 'java' || ext === 'kt' || ext === 'c' || ext === 'cpp'
    || ext === 'h' || ext === 'hpp' || ext === 'cs' || ext === 'rb'
    || ext === 'go' || ext === 'rs' || ext === 'swift' || ext === 'php'
    || ext === 'html' || ext === 'htm' || ext === 'css' || ext === 'scss'
    || ext === 'json' || ext === 'xml' || ext === 'yaml' || ext === 'yml'
    || ext === 'sh' || ext === 'bat' || ext === 'ps1') {
    return { label: '</>', color: '#37474F' };
  }

  // ---- Plain text ----
  if (mime.indexOf('text/') === 0
    || ext === 'txt' || ext === 'md' || ext === 'log') {
    return { label: 'TXT', color: '#78909C' };
  }

  // ---- Font ----
  if (ext === 'ttf' || ext === 'otf' || ext === 'woff' || ext === 'woff2') {
    return { label: 'Aa', color: '#5E35B1' };
  }

  // ---- Google native formats ----
  if (mime === 'application/vnd.google-apps.document') {
    return { label: 'DOC', color: '#4285F4' };   // Docs blue
  }
  if (mime === 'application/vnd.google-apps.spreadsheet') {
    return { label: 'XLS', color: '#0F9D58' };   // Sheets green
  }
  if (mime === 'application/vnd.google-apps.presentation') {
    return { label: 'PPT', color: '#F4B400' };   // Slides yellow
  }
  if (mime === 'application/vnd.google-apps.drawing') {
    return { label: 'DRW', color: '#DB4437' };   // Drawings red
  }
  if (mime === 'application/vnd.google-apps.form') {
    return { label: 'FRM', color: '#673AB7' };   // Forms purple
  }
  if (mime === 'application/vnd.google-apps.shortcut') {
    return { label: 'LNK', color: '#5F6368' };   // Shortcut gray
  }

  // ---- Fallback: use the extension itself ----
  if (ext.length > 0) {
    return { label: ext.substring(0, 3).toUpperCase(), color: '#607D8B' };
  }

  return { label: 'FILE', color: '#607D8B' };
}

@Component
export struct FileIcon {
  @Prop fileName: string = '';
  @Prop mimeType: string = '';
  @Prop badgeSize: number = 36;
  @Prop rounded: boolean = false;

  build() {
    Column() {
      Text(fileIconInfo(this.fileName, this.mimeType).label)
        .fontSize(this.labelFontSize())
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
    }
    .width(this.badgeSize)
    .height(this.badgeSize)
    .borderRadius(this.rounded ? this.badgeSize / 2 : this.badgeSize * 0.22)
    .backgroundColor(fileIconInfo(this.fileName, this.mimeType).color)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  private labelFontSize(): number {
    const len: number = fileIconInfo(this.fileName, this.mimeType).label.length;
    if (len <= 1) {
      return this.badgeSize * 0.55;
    }
    if (len === 2) {
      return this.badgeSize * 0.42;
    }
    if (len === 3) {
      return this.badgeSize * 0.32;
    }
    return this.badgeSize * 0.28; // for "</>" (4 chars)
  }
}
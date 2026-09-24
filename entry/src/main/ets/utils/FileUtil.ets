import { fileIo as fs } from '@kit.CoreFileKit';

export class LocalFileService {
  private static readonly TAG = 'LocalFileService';

  /** Read the entire file into an ArrayBuffer. */
  static async readAll(pathOrUri: string): Promise<ArrayBuffer> {
    const path = LocalFileService.toPath(pathOrUri);
    const stat = fs.statSync(path);
    const buffer = new ArrayBuffer(stat.size);
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      fs.readSync(file.fd, buffer);
      return buffer;
    } finally {
      fs.closeSync(file);
    }
  }

  /** Read a byte range from a file. */
  static async readRange(
    pathOrUri: string, offset: number, length: number
  ): Promise<ArrayBuffer> {
    const path = LocalFileService.toPath(pathOrUri);
    const buffer = new ArrayBuffer(length);
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      fs.readSync(file.fd, buffer, { offset, length });
      return buffer;
    } finally {
      fs.closeSync(file);
    }
  }

  /** Write an ArrayBuffer to a file, creating it if needed. */
  static async writeAll(pathOrUri: string, content: ArrayBuffer): Promise<void> {
    const path = LocalFileService.toPath(pathOrUri);
    const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    try {
      fs.writeSync(file.fd, content);
    } finally {
      fs.closeSync(file);
    }
  }

  /** Get file size in bytes. */
  static async getSize(pathOrUri: string): Promise<number> {
    const path = LocalFileService.toPath(pathOrUri);
    return fs.statSync(path).size;
  }

  /** Convert a file:// URI or plain path into a filesystem path. */
  private static toPath(pathOrUri: string): string {
    if (pathOrUri.startsWith('file://')) {
      return pathOrUri.substring('file://'.length);
    }
    return pathOrUri;
  }
}
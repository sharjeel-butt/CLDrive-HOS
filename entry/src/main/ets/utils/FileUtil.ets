import { fileIo as fs } from '@kit.CoreFileKit';
import { fileUri } from '@kit.CoreFileKit';
import { Logger } from './Logger';

export class LocalFileService {
  private static readonly TAG = 'LocalFileService';

  /** Read the entire file into an ArrayBuffer. */
  static async readAll(pathOrUri: string): Promise<ArrayBuffer> {
    if (pathOrUri === undefined || pathOrUri === null || pathOrUri.length === 0) {
      throw new Error('readAll: path is required');
    }
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
    if (pathOrUri === undefined || pathOrUri === null || pathOrUri.length === 0) {
      throw new Error('readRange: path is required');
    }
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
    if (pathOrUri === undefined || pathOrUri === null || pathOrUri.length === 0) {
      throw new Error('writeAll: path is required');
    }
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
    if (pathOrUri === undefined || pathOrUri === null || pathOrUri.length === 0) {
      throw new Error('getSize: path is required');
    }
    const path = LocalFileService.toPath(pathOrUri);
    return fs.statSync(path).size;
  }

  /**
   * Convert a file:// URI (from the picker) or a plain path into a
   * real filesystem path that fs APIs can open.
   */
  private static toPath(pathOrUri: string): string {
    if (pathOrUri === undefined || pathOrUri === null || pathOrUri.length === 0) {
      throw new Error('toPath: path is required');
    }

    if (pathOrUri.startsWith('file://')) {
      try {
        const uriObj = new fileUri.FileUri(pathOrUri);
        const realPath: string = uriObj.path;
        Logger.info(LocalFileService.TAG, `Converted URI to path: ${realPath}`);
        return realPath;
      } catch (e) {
        const err: Error = e as Error;
        Logger.warn(
          LocalFileService.TAG,
          `fileUri conversion failed, using raw path: ${err.message}`
        );
        return pathOrUri.substring('file://'.length);
      }
    }
    return pathOrUri;
  }
}
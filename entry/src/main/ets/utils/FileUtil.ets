import { fileIo as fs } from '@kit.CoreFileKit';
import { fileUri } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from './Logger';

/**
 * HarmonyOS fs error codes — the numeric values users see when a
 * file-system call fails. Mapped to human-readable text.
 */
const FS_ERROR_MAP: Map<number, string> = new Map([
  [13900001, 'Operation not permitted'],
  [13900002, 'No such file or directory'],
  [13900003, 'No such process'],
  [13900004, 'Interrupted system call'],
  [13900005, 'I/O error'],
  [13900011, 'Out of memory'],
  [13900012, 'Permission denied'],
  [13900013, 'Bad address'],
  [13900014, 'Device or resource busy'],
  [13900015, 'File already exists'],
  [13900016, 'Cross-device link'],
  [13900017, 'No such device'],
  [13900018, 'Not a directory'],
  [13900019, 'Is a directory'],
  [13900020, 'Invalid argument'],
  [13900021, 'File table overflow'],
  [13900022, 'Too many open files'],
  [13900023, 'Text file busy'],
  [13900024, 'File too large'],
  [13900025, 'No space left on device'],
  [13900026, 'Illegal seek'],
  [13900027, 'Read-only file system'],
  [13900028, 'Too many links'],
  [13900029, 'Broken pipe'],
  [13900030, 'Math argument out of domain'],
  [13900031, 'Math result not representable'],
  [13900032, 'Resource deadlock would occur'],
  [13900033, 'File name too long'],
  [13900035, 'Function not implemented'],
  [13900036, 'Directory not empty'],
  [13900037, 'Too many symbolic links'],
  [13900038, 'No data available'],
  [13900039, 'Timer expired']
]);

/**
 * Convert a raw error into something a user can read. Numeric codes
 * are mapped to their OS description; anything unrecognized is
 * returned with the code so the user can search for it.
 */
export function formatFsError(e: Error | BusinessError | undefined | null): string {
  if (e === undefined || e === null) return 'Unknown error';

  const be = e as BusinessError;
  const code: number | undefined = be.code;
  const msg: string = be.message !== undefined && be.message !== null
    ? be.message
    : String(e);

  if (code !== undefined && code > 0) {
    const mapped: string | undefined = FS_ERROR_MAP.get(code);
    if (mapped !== undefined) {
      return `${mapped} (code ${code})`;
    }
    return `${msg} (code ${code})`;
  }
  return msg;
}

export class LocalFileService {
  private static readonly TAG = 'LocalFileService';

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

  static async getSize(pathOrUri: string): Promise<number> {
    if (pathOrUri === undefined || pathOrUri === null || pathOrUri.length === 0) {
      throw new Error('getSize: path is required');
    }
    const path = LocalFileService.toPath(pathOrUri);
    return fs.statSync(path).size;
  }

  /**
   * Open a destination for writing. Tries three strategies in order:
   *   1. Pass the full file:// URI to fs.openSync (the picker grants
   *      permission to the URI string, not to the underlying path).
   *   2. Strip the file:// prefix and pass the remaining path.
   *   3. Resolve via fileUri.FileUri(uri).path.
   *
   * Returns the open File handle. Logs each failed attempt with a
   * formatted error so the terminal tells us why.
   */
  static openDestinationForWrite(targetUri: string): fs.File {
    const flags =
      fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC;

    // ---- Attempt 1: pass the URI directly ----
    if (targetUri.startsWith('file://')) {
      try {
        const f = fs.openSync(targetUri, flags);
        Logger.info(LocalFileService.TAG, `openSync(uri) OK: ${targetUri}`);
        return f;
      } catch (e) {
        Logger.warn(
          LocalFileService.TAG,
          `openSync(uri) failed: ${formatFsError(e as Error)}`
        );
      }
    }

    // ---- Attempt 2: strip file:// prefix ----
    if (targetUri.startsWith('file://')) {
      const stripped: string = targetUri.substring('file://'.length);
      try {
        const f = fs.openSync(stripped, flags);
        Logger.info(LocalFileService.TAG, `openSync(stripped) OK: ${stripped}`);
        return f;
      } catch (e) {
        Logger.warn(
          LocalFileService.TAG,
          `openSync(stripped) failed: ${formatFsError(e as Error)}`
        );
      }
    }

    // ---- Attempt 3: resolve via fileUri ----
    try {
      const resolved: string = new fileUri.FileUri(targetUri).path;
      const f = fs.openSync(resolved, flags);
      Logger.info(LocalFileService.TAG, `openSync(resolved) OK: ${resolved}`);
      return f;
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(
        LocalFileService.TAG,
        `All open attempts failed for ${targetUri}: ${formatFsError(err)}`
      );
      throw new Error(`Cannot open destination: ${formatFsError(err)}`);
    }
  }

  /**
   * Create a directory and all its parents, using the recursive flag
   * that HarmonyOS supports on newer SDK versions. Falls back to a
   * manual walk if the recursive form isn't available.
   *
   * Throws with a readable message if the directory cannot be created.
   */
  static ensureDir(dirPath: string): void {
    if (dirPath === undefined || dirPath === null || dirPath.length === 0) {
      throw new Error('ensureDir: path is required');
    }

    // Already exists → done.
    try {
      const stat = fs.statSync(dirPath);
      if (stat.isDirectory()) return;
      throw new Error(`Path exists but is not a directory: ${dirPath}`);
    } catch (e) {
      const err: Error = e as Error;
      // 13900002 = not found → proceed to create.
      // Anything else → rethrow.
      if (err.message.indexOf('No such file') < 0
        && err.message.indexOf('13900002') < 0) {
        // statSync threw for another reason — attempt create anyway.
      }
    }

    // Primary strategy: recursive mkdir (API 12+).
    try {
      fs.mkdirSync(dirPath, true);
      Logger.info(LocalFileService.TAG, `mkdirSync(recursive) OK: ${dirPath}`);
      return;
    } catch (e) {
      const err: Error = e as Error;
      Logger.warn(
        LocalFileService.TAG,
        `mkdirSync(recursive) failed: ${formatFsError(err)}`
      );
    }

    // Fallback: walk up to the nearest existing ancestor and create
    // segments from shallowest to deepest.
    const toCreate: string[] = [dirPath];
    let current: string = dirPath;
    while (current.length > 1) {
      const slash: number = current.lastIndexOf('/');
      if (slash <= 0) break;
      current = current.substring(0, slash);
      try {
        fs.accessSync(current);
        break;
      } catch (_) {
        toCreate.push(current);
      }
    }
    toCreate.reverse();

    for (let i = 0; i < toCreate.length; i++) {
      const dir: string = toCreate[i];
      try {
        fs.mkdirSync(dir);
        Logger.info(LocalFileService.TAG, `mkdirSync OK: ${dir}`);
      } catch (e) {
        const err: Error = e as Error;
        if (err.message.indexOf('exist') >= 0
          || err.message.indexOf('EEXIST') >= 0) {
          continue;
        }
        Logger.error(
          LocalFileService.TAG,
          `mkdirSync failed for ${dir}: ${formatFsError(err)}`
        );
        throw new Error(`Cannot create directory ${dir}: ${formatFsError(err)}`);
      }
    }
  }

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
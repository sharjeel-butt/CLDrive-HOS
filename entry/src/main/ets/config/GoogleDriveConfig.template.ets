import { Endpoints } from './Endpoints';
import { Logger } from '../utils/Logger';

export class GoogleDriveConfig {
  // ---------------------------------------------------------------------------
  // Credentials — replace with your Google Cloud values
  // ---------------------------------------------------------------------------
  static readonly CLIENT_ID: string = 'YOUR_CLIENT_ID';
  static readonly CLIENT_SECRET: string = 'YOUR_CLIENT_SECRET';
  static readonly REDIRECT_URI: string = Endpoints.GOOGLE_REDIRECT_URI;

  // ---------------------------------------------------------------------------
  // OAuth scopes
  // ---------------------------------------------------------------------------
  static readonly SCOPES: string =
    'https://www.googleapis.com/auth/drive.readonly ' +
      'https://www.googleapis.com/auth/drive.file';

  // ---------------------------------------------------------------------------
  // Endpoints
  // ---------------------------------------------------------------------------
  static readonly AUTH_URL: string = Endpoints.GOOGLE_AUTH_URL;
  static readonly TOKEN_URL: string = Endpoints.GOOGLE_TOKEN_URL;
  static readonly DRIVE_API: string = Endpoints.GOOGLE_DRIVE_API;
  static readonly UPLOAD_API: string = Endpoints.GOOGLE_DRIVE_UPLOAD_API;

  // ---------------------------------------------------------------------------
  // Transfer constraints
  // ---------------------------------------------------------------------------
  /** Files at or below this size are uploaded in a single PUT to the session URL. */
  static readonly SIMPLE_UPLOAD_MAX_BYTES: number = 5 * 1024 * 1024;

  /** Must be a multiple of 256 KiB except for the last chunk. */
  static readonly UPLOAD_CHUNK_BYTES: number = 256 * 1024 * 8; // 2 MB

  // ---------------------------------------------------------------------------
  // Timeouts
  // ---------------------------------------------------------------------------
  static readonly REQUEST_TIMEOUT_MS: number = 30_000;
  static readonly TRANSFER_TIMEOUT_MS: number = 120_000;

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------
  static validate(): boolean {
    const clientId: string = GoogleDriveConfig.CLIENT_ID.trim();
    const secret: string = GoogleDriveConfig.CLIENT_SECRET.trim();

    if (clientId.length === 0 || clientId.indexOf('PASTE_YOUR') >= 0) {
      Logger.error('GoogleDriveConfig', 'CLIENT_ID is not configured.');
      return false;
    }
    if (secret.length === 0 || secret.indexOf('PASTE_YOUR') >= 0) {
      Logger.error('GoogleDriveConfig', 'CLIENT_SECRET is not configured.');
      return false;
    }
    if (!GoogleDriveConfig.REDIRECT_URI.startsWith('http://127.0.0.1')
      && !GoogleDriveConfig.REDIRECT_URI.startsWith('http://localhost')) {
      Logger.warn(
        'GoogleDriveConfig',
        'REDIRECT_URI should point to a loopback address for Web application clients.'
      );
    }
    return true;
  }
}
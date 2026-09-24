import { Endpoints } from './Endpoints';
import { Logger } from '../utils/Logger';

/**
 * OneDriveConfig
 * ----------------------------------------------------------------------------
 * Static configuration for the OneDrive provider.
 *
 * This app uses Authorization Code + PKCE, the Microsoft-recommended
 * configuration for native mobile apps. There is NO client secret.
 *
 * Azure prerequisites:
 *   - Supported account types: Multitenant + personal Microsoft accounts
 *   - Redirect URI (Mobile and desktop platform): https://cl.drive/oauth
 *   - Advanced settings → Allow public client flows: Yes
 *   - Delegated API permissions: Files.ReadWrite, User.Read, offline_access
 */
export class OneDriveConfig {
  // ---------------------------------------------------------------------------
  // Credentials — PUBLIC CLIENT with PKCE
  // ---------------------------------------------------------------------------

  /** Application (client) ID from Azure App Registration → Overview. */
  static readonly CLIENT_ID: string = '31879cd9-2ab1-41e2-a368-ff7d0d9633ec';
  // CLIENT_SECRET intentionally absent — PKCE public client.

  static readonly REDIRECT_URI: string = Endpoints.TOKEN_EXCHANGE_REDIRECT;
  static readonly SCOPES: string = 'Files.ReadWrite offline_access User.Read';
  // ---------------------------------------------------------------------------
  // Endpoints
  // ---------------------------------------------------------------------------

  static readonly AUTH_URL: string = Endpoints.MS_AUTHORIZE;
  static readonly TOKEN_URL: string = Endpoints.MS_TOKEN;
  static readonly GRAPH_BASE: string = Endpoints.GRAPH_BASE;
  // ---------------------------------------------------------------------------
  // Transfer constraints
  // ---------------------------------------------------------------------------

  static readonly SIMPLE_UPLOAD_MAX_BYTES: number = 4 * 1024 * 1024;
  static readonly UPLOAD_CHUNK_BYTES: number = 320 * 1024 * 10;
  // ---------------------------------------------------------------------------
  // Timeouts
  // ---------------------------------------------------------------------------

  static readonly REQUEST_TIMEOUT_MS: number = 30_000;
  static readonly TRANSFER_TIMEOUT_MS: number = 120_000;

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  static validate(): boolean {
    if (OneDriveConfig.CLIENT_ID.trim().length === 0) {
      Logger.error('OneDriveConfig', 'CLIENT_ID is empty.');
      return false;
    }
    if (!OneDriveConfig.REDIRECT_URI.startsWith('https://')) {
      Logger.error('OneDriveConfig', 'REDIRECT_URI must use https:// scheme.');
      return false;
    }
    if (!OneDriveConfig.SCOPES.includes('offline_access')) {
      Logger.warn(
        'OneDriveConfig',
        'SCOPES missing offline_access — no refresh tokens will be issued.'
      );
    }
    return true;
  }
}
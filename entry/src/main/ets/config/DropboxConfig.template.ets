import { Endpoints } from './Endpoints';
import { Logger } from '../utils/Logger';

/**
 * DropboxConfig
 * ----------------------------------------------------------------------------
 * Static configuration for the Dropbox provider.
 *
 * CLDrive uses the OAuth 2.0 Authorization Code flow with PKCE. Dropbox
 * supports PKCE for public clients (mobile apps) — no client secret is
 * embedded in the binary.
 *
 * APP CONSOLE SETUP CHECKLIST
 * ----------------------------------------------------------------------------
 *   1. Dropbox App Console → https://www.dropbox.com/developers/apps
 *   2. Create app → Scoped access → "Full Dropbox" → name "CLDrive".
 *   3. OAuth 2.0 → Redirect URIs → add "https://cl.drive/dropbox-oauth".
 *   4. Permissions tab → enable:
 *        - account_info.read
 *        - files.metadata.read
 *        - files.metadata.write
 *        - files.content.read
 *        - files.content.write
 *   5. Copy the "App key" into CLIENT_ID below.
 *   6. (Optional) Submit for Production to allow more than 500 users.
 */
export class DropboxConfig {

  // ---------------------------------------------------------------------------
  // Credentials — PUBLIC CLIENT with PKCE
  // ---------------------------------------------------------------------------

  /**
   * Dropbox "App key" from the App Console. This is Dropbox's name for
   * what every other provider calls a client ID.
   */
  static readonly CLIENT_ID: string = 'YOUR_CLIENT_ID';

  /**
   * Dropbox returns a refresh token when the request includes
   * `token_access_type=offline`. No client secret is needed for the
   * PKCE token exchange.
   *
   * If you later migrate to a confidential client model (server-side
   * token exchange), re-introduce CLIENT_SECRET here and send it in
   * the token request. For the PKCE flow used by CLDrive, keep it empty.
   */
  static readonly CLIENT_SECRET: string = '';

  /**
   * Must EXACTLY match a redirect URI registered in the App Console.
   * Dropbox uses HTTPS URLs or custom schemes; we reuse the CLDrive
   * domain pattern already used for Microsoft.
   */
  static readonly REDIRECT_URI: string = Endpoints.DROPBOX_REDIRECT_URI;

  // ---------------------------------------------------------------------------
  // OAuth scopes
  // ---------------------------------------------------------------------------
  /**
   * Space-separated list of Dropbox scopes. Every scope listed here
   * MUST also be enabled on the "Permissions" tab of the App Console.
   * Dropbox rejects the authorization request if any requested scope
   * is not pre-enabled.
   */
  static readonly SCOPES: string = [
    'account_info.read',
    'files.metadata.read',
    'files.metadata.write',
    'files.content.read',
    'files.content.write'
  ].join(' ');

  // ---------------------------------------------------------------------------
  // Endpoints
  // ---------------------------------------------------------------------------

  static readonly AUTH_URL: string = Endpoints.DROPBOX_AUTH_URL;
  static readonly TOKEN_URL: string = Endpoints.DROPBOX_TOKEN_URL;

  /**
   * Metadata endpoints (list_folder, get_metadata, create_folder,
   * move, copy, delete, search). Requests send a JSON body and
   * receive a JSON response.
   */
  static readonly API_BASE: string = Endpoints.DROPBOX_API_BASE;

  /**
   * Content endpoints (upload, download). Requests carry the raw file
   * bytes in the body and the operation arguments in a `Dropbox-API-Arg`
   * header.
   */
  static readonly CONTENT_BASE: string = Endpoints.DROPBOX_CONTENT_BASE;

  // ---------------------------------------------------------------------------
  // Transfer constraints
  // ---------------------------------------------------------------------------

  /**
   * Dropbox's single-request upload endpoint (/files/upload) accepts
   * files up to 150 MB. Files above this must use the resumable
   * upload session flow (/files/upload_session/start, /append_v2,
   * /finish).
   */
  static readonly SIMPLE_UPLOAD_MAX_BYTES: number = 150 * 1024 * 1024;

  /**
   * Upload session chunk size. Dropbox requires each append call to
   * carry a multiple of 4 MB, except for the final chunk which may be
   * smaller. 8 MB balances request count against memory per call.
   */
  static readonly UPLOAD_CHUNK_BYTES: number = 8 * 1024 * 1024;

  // ---------------------------------------------------------------------------
  // Timeouts
  // ---------------------------------------------------------------------------

  /** Standard metadata request timeout. */
  static readonly REQUEST_TIMEOUT_MS: number = 30_000;

  /** Extended timeout for upload/download transfers. */
  static readonly TRANSFER_TIMEOUT_MS: number = 180_000;

  // ---------------------------------------------------------------------------
  // Root path
  // ---------------------------------------------------------------------------

  /**
   * Dropbox identifies the root of the user's account with an empty
   * string. Every other path is absolute and begins with "/". This
   * constant gives the CloudProvider abstraction a stable token for
   * "the top of the account", mirroring OneDrive's "root" and Google
   * Drive's "root" special IDs.
   */
  static readonly ROOT_PATH: string = '';

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  /**
   * Call once at app startup so misconfiguration fails fast with a
   * clear log message rather than a cryptic API error later.
   */
  static validate(): boolean {
    const clientId: string = DropboxConfig.CLIENT_ID.trim();

    if (clientId.length === 0
      || clientId === 'YOUR_DROPBOX_APP_KEY') {
      Logger.error(
        'DropboxConfig',
        'CLIENT_ID is not configured. Set it to your Dropbox App key.'
      );
      return false;
    }

    if (!DropboxConfig.REDIRECT_URI.startsWith('https://')) {
      Logger.error(
        'DropboxConfig',
        'REDIRECT_URI must use the https:// scheme. Register the same ' +
          'URI in the Dropbox App Console under OAuth 2.0 → Redirect URIs.'
      );
      return false;
    }

    if (DropboxConfig.SCOPES.indexOf('files.content.read') < 0) {
      Logger.warn(
        'DropboxConfig',
        'SCOPES missing files.content.read — downloads will fail.'
      );
    }

    if (DropboxConfig.SCOPES.indexOf('files.content.write') < 0) {
      Logger.warn(
        'DropboxConfig',
        'SCOPES missing files.content.write — uploads will fail.'
      );
    }

    if (DropboxConfig.CLIENT_SECRET.trim().length > 0) {
      Logger.warn(
        'DropboxConfig',
        'CLIENT_SECRET is set but the PKCE flow does not use it. ' +
          'Remove it to avoid sending an unnecessary credential.'
      );
    }

    return true;
  }
}
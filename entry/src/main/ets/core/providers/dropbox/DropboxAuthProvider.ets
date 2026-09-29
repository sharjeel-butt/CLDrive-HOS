import { IAuthProvider } from '../../interfaces/IAuthProvider';
import { AuthTokens } from '../../models/AuthTokens';
import { CloudProviderType } from '../../models/CloudProviderType';
import { DropboxConfig } from '../../../config/DropboxConfig';
import { HttpClient, HttpRequestOptions } from '../../network/HttpClient';
import { PkceHelper } from '../../auth/PkceHelper';
import { http } from '@kit.NetworkKit';
import { Logger } from '../../../utils/Logger';

interface DropboxTokenResponse {
  access_token: string;
  refresh_token?: string;
  expires_in?: number;
  token_type?: string;
  scope?: string;
  uid?: string;
  account_id?: string;
}

export class DropboxAuthProvider implements IAuthProvider {
  readonly providerType: string = CloudProviderType.DROPBOX;
  private static readonly TAG: string = 'DropboxAuthProvider';

  private pendingCodeVerifier: string = '';

  // ---------------------------------------------------------------------------
  // Authorization
  // ---------------------------------------------------------------------------

  async buildAuthorizationUrl(state: string): Promise<string> {
    const codeVerifier: string = await PkceHelper.generateCodeVerifier();
    const codeChallenge: string =
      await PkceHelper.generateCodeChallenge(codeVerifier);

    this.pendingCodeVerifier = codeVerifier;

    const params = new Map<string, string>();
    params.set('client_id', DropboxConfig.CLIENT_ID);
    params.set('response_type', 'code');
    params.set('redirect_uri', DropboxConfig.REDIRECT_URI);
    params.set('scope', DropboxConfig.SCOPES);
    params.set('state', state);
    // Force the account chooser so the user can switch accounts.
    params.set('force_reapprove', 'false');
    // Dropbox-specific: request a refresh token.
    params.set('token_access_type', 'offline');
    // PKCE.
    params.set('code_challenge', codeChallenge);
    params.set('code_challenge_method', 'S256');

    const query: string = DropboxAuthProvider.encodeForm(params);
    Logger.info(DropboxAuthProvider.TAG, 'Built Dropbox authorization URL.');
    return `${DropboxConfig.AUTH_URL}?${query}`;
  }

  // ---------------------------------------------------------------------------
  // Token exchange
  // ---------------------------------------------------------------------------

  async exchangeCodeForTokens(code: string): Promise<AuthTokens> {
    if (this.pendingCodeVerifier.length === 0) {
      throw new Error(
        'No pending PKCE code_verifier. buildAuthorizationUrl() must be ' +
          'called before exchangeCodeForTokens().'
      );
    }

    const form = new Map<string, string>();
    form.set('code', code);
    form.set('grant_type', 'authorization_code');
    form.set('client_id', DropboxConfig.CLIENT_ID);
    form.set('redirect_uri', DropboxConfig.REDIRECT_URI);
    form.set('code_verifier', this.pendingCodeVerifier);
    // No client_secret — PKCE public client.

    const opts = new HttpRequestOptions();
    opts.method = http.RequestMethod.POST;
    opts.headers.set('Content-Type', 'application/x-www-form-urlencoded');
    opts.body = DropboxAuthProvider.encodeForm(form);

    Logger.info(DropboxAuthProvider.TAG, 'Exchanging code for tokens.');

    let raw: string;
    try {
      raw = await HttpClient.request(DropboxConfig.TOKEN_URL, opts);
    } finally {
      this.pendingCodeVerifier = '';
    }

    const parsed = JSON.parse(raw) as DropboxTokenResponse;

    if (parsed.refresh_token === undefined || parsed.refresh_token.length === 0) {
      Logger.warn(
        DropboxAuthProvider.TAG,
        'No refresh_token in response. Verify token_access_type=offline ' +
          'is set on the authorization URL.'
      );
    }

    return this.mapTokenResponse(parsed);
  }

  // ---------------------------------------------------------------------------
  // Refresh
  // ---------------------------------------------------------------------------

  async refreshTokens(refreshToken: string): Promise<AuthTokens> {
    const form = new Map<string, string>();
    form.set('grant_type', 'refresh_token');
    form.set('refresh_token', refreshToken);
    form.set('client_id', DropboxConfig.CLIENT_ID);
    // Dropbox does not rotate refresh tokens; the same one is reusable.

    const opts = new HttpRequestOptions();
    opts.method = http.RequestMethod.POST;
    opts.headers.set('Content-Type', 'application/x-www-form-urlencoded');
    opts.body = DropboxAuthProvider.encodeForm(form);

    Logger.info(DropboxAuthProvider.TAG, 'Refreshing access token.');
    const raw: string = await HttpClient.request(DropboxConfig.TOKEN_URL, opts);
    const parsed = JSON.parse(raw) as DropboxTokenResponse;

    // Dropbox omits refresh_token on the refresh response — reuse the
    // existing one so it stays in TokenStorage.
    parsed.refresh_token = refreshToken;
    return this.mapTokenResponse(parsed);
  }

  async revokeTokens(refreshToken: string): Promise<void> {
    const form = new Map<string, string>();
    form.set('token', refreshToken);
    form.set('client_id', DropboxConfig.CLIENT_ID);

    const opts = new HttpRequestOptions();
    opts.method = http.RequestMethod.POST;
    opts.headers.set('Content-Type', 'application/x-www-form-urlencoded');
    opts.body = DropboxAuthProvider.encodeForm(form);

    try {
      await HttpClient.request(
        'https://api.dropboxapi.com/2/auth/token/revoke', opts
      );
      Logger.info(DropboxAuthProvider.TAG, 'Tokens revoked.');
    } catch (e) {
      const err: Error = e as Error;
      Logger.warn(
        DropboxAuthProvider.TAG,
        `revokeTokens failed: ${err.message}`
      );
      // Silent failure — clearing local storage is enough on sign-out.
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  private static encodeForm(params: Map<string, string>): string {
    const parts: string[] = [];
    params.forEach((value: string, key: string): void => {
      parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
    });
    return parts.join('&');
  }

  private mapTokenResponse(res: DropboxTokenResponse): AuthTokens {
    return {
      accessToken: res.access_token,
      refreshToken: res.refresh_token !== undefined ? res.refresh_token : '',
      // Dropbox short-lived tokens expire in ~4 hours (14400s). If the
      // response omits expires_in, default to 4 hours.
      expiresIn: res.expires_in !== undefined ? res.expires_in : 14400,
      tokenType: res.token_type !== undefined ? res.token_type : 'bearer',
      scope: res.scope,
      issuedAt: Date.now()
    };
  }
}
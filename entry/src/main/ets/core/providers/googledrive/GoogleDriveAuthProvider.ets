import { IAuthProvider } from '../../interfaces/IAuthProvider';
import { AuthTokens } from '../../models/AuthTokens';
import { CloudProviderType } from '../../models/CloudProviderType';
import { GoogleDriveConfig } from '../../../config/GoogleDriveConfig';
import { HttpClient, HttpRequestOptions } from '../../network/HttpClient';
import { PkceHelper } from '../../auth/PkceHelper';
import { http } from '@kit.NetworkKit';
import { Logger } from '../../../utils/Logger';

interface GoogleTokenResponse {
  access_token: string;
  refresh_token?: string;
  expires_in: number;
  token_type: string;
  scope?: string;
}

export class GoogleDriveAuthProvider implements IAuthProvider {
  readonly providerType: string = CloudProviderType.GOOGLE_DRIVE;
  private static readonly TAG: string = 'GoogleDriveAuthProvider';

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
    params.set('client_id', GoogleDriveConfig.CLIENT_ID);
    params.set('response_type', 'code');
    params.set('redirect_uri', GoogleDriveConfig.REDIRECT_URI);
    params.set('scope', GoogleDriveConfig.SCOPES);
    params.set('state', state);
    // Google-specific: get a refresh token and force the consent screen.
    params.set('access_type', 'offline');
    params.set('prompt', 'consent');
    params.set('include_granted_scopes', 'true');
    // PKCE.
    params.set('code_challenge', codeChallenge);
    params.set('code_challenge_method', 'S256');

    const query: string = GoogleDriveAuthProvider.encodeForm(params);
    Logger.info(GoogleDriveAuthProvider.TAG, 'Built Google authorization URL.');
    return `${GoogleDriveConfig.AUTH_URL}?${query}`;
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
    form.set('client_id', GoogleDriveConfig.CLIENT_ID);
    form.set('client_secret', GoogleDriveConfig.CLIENT_SECRET);
    form.set('code', code);
    form.set('redirect_uri', GoogleDriveConfig.REDIRECT_URI);
    form.set('grant_type', 'authorization_code');
    form.set('code_verifier', this.pendingCodeVerifier);

    const opts = new HttpRequestOptions();
    opts.method = http.RequestMethod.POST;
    opts.headers.set('Content-Type', 'application/x-www-form-urlencoded');
    opts.body = GoogleDriveAuthProvider.encodeForm(form);

    Logger.info(GoogleDriveAuthProvider.TAG, 'Exchanging code for tokens.');

    let raw: string;
    try {
      raw = await HttpClient.request(GoogleDriveConfig.TOKEN_URL, opts);
    } finally {
      this.pendingCodeVerifier = '';
    }

    const parsed = JSON.parse(raw) as GoogleTokenResponse;
    if (parsed.refresh_token === undefined || parsed.refresh_token.length === 0) {
      Logger.warn(
        GoogleDriveAuthProvider.TAG,
        'No refresh_token in response. User may need to re-consent.'
      );
    }
    return this.mapTokenResponse(parsed);
  }

  // ---------------------------------------------------------------------------
  // Refresh
  // ---------------------------------------------------------------------------

  async refreshTokens(refreshToken: string): Promise<AuthTokens> {
    const form = new Map<string, string>();
    form.set('client_id', GoogleDriveConfig.CLIENT_ID);
    form.set('client_secret', GoogleDriveConfig.CLIENT_SECRET);
    form.set('refresh_token', refreshToken);
    form.set('grant_type', 'refresh_token');

    const opts = new HttpRequestOptions();
    opts.method = http.RequestMethod.POST;
    opts.headers.set('Content-Type', 'application/x-www-form-urlencoded');
    opts.body = GoogleDriveAuthProvider.encodeForm(form);

    Logger.info(GoogleDriveAuthProvider.TAG, 'Refreshing access token.');
    const raw: string = await HttpClient.request(GoogleDriveConfig.TOKEN_URL, opts);
    const parsed = JSON.parse(raw) as GoogleTokenResponse;

    // Google never returns a new refresh_token on refresh.
    parsed.refresh_token = refreshToken;
    return this.mapTokenResponse(parsed);
  }

  async revokeTokens(_refreshToken: string): Promise<void> {
    // Google exposes https://oauth2.googleapis.com/revoke for revocation.
    // We skip it here; clearing local storage is sufficient for sign-out.
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

  private mapTokenResponse(res: GoogleTokenResponse): AuthTokens {
    return {
      accessToken: res.access_token,
      refreshToken: res.refresh_token !== undefined ? res.refresh_token : '',
      expiresIn: res.expires_in,
      tokenType: res.token_type,
      scope: res.scope,
      issuedAt: Date.now()
    };
  }
}
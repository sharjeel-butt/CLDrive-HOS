import { IAuthProvider } from '../../interfaces/IAuthProvider';
import { AuthTokens } from '../../models/AuthTokens';
import { CloudProviderType } from '../../models/CloudProviderType';
import { OneDriveConfig } from '../../../config/OneDriveConfig';
import { HttpClient, HttpRequestOptions } from '../../network/HttpClient';
import { PkceHelper } from '../../auth/PkceHelper';
import { http } from '@kit.NetworkKit';
import { Logger } from '../../../utils/Logger';

interface TokenResponse {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  token_type: string;
  scope?: string;
}

export class OneDriveAuthProvider implements IAuthProvider {
  private static readonly TAG: string = 'OneDriveAuthProvider';
  readonly providerType: string = CloudProviderType.ONEDRIVE;
  /**
   * PKCE verifier kept in memory between buildAuthorizationUrl() and
   * exchangeCodeForTokens(). Cleared after a successful exchange so it
   * can never be reused. Single-use is a core PKCE guarantee.
   */
  private pendingCodeVerifier: string = '';

  // ---------------------------------------------------------------------------
  // Authorization
  // ---------------------------------------------------------------------------

  private static encodeForm(params: Map<string, string>): string {
    const parts: string[] = [];
    params.forEach((value: string, key: string): void => {
      parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
    });
    return parts.join('&');
  }

  // ---------------------------------------------------------------------------
  // Token exchange
  // ---------------------------------------------------------------------------

  async buildAuthorizationUrl(state: string): Promise<string> {
    const codeVerifier: string = await PkceHelper.generateCodeVerifier();
    const codeChallenge: string =
      await PkceHelper.generateCodeChallenge(codeVerifier);

    // Cache the verifier for the token exchange step.
    this.pendingCodeVerifier = codeVerifier;

    const params = new Map<string, string>();
    params.set('client_id', OneDriveConfig.CLIENT_ID);
    params.set('response_type', 'code');
    params.set('redirect_uri', OneDriveConfig.REDIRECT_URI);
    params.set('scope', OneDriveConfig.SCOPES);
    params.set('state', state);
    params.set('response_mode', 'query');
    params.set('prompt', 'select_account');
    // PKCE parameters.
    params.set('code_challenge', codeChallenge);
    params.set('code_challenge_method', 'S256');

    const query: string = OneDriveAuthProvider.encodeForm(params);
    Logger.info(OneDriveAuthProvider.TAG, 'Built PKCE authorization URL.');
    return `${OneDriveConfig.AUTH_URL}?${query}`;
  }

  // ---------------------------------------------------------------------------
  // Refresh
  // ---------------------------------------------------------------------------

  async exchangeCodeForTokens(code: string): Promise<AuthTokens> {
    if (this.pendingCodeVerifier.length === 0) {
      throw new Error(
        'No pending PKCE code_verifier. buildAuthorizationUrl() must be ' +
          'called before exchangeCodeForTokens().'
      );
    }

    const form = new Map<string, string>();
    form.set('client_id', OneDriveConfig.CLIENT_ID);
    form.set('code', code);
    form.set('redirect_uri', OneDriveConfig.REDIRECT_URI);
    form.set('grant_type', 'authorization_code');
    form.set('scope', OneDriveConfig.SCOPES);
    // PKCE: prove we are the client that initiated the flow.
    form.set('code_verifier', this.pendingCodeVerifier);
    // NO client_secret — this is a public client.

    const opts = new HttpRequestOptions();
    opts.method = http.RequestMethod.POST;
    opts.headers.set('Content-Type', 'application/x-www-form-urlencoded');
    opts.body = OneDriveAuthProvider.encodeForm(form);

    Logger.info(OneDriveAuthProvider.TAG, 'Exchanging code with PKCE verifier.');

    let raw: string;
    try {
      raw = await HttpClient.request(OneDriveConfig.TOKEN_URL, opts);
    } finally {
      // One-shot: never allow replay, even on failure.
      this.pendingCodeVerifier = '';
    }

    const parsed: TokenResponse = JSON.parse(raw) as TokenResponse;
    return this.mapTokenResponse(parsed);
  }

  async refreshTokens(refreshToken: string): Promise<AuthTokens> {
    const form = new Map<string, string>();
    form.set('client_id', OneDriveConfig.CLIENT_ID);
    form.set('refresh_token', refreshToken);
    form.set('grant_type', 'refresh_token');
    form.set('scope', OneDriveConfig.SCOPES);
    // No client_secret. No code_verifier for refresh grant.

    const opts = new HttpRequestOptions();
    opts.method = http.RequestMethod.POST;
    opts.headers.set('Content-Type', 'application/x-www-form-urlencoded');
    opts.body = OneDriveAuthProvider.encodeForm(form);

    Logger.info(OneDriveAuthProvider.TAG, 'Refreshing access token.');
    const raw: string = await HttpClient.request(OneDriveConfig.TOKEN_URL, opts);
    const parsed: TokenResponse = JSON.parse(raw) as TokenResponse;

    // Microsoft may omit refresh_token when refreshing; keep the old one.
    if (!parsed.refresh_token || parsed.refresh_token.length === 0) {
      parsed.refresh_token = refreshToken;
    }
    return this.mapTokenResponse(parsed);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  async revokeTokens(_refreshToken: string): Promise<void> {
    // Microsoft does not expose a public revoke endpoint for consumer MSA.
  }

  private mapTokenResponse(res: TokenResponse): AuthTokens {
    return {
      accessToken: res.access_token,
      refreshToken: res.refresh_token,
      expiresIn: res.expires_in,
      tokenType: res.token_type,
      scope: res.scope,
      issuedAt: Date.now()
    };
  }
}
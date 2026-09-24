import { AuthTokens } from '../models/AuthTokens';

export interface IAuthProvider {
  readonly providerType: string;

  /**
   * Build the URL the WebView will navigate to.
   *
   * Async because PKCE verifier + challenge generation requires the
   * crypto API. The generated code_verifier is cached inside the
   * implementation and consumed by exchangeCodeForTokens().
   */
  buildAuthorizationUrl(state: string): Promise<string>;

  /** Exchange the authorization code for tokens. */
  exchangeCodeForTokens(code: string): Promise<AuthTokens>;

  /** Use a refresh token to obtain a new access token. */
  refreshTokens(refreshToken: string): Promise<AuthTokens>;

  /** Optional: revoke tokens on sign-out. */
  revokeTokens(refreshToken: string): Promise<void>;
}
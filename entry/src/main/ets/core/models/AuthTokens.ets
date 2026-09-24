export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number; // seconds from issuance
  tokenType: string; // typically "Bearer"
  scope?: string;
  issuedAt: number; // epoch ms, so we can compute expiry
}
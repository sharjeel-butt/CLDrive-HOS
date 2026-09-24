import { IAuthProvider } from '../interfaces/IAuthProvider';
import { AuthTokens } from '../models/AuthTokens';
import { TokenStorage } from './TokenStorage';
import { HttpError } from '../network/HttpError';
import { Logger } from '../../utils/Logger';

export class TokenRefresher {
  private static readonly TAG = 'TokenRefresher';

  /**
   * Run `operation` with the current access token. If it throws a 401,
   * refresh and retry once.
   */
  static async withAutoRefresh<T>(
    accountId: string,
    authProvider: IAuthProvider,
    operation: (accessToken: string) => Promise<T>
  ): Promise<T> {
    const accessToken: string | null = await TokenStorage.getAccess(accountId);

    if (accessToken === null || accessToken.length === 0) {
      throw new Error(`No access token for account ${accountId}. Sign in first.`);
    }

    try {
      return await operation(accessToken);
    } catch (e) {
      const err: Error = e as Error;

      if (!(err instanceof HttpError) || !err.isUnauthorized) {
        throw err;
      }

      Logger.warn(TokenRefresher.TAG, `401 for ${accountId}, refreshing...`);
      const refreshToken: string | null = await TokenStorage.getRefresh(accountId);
      if (refreshToken === null || refreshToken.length === 0) {
        throw new Error(`No refresh token for ${accountId}. Re-authentication required.`);
      }

      const newTokens: AuthTokens = await authProvider.refreshTokens(refreshToken);
      await TokenStorage.save(accountId, newTokens);

      return await operation(newTokens.accessToken);
    }
  }
}
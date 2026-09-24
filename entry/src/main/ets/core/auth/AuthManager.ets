import { AccountInfo } from '../models/AccountInfo';
import { CloudProviderType } from '../models/CloudProviderType';
import { AccountStore } from './AccountStore';
import { TokenStorage } from './TokenStorage';

/**
 * Central manager for signed-in accounts.
 * Delegates persistence to AccountStore + TokenStorage.
 */
export class AuthManager {
  /** Return the currently active account, or null. */
  static async getActiveAccount(): Promise<AccountInfo | null> {
    return AccountStore.getActiveAccount();
  }

  static async getActiveAccountId(): Promise<string> {
    return AccountStore.getActiveAccountId();
  }

  static async setActiveAccountId(accountId: string): Promise<void> {
    await AccountStore.setActiveAccountId(accountId);
  }

  static async getAccounts(): Promise<AccountInfo[]> {
    return AccountStore.getAccounts();
  }

  static async hasAccounts(): Promise<boolean> {
    return AccountStore.hasAccounts();
  }

  static async saveAccount(account: AccountInfo): Promise<void> {
    await AccountStore.addAccount(account);
    await AccountStore.setActiveAccountId(account.accountId);
  }

  static async signOut(accountId: string): Promise<void> {
    await TokenStorage.clear(accountId);
    await AccountStore.removeAccount(accountId);
  }

  static async getAccessToken(accountId: string): Promise<string | null> {
    return TokenStorage.getAccess(accountId);
  }

  /** Convenience: look up the provider type of the active account. */
  static async getActiveProviderType(): Promise<CloudProviderType | null> {
    const account = await AuthManager.getActiveAccount();
    return account === null ? null : account.provider;
  }
}
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AccountInfo } from '../models/AccountInfo';
import { Logger } from '../../utils/Logger';

/**
 * Persistent store for the list of signed-in accounts.
 * Uses HarmonyOS Preferences (lightweight key-value store).
 */
export class AccountStore {
  private static readonly TAG = 'AccountStore';
  private static readonly STORE_NAME = 'cl_drive_accounts';
  private static readonly KEY_LIST = 'account_list';
  private static readonly KEY_ACTIVE = 'active_account_id';
  private static prefs: preferences.Preferences | null = null;

  static async init(context: common.Context): Promise<void> {
    if (AccountStore.prefs !== null) {
      return;
    }
    AccountStore.prefs = await preferences.getPreferences(context, AccountStore.STORE_NAME);
    Logger.info(AccountStore.TAG, 'AccountStore initialized.');
  }

  static async getAccounts(): Promise<AccountInfo[]> {
    const p = AccountStore.ensure();
    const raw = await p.get(AccountStore.KEY_LIST, '[]');
    const str: string = typeof raw === 'string' ? raw : '[]';
    try {
      return JSON.parse(str) as AccountInfo[];
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(AccountStore.TAG, `parse account list failed: ${err.message}`);
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Accounts
  // ---------------------------------------------------------------------------

  static async saveAccounts(accounts: AccountInfo[]): Promise<void> {
    const p = AccountStore.ensure();
    await p.put(AccountStore.KEY_LIST, JSON.stringify(accounts));
    await p.flush();
  }

  static async addAccount(account: AccountInfo): Promise<void> {
    const accounts = await AccountStore.getAccounts();
    const filtered = accounts.filter(
      (a: AccountInfo): boolean => a.accountId !== account.accountId
    );
    filtered.push(account);
    await AccountStore.saveAccounts(filtered);
    Logger.info(AccountStore.TAG, `Added account ${account.accountId}`);
  }

  static async removeAccount(accountId: string): Promise<void> {
    const accounts = await AccountStore.getAccounts();
    const filtered = accounts.filter(
      (a: AccountInfo): boolean => a.accountId !== accountId
    );
    await AccountStore.saveAccounts(filtered);

    const active = await AccountStore.getActiveAccountId();
    if (active === accountId) {
      const next: string = filtered.length > 0 ? filtered[0].accountId : '';
      await AccountStore.setActiveAccountId(next);
    }
    Logger.info(AccountStore.TAG, `Removed account ${accountId}`);
  }

  static async findAccount(accountId: string): Promise<AccountInfo | null> {
    const accounts = await AccountStore.getAccounts();
    for (let i = 0; i < accounts.length; i++) {
      if (accounts[i].accountId === accountId) {
        return accounts[i];
      }
    }
    return null;
  }

  static async getActiveAccountId(): Promise<string> {
    const p = AccountStore.ensure();
    const id = await p.get(AccountStore.KEY_ACTIVE, '');
    return typeof id === 'string' ? id : '';
  }

  // ---------------------------------------------------------------------------
  // Active account
  // ---------------------------------------------------------------------------

  static async setActiveAccountId(accountId: string): Promise<void> {
    const p = AccountStore.ensure();
    await p.put(AccountStore.KEY_ACTIVE, accountId);
    await p.flush();
  }

  static async getActiveAccount(): Promise<AccountInfo | null> {
    const activeId = await AccountStore.getActiveAccountId();
    if (activeId.length === 0) {
      return null;
    }
    return AccountStore.findAccount(activeId);
  }

  static async hasAccounts(): Promise<boolean> {
    const accounts = await AccountStore.getAccounts();
    return accounts.length > 0;
  }

  private static ensure(): preferences.Preferences {
    if (AccountStore.prefs === null) {
      throw new Error('AccountStore.init(context) must be called before use.');
    }
    return AccountStore.prefs;
  }
}
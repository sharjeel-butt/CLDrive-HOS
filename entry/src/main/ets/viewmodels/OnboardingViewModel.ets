import { router } from '@kit.ArkUI';
import { CloudProviderFactory } from '../core/providers/CloudProviderFactory';
import { CloudProviderType } from '../core/models/CloudProviderType';
import { TokenStorage } from '../core/auth/TokenStorage';
import { AuthManager } from '../core/auth/AuthManager';
import { IAuthProvider } from '../core/interfaces/IAuthProvider';
import { AuthTokens } from '../core/models/AuthTokens';
import { AccountInfo, makeAccountId } from '../core/models/AccountInfo';
import { OneDriveApiClient } from '../core/providers/onedrive/OneDriveApiClient';
import { GraphUser } from '../core/providers/onedrive/OneDriveMapper';
import { GoogleDriveApiClient } from '../core/providers/googledrive/GoogleDriveApiClient';
import {
  GoogleAbout, GoogleUser
} from '../core/providers/googledrive/GoogleDriveMapper';
import { DropboxApiClient } from '../core/providers/dropbox/DropboxApiClient';
import {
  DropboxCurrentAccount
} from '../core/providers/dropbox/DropboxMapper';
import { formatError } from '../utils/ErrorFormatter';
import { Logger } from '../utils/Logger';
import { parseQuery } from '../utils/StringUtil';
import { Routes } from '../utils/RouteConstants';


const TAG: string = 'OnboardingViewModel';


export const STEP_SELECT_PROVIDER: number = 0;
export const STEP_AUTHENTICATE: number = 1;

export const MOBILE_USER_AGENT: string =
  'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 ' +
    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

export interface ProviderOption {
  type: CloudProviderType;
  label: string;
  subtitle: string;
  enabled: boolean;
}

export class OnboardingViewModel {
  // ---- Reactive state ----
  step: number = STEP_SELECT_PROVIDER;
  selectedProvider: CloudProviderType = CloudProviderType.ONEDRIVE;
  authUrl: string = '';
  statusMessage: string = '';
  isLoading: boolean = false;
  isAddMode: boolean = false;
  readonly providers: ProviderOption[] = [
    {
      type: CloudProviderType.ONEDRIVE,
      label: 'OneDrive',
      subtitle: 'Microsoft account',
      enabled: true
    },
    {
      type: CloudProviderType.GOOGLE_DRIVE,
      label: 'Google Drive',
      subtitle: 'Google account',
      enabled: true
    },
    {
      type: CloudProviderType.DROPBOX,
      label: 'Dropbox',
      subtitle: 'Dropbox account',
      enabled: true
    }
  ];

  private oauthState: string = '';
  private redirectConsumed: boolean = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  init(): void {
    const params: object = router.getParams();
    if (params !== null && params !== undefined) {
      const mode = Reflect.get(params, 'mode') as string;
      if (mode !== undefined && mode === 'add') {
        this.isAddMode = true;
        Logger.info(TAG, 'Add-account mode enabled.');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  async onSelectProvider(type: CloudProviderType): Promise<void> {
    this.selectedProvider = type;
    this.oauthState = `state_${Date.now()}`;
    this.redirectConsumed = false;
    this.statusMessage = '';
    this.isLoading = false;

    try {
      const auth: IAuthProvider = CloudProviderFactory.getAuthProvider(type);
      this.authUrl = await auth.buildAuthorizationUrl(this.oauthState);
      Logger.info(TAG, `Auth URL for ${type} prepared.`);
      this.step = STEP_AUTHENTICATE;
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `buildAuthorizationUrl failed: ${err.message}`);
      this.statusMessage = 'Failed to prepare sign-in. Please try again.';
    }
  }

  onBack(): void {
    this.authUrl = '';
    this.statusMessage = '';
    this.oauthState = '';
    this.isLoading = false;
    this.redirectConsumed = false;
    this.step = STEP_SELECT_PROVIDER;
  }

  onCancel(): void {
    router.back();
  }

  async handleRedirect(url: string): Promise<void> {
    if (this.redirectConsumed) {
      Logger.info(TAG, 'Duplicate redirect ignored.');
      return;
    }
    this.redirectConsumed = true;
    const params = parseQuery(url);

    const returnedState = params.get('state');
    if (returnedState !== this.oauthState) {
      this.statusMessage = 'Security check failed. Please try again.';
      return;
    }

    const errorCode = params.get('error');
    if (errorCode !== undefined) {
      this.statusMessage = `Sign-in cancelled (${errorCode}).`;
      return;
    }

    const code = params.get('code');
    if (code === undefined || code.length === 0) {
      this.statusMessage = 'No authorization code returned.';
      return;
    }

    this.isLoading = true;
    try {
      const auth: IAuthProvider =
        CloudProviderFactory.getAuthProvider(this.selectedProvider);
      const tokens: AuthTokens = await auth.exchangeCodeForTokens(code);
      const account = await this.buildAccountInfo(this.selectedProvider, tokens);

      await TokenStorage.save(account.accountId, tokens);
      await AuthManager.saveAccount(account);
      CloudProviderFactory.evict(account.accountId);

      Logger.info(TAG, `Signed in as ${account.accountId}`);

      if (this.isAddMode) {
        router.back();
      } else {
        router.replaceUrl({ url: Routes.FILE_BROWSER }).catch((e: Error) => {
          Logger.error(TAG, `replaceUrl failed: ${e.message}`);
        });
      }
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `Token exchange failed: ${err.message}`);
      this.statusMessage = `Sign-in failed: ${err.message}`;
    } finally {
      this.isLoading = false;
    }
  }

  providerLabel(type: CloudProviderType): string {
    if (type === CloudProviderType.ONEDRIVE) {
      return 'OneDrive';
    }
    if (type === CloudProviderType.GOOGLE_DRIVE) {
      return 'Google Drive';
    }
    return 'provider';
  }

  /**
   * Fetch the user profile from the specified provider using the newly
   * issued access token, and construct an AccountInfo record.
   *
   * Called once per successful OAuth flow, before the tokens are saved
   * to TokenStorage. The resulting accountId becomes the storage key
   * for that account's tokens and preferences.
   *
   * Each provider returns a different user-info shape; the mapping
   * below normalises them all to AccountInfo.
   */
  private async buildAccountInfo(
    type: CloudProviderType,
    tokens: AuthTokens
  ): Promise<AccountInfo> {

    // =========================================================================
    // OneDrive — Microsoft Graph /me
    // =========================================================================
    if (type === CloudProviderType.ONEDRIVE) {
      const api = new OneDriveApiClient();
      const me: GraphUser = await api.getMe(tokens.accessToken);

      const displayName: string =
        me.displayName !== undefined
          && me.displayName !== null
          && me.displayName.length > 0
          ? me.displayName
          : 'OneDrive User';

      let email: string | undefined = undefined;
      if (me.mail !== undefined && me.mail !== null && me.mail.length > 0) {
        email = me.mail;
      } else if (me.userPrincipalName !== undefined
        && me.userPrincipalName !== null
        && me.userPrincipalName.length > 0) {
        email = me.userPrincipalName;
      }

      // Prefer the email as the unique part of the account ID so the
      // account remains stable across reinstalls. Fall back to the
      // Graph user ID if no email is available.
      const uniquePart: string =
        email !== undefined && email.length > 0
          ? email
          : me.id;

      const accountId: string = makeAccountId(
        CloudProviderType.ONEDRIVE, uniquePart
      );

      Logger.info(
        TAG,
        `Built OneDrive account: ${accountId} (${displayName})`
      );

      const account: AccountInfo = {
        accountId: accountId,
        provider: CloudProviderType.ONEDRIVE,
        displayName: displayName,
        email: email,
        avatarUrl: undefined,
        addedAt: Date.now()
      };
      return account;
    }

    // =========================================================================
    // Google Drive — Drive v3 /about
    // =========================================================================
    if (type === CloudProviderType.GOOGLE_DRIVE) {
      const api = new GoogleDriveApiClient();
      const about: GoogleAbout = await api.getAbout(tokens.accessToken);

      const user: GoogleUser = about.user !== undefined
        && about.user !== null
        ? about.user
        : {};

      const displayName: string =
        user.displayName !== undefined
          && user.displayName !== null
          && user.displayName.length > 0
          ? user.displayName
          : 'Google User';

      const email: string | undefined =
        user.emailAddress !== undefined
          && user.emailAddress !== null
          && user.emailAddress.length > 0
          ? user.emailAddress
          : undefined;

      const uniquePart: string =
        email !== undefined && email.length > 0
          ? email
          : 'google_user';

      const accountId: string = makeAccountId(
        CloudProviderType.GOOGLE_DRIVE, uniquePart
      );

      Logger.info(
        TAG,
        `Built Google Drive account: ${accountId} (${displayName})`
      );

      const account: AccountInfo = {
        accountId: accountId,
        provider: CloudProviderType.GOOGLE_DRIVE,
        displayName: displayName,
        email: email,
        avatarUrl: user.photoLink,
        addedAt: Date.now()
      };
      return account;
    }

    // =========================================================================
    // Dropbox — Dropbox v2 /users/get_current_account
    // =========================================================================
    if (type === CloudProviderType.DROPBOX) {
      const api = new DropboxApiClient();
      const account: DropboxCurrentAccount =
        await api.getCurrentAccount(tokens.accessToken);

      // Dropbox nests the display name inside a `name` object.
      let displayName: string = 'Dropbox User';
      if (account.name !== undefined
        && account.name !== null
        && account.name.display_name !== undefined
        && account.name.display_name !== null
        && account.name.display_name.length > 0) {
        displayName = account.name.display_name;
      }

      const email: string | undefined =
        account.email !== undefined
          && account.email !== null
          && account.email.length > 0
          ? account.email
          : undefined;

      // Dropbox returns a stable `account_id` like "dbid:AABxyz…". Use
      // that for the account ID so it survives email changes.
      const uniquePart: string =
        account.account_id !== undefined
          && account.account_id !== null
          && account.account_id.length > 0
          ? account.account_id
          : (email !== undefined ? email : 'dropbox_user');

      const accountId: string = makeAccountId(
        CloudProviderType.DROPBOX, uniquePart
      );

      Logger.info(
        TAG,
        `Built Dropbox account: ${accountId} (${displayName})`
      );

      const info: AccountInfo = {
        accountId: accountId,
        provider: CloudProviderType.DROPBOX,
        displayName: displayName,
        email: email,
        avatarUrl: account.profile_photo_url,
        addedAt: Date.now()
      };
      return info;
    }

    // =========================================================================
    // Unknown provider
    // =========================================================================
    throw new Error(`Unsupported provider for account creation: ${type}`);
  }
}
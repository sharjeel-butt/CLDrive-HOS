import { router } from '@kit.ArkUI';
import { CloudProviderFactory } from '../core/providers/CloudProviderFactory';
import { CloudProviderType } from '../core/models/CloudProviderType';
import { TokenStorage } from '../core/auth/TokenStorage';
import { AuthManager } from '../core/auth/AuthManager';
import { IAuthProvider } from '../core/interfaces/IAuthProvider';
import { AuthTokens } from '../core/models/AuthTokens';
import { AccountInfo, makeAccountId } from '../core/models/AccountInfo';
import { Logger } from '../utils/Logger';
import { parseQuery } from '../utils/StringUtil';
import { Routes } from '../utils/RouteConstants';
import { DropboxApiClient } from '../core/providers/dropbox/DropboxApiClient';
import { DropboxCurrentAccount } from '../core/providers/dropbox/DropboxMapper';

const TAG: string = 'OnboardingViewModel';

export const STEP_SELECT_PROVIDER: number = 0;

export const STEP_AUTHENTICATE: number = 1;

export const MOBILE_USER_AGENT: string =
  'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

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
    this.step = STEP_SELECT_PROVIDER;
  }

  onCancel(): void {
    router.back();
  }

  async handleRedirect(url: string): Promise<void> {
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

  private async buildAccountInfo(
    type: CloudProviderType,
    tokens: AuthTokens
  ): Promise<AccountInfo> {
    if (type === CloudProviderType.ONEDRIVE) {
      // ... existing OneDrive code
    }

    if (type === CloudProviderType.GOOGLE_DRIVE) {
      // ... existing Google Drive code
    }

    if (type === CloudProviderType.DROPBOX) {
      const api = new DropboxApiClient();
      const account: DropboxCurrentAccount =
        await api.getCurrentAccount(tokens.accessToken);

      const displayName: string =
        account.name !== undefined
          && account.name.display_name !== undefined
          && account.name.display_name.length > 0
          ? account.name.display_name
          : 'Dropbox User';

      const accountId: string = makeAccountId(
        CloudProviderType.DROPBOX, account.account_id
      );

      return {
        accountId: accountId,
        provider: CloudProviderType.DROPBOX,
        displayName: displayName,
        email: account.email,
        avatarUrl: account.profile_photo_url,
        addedAt: Date.now()
      };
    }

    throw new Error(`Unsupported provider for account creation: ${type}`);
  }
}
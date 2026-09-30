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
import { t } from '../core/i18n/I18n';

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
  /**
   * True for providers that are announced but not yet implemented.
   * The picker renders them faded with a "Coming soon" chip and
   * does not fire onSelectProvider.
   */
  comingSoon: boolean;
}

export class OnboardingViewModel {
  // ---- Reactive state ----
  step: number = STEP_SELECT_PROVIDER;
  selectedProvider: CloudProviderType = CloudProviderType.ONEDRIVE;
  authUrl: string = '';
  statusMessage: string = '';
  isLoading: boolean = false;
  isAddMode: boolean = false;

  // Rebuilt on every read so labels track the current language.
  get providers(): ProviderOption[] {
    return OnboardingViewModel.buildProviders();
  }

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
      this.statusMessage = t('onb.prepareFailed');
    }
  }

  onBack(): void {
    this.authUrl = '';
    this.statusMessage = '';
    this.oauthState = '';
    this.redirectConsumed = false;
    this.isLoading = false;
    this.step = STEP_SELECT_PROVIDER;
  }

  onCancel(): void {
    router.back();
  }

  async handleRedirect(url: string): Promise<void> {
    // Guard against a stale redirect URL in the WebView's history
    // firing the same authorization code twice.
    if (this.redirectConsumed) {
      Logger.info(TAG, 'Duplicate redirect ignored.');
      return;
    }
    this.redirectConsumed = true;

    const params = parseQuery(url);

    const returnedState = params.get('state');
    if (returnedState !== this.oauthState) {
      this.statusMessage = t('onb.securityFailed');
      return;
    }

    const errorCode = params.get('error');
    if (errorCode !== undefined) {
      this.statusMessage = `${t('onb.cancelled')} (${errorCode}).`;
      return;
    }

    const code = params.get('code');
    if (code === undefined || code.length === 0) {
      this.statusMessage = t('onb.noCode');
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
      const readable: string = formatError(err);
      this.statusMessage = `${t('onb.signInFailed')}: ${readable}`;
    } finally {
      this.isLoading = false;
    }
  }

  providerLabel(type: CloudProviderType): string {
    if (type === CloudProviderType.ONEDRIVE) return t('onb.provider.onedrive');
    if (type === CloudProviderType.GOOGLE_DRIVE) return t('onb.provider.google');
    if (type === CloudProviderType.DROPBOX) return t('onb.provider.dropbox');
    if (type === CloudProviderType.WEBDAV) return t('onb.provider.webdav');
    if (type === CloudProviderType.S3) return t('onb.provider.s3');
    if (type === CloudProviderType.BOX) return t('onb.provider.box');
    return t('onb.provider');
  }
  // ---------------------------------------------------------------------------
  // Provider list — rebuilt on each read so language changes take effect
  // ---------------------------------------------------------------------------

  private static buildProviders(): ProviderOption[] {
    return [
      {
        type: CloudProviderType.ONEDRIVE,
        label: t('onb.provider.onedrive'),
        subtitle: t('onb.subtitle.onedrive'),
        enabled: true,
        comingSoon: false
      },
      {
        type: CloudProviderType.GOOGLE_DRIVE,
        label: t('onb.provider.google'),
        subtitle: t('onb.subtitle.google'),
        enabled: true,
        comingSoon: false
      },
      {
        type: CloudProviderType.DROPBOX,
        label: t('onb.provider.dropbox'),
        subtitle: t('onb.subtitle.dropbox'),
        enabled: true,
        comingSoon: false
      },

      // ---- Coming soon ----
      {
        type: CloudProviderType.WEBDAV,
        label: t('onb.provider.webdav'),
        subtitle: t('onb.comingSoon'),
        enabled: false,
        comingSoon: true
      },
      {
        type: CloudProviderType.S3,
        label: t('onb.provider.s3'),
        subtitle: t('onb.comingSoon'),
        enabled: false,
        comingSoon: true
      },
      {
        type: CloudProviderType.BOX,
        label: t('onb.provider.box'),
        subtitle: t('onb.comingSoon'),
        enabled: false,
        comingSoon: true
      }
    ];
  }

  // ---------------------------------------------------------------------------
  // Account construction per provider
  // ---------------------------------------------------------------------------

  private async buildAccountInfo(
    type: CloudProviderType,
    tokens: AuthTokens
  ): Promise<AccountInfo> {

    // ---- OneDrive ----
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

    // ---- Google Drive ----
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

      // Never fall back to a fixed string — that would collide every
      // account without an email into a single slot.
      if (email === undefined || email.length === 0) {
        throw new Error('Google Drive returned no email address.');
      }

      const accountId: string = makeAccountId(
        CloudProviderType.GOOGLE_DRIVE, email
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

    // ---- Dropbox ----
    if (type === CloudProviderType.DROPBOX) {
      const api = new DropboxApiClient();
      const account: DropboxCurrentAccount =
        await api.getCurrentAccount(tokens.accessToken);

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

    throw new Error(`Unsupported provider for account creation: ${type}`);
  }
}
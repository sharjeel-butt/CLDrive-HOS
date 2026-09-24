import { webview } from '@kit.ArkWeb';
import { CloudProviderFactory } from '../core/providers/CloudProviderFactory';
import { CloudProviderType } from '../core/models/CloudProviderType';
import { TokenStorage } from '../core/auth/TokenStorage';
import { AuthManager } from '../core/auth/AuthManager';
import { IAuthProvider } from '../core/interfaces/IAuthProvider';
import { AuthTokens } from '../core/models/AuthTokens';
import { Logger } from '../utils/Logger';
import { parseQuery } from '../utils/StringUtil';

@Entry
@Component
struct SignInPage {
  @State authUrl: string = '';
  @State showWeb: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private auth: IAuthProvider = CloudProviderFactory.getAuthProvider(CloudProviderType.ONEDRIVE);
  private state: string = `state_${Date.now()}`;

  build() {
    Column({ space: 20 }) {
      Text('CLDrive')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
      Text('Sign in to OneDrive')
        .fontSize(16)
        .fontColor('#666')

      Button('Sign in with Microsoft')
        .onClick(() => {
          this.authUrl = this.auth.buildAuthorizationUrl(this.state);
          this.showWeb = true;
        })

      if (this.showWeb) {
        Web({ src: this.authUrl, controller: this.controller })
          .onLoadIntercept((event) => {
            const url: string = event.data.getRequestUrl();
            if (url.startsWith('https://cl.drive/oauth')) {
              this.handleRedirect(url);
              return true; // Block navigation to the redirect URI
            }
            return false; // Allow all other navigations
          })
          .width('100%')
          .height(400)
      }
    }
    .padding(24)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  private async handleRedirect(url: string): Promise<void> {
    const params = parseQuery(url);

    const returnedState: string | undefined = params.get('state');
    if (returnedState !== this.state) {
      Logger.error('SignInPage', 'State mismatch — possible CSRF.');
      return;
    }

    const code: string | undefined = params.get('code');
    if (code === undefined || code.length === 0) {
      Logger.error('SignInPage', 'No authorization code in redirect.');
      return;
    }

    try {
      const tokens: AuthTokens = await this.auth.exchangeCodeForTokens(code);
      await TokenStorage.save(CloudProviderType.ONEDRIVE, tokens);
      AuthManager.setActive(CloudProviderType.ONEDRIVE);
      this.showWeb = false;
      Logger.info('SignInPage', 'Signed in successfully.');
      // Navigate to FileBrowserPage here.
    } catch (e) {
      const err: Error = e as Error;
      Logger.error('SignInPage', `Token exchange failed: ${err.message}`);
    }
  }
}
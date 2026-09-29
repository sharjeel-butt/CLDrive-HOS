import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { ThemeManager } from '../core/theme/ThemeManager';
import { ThemeColors } from '../core/theme/ThemeColors';
import { Logger } from '../utils/Logger';

const TAG: string = 'PrivacyPolicyViewerPage';

const PRIVACY_POLICY_URL: string =
  'https://sharjeel-butt.github.io/CLDrive-HOS/';

@Entry
@Component
struct PrivacyPolicyViewerPage {
  @State private theme: ThemeColors = ThemeManager.get().colors();
  @State private isLoading: boolean = true;
  @State private errorMessage: string = '';

  private controller: webview.WebviewController =
    new webview.WebviewController();

  private onThemeChanged = (): void => {
    this.theme = ThemeManager.get().colors();
  };

  aboutToAppear(): void {
    ThemeManager.get().subscribe(this.onThemeChanged);
  }

  aboutToDisappear(): void {
    ThemeManager.get().unsubscribe(this.onThemeChanged);
  }

  private webDarkMode(): WebDarkMode {
    return this.theme.isDark ? WebDarkMode.On : WebDarkMode.Off;
  }

  build() {
    Column() {
      // ---- Header ----
      Row({ space: 12 }) {
        Text('←')
          .fontSize(24)
          .fontColor(this.theme.textPrimary)
          .width(40)
          .textAlign(TextAlign.Center)
          .onClick(() => { router.back(); })

        Column({ space: 2 }) {
          Text('Privacy Policy')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.textPrimary)
            .textAlign(TextAlign.Start)
            .width('100%')
          if (this.errorMessage.length > 0) {
            Text('Could not load')
              .fontSize(11)
              .fontColor(this.theme.error)
              .textAlign(TextAlign.Start)
              .width('100%')
          } else {
            Text('sharjeel-butt.github.io/CLDrive-HOS')
              .fontSize(11)
              .fontColor(this.theme.textSecondary)
              .textAlign(TextAlign.Start)
              .width('100%')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 16, top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.theme.surface)

      Divider().color(this.theme.divider)

      // ---- WebView / loading / error ----
      Stack() {
        Web({ src: PRIVACY_POLICY_URL, controller: this.controller })
          .darkMode(this.webDarkMode())
          .forceDarkAccess(false)
          .domStorageAccess(false)
          .javaScriptAccess(false)
          .fileAccess(false)
          .onlineImageAccess(true)
          .mixedMode(MixedMode.None)
          .width('100%')
          .height('100%')
          .backgroundColor(this.theme.background)
          .onPageBegin(() => {
            this.isLoading = true;
            this.errorMessage = '';
          })
          .onPageEnd(() => {
            this.isLoading = false;
          })
          .onErrorReceive((event) => {
            if (event === undefined) return;
            const err = event.error;
            Logger.error(
              TAG,
              `Web load error ${err.getErrorCode}: ${err.getErrorInfo}`
            );
            this.isLoading = false;
            this.errorMessage =
              `Could not load the privacy policy (${err.getErrorCode}).`;
          })

        if (this.isLoading) {
          Column({ space: 12 }) {
            LoadingProgress().width(36).height(36).color(this.theme.primary)
            Text('Loading policy...')
              .fontSize(13).fontColor(this.theme.textSecondary)
          }
          .width('100%').height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.theme.background)
        }

        if (this.errorMessage.length > 0) {
          Column({ space: 14 }) {
            Text('🌐').fontSize(42)
            Text('Could not load the policy')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary)
            Text(this.errorMessage)
              .fontSize(13)
              .fontColor(this.theme.textSecondary)
              .textAlign(TextAlign.Center)
              .padding({ left: 32, right: 32 })
            Button('Retry')
              .onClick(() => {
                this.errorMessage = '';
                this.isLoading = true;
                try {
                  this.controller.loadUrl(PRIVACY_POLICY_URL);
                } catch (e) {
                  const err: Error = e as Error;
                  Logger.error(TAG, `loadUrl retry failed: ${err.message}`);
                  this.errorMessage = 'Retry failed. Check your connection.';
                  this.isLoading = false;
                }
              })
          }
          .width('100%').height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.theme.background)
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.background)
  }
}
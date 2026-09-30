import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { ThemeManager } from '../core/theme/ThemeManager';
import { ThemeColors } from '../core/theme/ThemeColors';
import { LanguageManager } from '../core/i18n/LanguageManager';
import { t } from '../core/i18n/I18n';
import { Logger } from '../utils/Logger';

const TAG: string = 'PrivacyPolicyViewerPage';

const POLICY_BASE: string =
  'https://sharjeel-butt.github.io/CLDrive-HOS';

/**
 * Return the online privacy policy URL for a language.
 *
 * Languages with a translated policy page have their own path.
 * Any language without one falls back to English so the WebView
 * never lands on a 404.
 *
 * URL layout mirrors the GitHub Pages site built from `docs/`:
 *   /                    → English landing (README)
 *   /privacy/en/         → English policy
 *   /privacy/ru/         → Russian policy
 *   /privacy/zh-Hans/    → Simplified Chinese policy
 *   /privacy/ar/         → Arabic policy
 *   /privacy/es/         → Spanish policy
 */
function policyUrlFor(lang: string): string {
  if (lang === 'ru')      return `${POLICY_BASE}/privacy/ru/`;
  if (lang === 'zh-Hans') return `${POLICY_BASE}/privacy/zh-Hans/`;
  if (lang === 'ar')      return `${POLICY_BASE}/privacy/ar/`;
  if (lang === 'es')      return `${POLICY_BASE}/privacy/es/`;
  if (lang === 'en')      return `${POLICY_BASE}/privacy/en/`;
  // Every other language falls back to English.
  return `${POLICY_BASE}/privacy/en/`;
}

@Entry
@Component
struct PrivacyPolicyViewerPage {
  @State private theme: ThemeColors = ThemeManager.get().colors();
  @State private isLoading: boolean = true;
  @State private errorMessage: string = '';
  @State private url: string = POLICY_BASE;

  @StorageLink('languageVersion') langVersion: number = 0;

  private controller: webview.WebviewController =
    new webview.WebviewController();

  private onThemeChanged = (): void => {
    this.theme = ThemeManager.get().colors();
  };

  aboutToAppear(): void {
    this.theme = ThemeManager.get().colors();
    ThemeManager.get().subscribe(this.onThemeChanged);
    this.url = policyUrlFor(LanguageManager.get());
  }

  aboutToDisappear(): void {
    ThemeManager.get().unsubscribe(this.onThemeChanged);
  }

  private webDarkMode(): WebDarkMode {
    return this.theme.isDark ? WebDarkMode.On : WebDarkMode.Off;
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Text('←')
          .fontSize(24)
          .fontColor(this.theme.textPrimary)
          .width(40)
          .textAlign(TextAlign.Center)
          .onClick(() => { router.back(); })

        Column({ space: 2 }) {
          Text(t('viewer.title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.textPrimary)
            .textAlign(TextAlign.Start)
            .width('100%')
          if (this.errorMessage.length > 0) {
            Text(t('viewer.error'))
              .fontSize(11)
              .fontColor(this.theme.error)
              .textAlign(TextAlign.Start)
              .width('100%')
          } else {
            Text(this.url.replace('https://', ''))
              .fontSize(11)
              .fontColor(this.theme.textSecondary)
              .textAlign(TextAlign.Start)
              .width('100%')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
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

      Stack() {
        Web({ src: this.url, controller: this.controller })
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
          .onPageEnd(() => { this.isLoading = false; })
          .onErrorReceive((event) => {
            if (event === undefined) return;
            const err = event.error;
            Logger.error(
              TAG,
              `Web load error ${err.getErrorCode}: ${err.getErrorInfo}`
            );
            this.isLoading = false;
            this.errorMessage =
              `${t('viewer.error')} (${err.getErrorCode}).`;
          })

        if (this.isLoading) {
          Column({ space: 12 }) {
            LoadingProgress().width(36).height(36).color(this.theme.primary)
            Text(t('viewer.loading'))
              .fontSize(13).fontColor(this.theme.textSecondary)
          }
          .width('100%').height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.theme.background)
        }

        if (this.errorMessage.length > 0) {
          Column({ space: 14 }) {
            Text('🌐').fontSize(42)
            Text(t('viewer.error'))
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary)
            Text(this.errorMessage)
              .fontSize(13)
              .fontColor(this.theme.textSecondary)
              .textAlign(TextAlign.Center)
              .padding({ left: 32, right: 32 })
            Button(t('viewer.retry'))
              .onClick(() => {
                this.errorMessage = '';
                this.isLoading = true;
                try {
                  this.controller.loadUrl(this.url);
                } catch (e) {
                  const err: Error = e as Error;
                  Logger.error(TAG, `loadUrl retry failed: ${err.message}`);
                  this.errorMessage = t('viewer.retryFailed');
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
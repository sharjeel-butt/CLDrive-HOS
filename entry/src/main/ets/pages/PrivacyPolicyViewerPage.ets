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

function policyUrlFor(lang: string): string {
  if (lang === 'en')      return `${POLICY_BASE}/privacy/en/`;
  if (lang === 'ru')      return `${POLICY_BASE}/privacy/ru/`;
  if (lang === 'zh-Hans') return `${POLICY_BASE}/privacy/zh-Hans/`;
  if (lang === 'ar')      return `${POLICY_BASE}/privacy/ar/`;
  if (lang === 'es')      return `${POLICY_BASE}/privacy/es/`;
  return `${POLICY_BASE}/privacy/en/`;
}

const SIZE_HEADER_ICON = 24;

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

  @Builder
  appIcon(media: Resource, size: number, color: string) {
    Image(media)
      .width(size)
      .height(size)
      .fillColor(color)
      .draggable(false)
      .objectFit(ImageFit.Contain)
  }

  private webDarkMode(): WebDarkMode {
    return this.theme.isDark ? WebDarkMode.On : WebDarkMode.Off;
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Row() {
          this.appIcon($r('app.media.ic_back'), SIZE_HEADER_ICON, this.theme.textPrimary)
        }
        .width(40).height(40)
        .justifyContent(FlexAlign.Center)
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
      .backgroundColor(this.theme.background)
      .border({ width: { bottom: 1 }, color: this.theme.divider })

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
            this.appIcon($r('app.media.ic_privacy_block'), 48, this.theme.textTertiary)
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
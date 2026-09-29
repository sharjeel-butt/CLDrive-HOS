import { router } from '@kit.ArkUI';
import { ThemeManager } from '../core/theme/ThemeManager';
import { ThemeColors } from '../core/theme/ThemeColors';
import { LanguageManager } from '../core/i18n/LanguageManager';
import { LanguageOption, LANGUAGES, LangCode } from '../core/i18n/Language';
import { t, detectSystemLanguage } from '../core/i18n/I18n';
import { PrivacyPrefs } from '../core/settings/PrivacyPrefs';
import { AuthManager } from '../core/auth/AuthManager';
import { Routes } from '../utils/RouteConstants';
import { Logger } from '../utils/Logger';

const TAG: string = 'LanguageSelectionPage';

@Entry
@Component
struct LanguageSelectionPage {
  @State private theme: ThemeColors = ThemeManager.get().colors();
  @State private selectedCode: LangCode = 'en';
  @State private isProcessing: boolean = false;
  @State private translationVersion: number = 0;

  private onThemeChanged = (): void => {
    this.theme = ThemeManager.get().colors();
  };

  aboutToAppear(): void {
    ThemeManager.get().subscribe(this.onThemeChanged);
    // Preselect based on system locale, but do not apply until the
    // user taps Continue.
    this.selectedCode = detectSystemLanguage();
  }

  aboutToDisappear(): void {
    ThemeManager.get().unsubscribe(this.onThemeChanged);
  }

  private async onContinue(): Promise<void> {
    if (this.isProcessing) return;
    this.isProcessing = true;
    try {
      await LanguageManager.set(this.selectedCode);

      // Route to the next gate: privacy policy if not yet accepted,
      // otherwise the existing auth check.
      const accepted: boolean = await PrivacyPrefs.isAccepted();
      let next: string = Routes.PRIVACY_POLICY;
      if (accepted) {
        const hasAccounts: boolean = await AuthManager.hasAccounts();
        next = hasAccounts ? Routes.FILE_BROWSER : Routes.ONBOARDING;
      }

      router.replaceUrl({ url: next }).catch((e: Error) => {
        Logger.error(TAG, `replaceUrl failed: ${e.message}`);
      });
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `onContinue failed: ${err.message}`);
      this.isProcessing = false;
    }
  }

  private async selectLanguage(option: LanguageOption): Promise<void> {
    this.selectedCode = option.code;
    // Preview the language immediately by applying it in-process.
    // Persistence still happens on Continue.
    LanguageManager.set(option.code)
      .then(() => {
        // Re-render so labels update to the newly selected language.
        this.translationVersion = this.translationVersion + 1;
      })
      .catch((e: Error) => {
        Logger.error(TAG, `preview language failed: ${e.message}`);
      });
  }

  build() {
    Column() {
      // ---- Header ----
      Column({ space: 6 }) {
        Text(t('lang.title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Start)
          .width('100%')
        Text(t('lang.subtitle'))
          .fontSize(13)
          .fontColor(this.theme.textSecondary)
          .textAlign(TextAlign.Start)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 24, right: 24, top: 40, bottom: 20 })

      // ---- Language list ----
      List({ space: 8 }) {
        ForEach(LANGUAGES, (lang: LanguageOption) => {
          ListItem() {
            Row({ space: 14 }) {
              Column({ space: 3 }) {
                Text(lang.englishName)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme.textPrimary)
                  .textAlign(TextAlign.Start)
                  .width('100%')
                Text(lang.nativeName)
                  .fontSize(13)
                  .fontColor(this.theme.textSecondary)
                  .textAlign(TextAlign.Start)
                  .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              if (this.selectedCode === lang.code) {
                Text('✓')
                  .fontSize(20)
                  .fontColor(this.theme.primary)
                  .fontWeight(FontWeight.Bold)
              }
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 14, bottom: 14 })
            .backgroundColor(this.selectedCode === lang.code
              ? this.theme.chipSelectedBg : this.theme.surface)
            .borderRadius(12)
            .border({
              width: this.selectedCode === lang.code ? 1.5 : 0,
              color: this.theme.primary
            })
            .alignItems(VerticalAlign.Center)
            .onClick(() => { this.selectLanguage(lang); })
          }
        }, (lang: LanguageOption) => lang.code)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)

      // ---- Continue button ----
      Button(this.isProcessing ? t('priv.saving') : t('lang.continue'))
        .width('100%')
        .height(50)
        .backgroundColor(this.theme.primary)
        .fontColor(this.theme.primaryContrast)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .enabled(!this.isProcessing)
        .margin({ left: 20, right: 20, top: 12, bottom: 28 })
        .onClick(() => { this.onContinue(); })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.background)
  }
}
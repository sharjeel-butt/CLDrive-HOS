import { webview } from '@kit.ArkWeb';
import { router } from '@kit.ArkUI';
import {
  OnboardingViewModel,
  ProviderOption,
  STEP_SELECT_PROVIDER,
  MOBILE_USER_AGENT
} from '../viewmodels/OnboardingViewModel';
import { ProviderIcon } from '../components/ProviderIcon';
import { ThemeManager } from '../core/theme/ThemeManager';
import { ThemeColors } from '../core/theme/ThemeColors';
import { t } from '../core/i18n/I18n';
import { Logger } from '../utils/Logger';

const TAG: string = 'OnboardingPage';

const SIZE_HEADER_ICON = 24;
const SIZE_PROVIDER_CHEVRON = 24;

@Entry
@Component
struct OnboardingPage {
  @State vm: OnboardingViewModel = new OnboardingViewModel();
  @State private theme: ThemeColors = ThemeManager.get().colors();

  @StorageLink('languageVersion') langVersion: number = 0;

  private controller: webview.WebviewController = new webview.WebviewController();

  private onThemeChanged = (): void => {
    this.theme = ThemeManager.get().colors();
  };

  aboutToAppear(): void {
    ThemeManager.get().subscribe(this.onThemeChanged);
    this.vm.init();
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

  onBackPress(): boolean {
    if (this.vm.step === STEP_SELECT_PROVIDER) {
      return false;
    }
    if (this.controller.accessBackward()) {
      this.controller.backward();
      return true;
    }
    this.vm.onBack();
    return true;
  }

  build() {
    Column() {
      this.buildHeader()

      if (this.vm.step === STEP_SELECT_PROVIDER) {
        this.buildProviderSelection()
      } else {
        this.buildAuthView()
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24, top: 24, bottom: 24 })
    .backgroundColor(this.theme.background)
  }

  @Builder
  buildHeader() {
    Column({ space: 8 }) {
      Row() {
        if (this.vm.isAddMode && this.vm.step === STEP_SELECT_PROVIDER) {
          Row({ space: 4 }) {
            this.appIcon($r('app.media.ic_chevron_left'),
              SIZE_HEADER_ICON, this.theme.primary)
            Text(t('common.cancel'))
              .fontSize(15)
              .fontColor(this.theme.primary)
          }
          .padding({ top: 6, bottom: 6, right: 8 })
          .alignItems(VerticalAlign.Center)
          .onClick(() => { this.vm.onCancel(); })

          Blank()
        }
      }
      .width('100%')

      Text(this.vm.isAddMode ? t('onb.addAccount') : t('onb.welcome'))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textPrimary)

      Text(this.vm.step === STEP_SELECT_PROVIDER
        ? t('onb.chooseProvider')
        : `${t('onb.signInTo')} ${this.vm.providerLabel(this.vm.selectedProvider)}`)
        .fontSize(14)
        .fontColor(this.theme.textSecondary)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ top: 24, bottom: 32 })
  }

  @Builder
  buildProviderSelection() {
    Column({ space: 12 }) {
      ForEach(this.vm.providers, (item: ProviderOption) => {
        this.buildProviderCard(item)
      }, (item: ProviderOption) => item.type)
    }
    .width('100%')
  }

  @Builder
  buildProviderCard(item: ProviderOption) {
    Row({ space: 16 }) {
      ProviderIcon({ provider: item.type, iconSize: 48 })

      Column({ space: 4 }) {
        Text(item.label)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(item.enabled
            ? this.theme.textPrimary
            : this.theme.textTertiary)
        Text(item.subtitle)
          .fontSize(13)
          .fontColor(item.enabled
            ? this.theme.textSecondary
            : this.theme.textTertiary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (item.comingSoon) {
        Text(t('onb.comingSoon'))
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textTertiary)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(this.theme.chipBg)
          .borderRadius(8)
      } else if (item.enabled) {
        this.appIcon($r('app.media.ic_chevron_right'),
          SIZE_PROVIDER_CHEVRON, this.theme.textTertiary)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.theme.surface)
    .borderRadius(12)
    .opacity(item.enabled ? 1.0 : 0.55)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (item.enabled) {
        this.vm.onSelectProvider(item.type);
      }
    })
  }

  @Builder
  buildAuthView() {
    Column() {
      Row() {
        Row({ space: 4 }) {
          this.appIcon($r('app.media.ic_chevron_left'),
            SIZE_HEADER_ICON, this.theme.primary)
          Text(t('priv.goBack'))
            .fontSize(15)
            .fontColor(this.theme.primary)
        }
        .padding({ top: 6, bottom: 6, right: 8 })
        .alignItems(VerticalAlign.Center)
        .onClick(() => { this.vm.onBack(); })

        Blank()
      }
      .width('100%')
      .margin({ bottom: 12 })

      if (this.vm.authUrl.length > 0) {
        Web({ src: this.vm.authUrl, controller: this.controller })
          .userAgent(MOBILE_USER_AGENT)
          .darkMode(this.webDarkMode())
          .forceDarkAccess(false)
          .onLoadIntercept((event) => {
            if (event === undefined) return false;
            const url: string = event.data.getRequestUrl();

            if (url.startsWith('https://cl.drive/oauth')) {
              this.vm.handleRedirect(url);
              return true;
            }
            if (url.startsWith('http://127.0.0.1:8080/oauth2redirect')
              || url.startsWith('http://localhost:8080/oauth2redirect')) {
              this.vm.handleRedirect(url);
              return true;
            }
            if (url.startsWith('https://cl.drive/dropbox-oauth')) {
              this.vm.handleRedirect(url);
              return true;
            }
            return false;
          })
          .domStorageAccess(true)
          .javaScriptAccess(true)
          .fileAccess(false)
          .onlineImageAccess(true)
          .mixedMode(MixedMode.All)
          .width('100%')
          .layoutWeight(1)
          .borderRadius(12)
          .backgroundColor(this.theme.surface)
      } else {
        Column({ space: 12 }) {
          LoadingProgress().width(36).height(36).color(this.theme.primary)
          Text(t('onb.preparing'))
            .fontSize(13)
            .fontColor(this.theme.textSecondary)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }

      if (this.vm.isLoading) {
        Row({ space: 12 }) {
          LoadingProgress().width(20).height(20).color(this.theme.primary)
          Text(t('onb.completing'))
            .fontSize(14)
            .fontColor(this.theme.textSecondary)
        }
        .margin({ top: 16 })
      }

      if (this.vm.statusMessage.length > 0) {
        Text(this.vm.statusMessage)
          .fontSize(13)
          .fontColor(this.theme.error)
          .margin({ top: 16 })
          .textAlign(TextAlign.Center)
          .width('100%')
      }
    }
    .width('100%')
    .layoutWeight(1)
  }
}
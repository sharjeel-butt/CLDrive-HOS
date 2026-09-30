import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ThemeManager } from '../core/theme/ThemeManager';
import { ThemeColors } from '../core/theme/ThemeColors';
import { PrivacyPrefs } from '../core/settings/PrivacyPrefs';
import { AuthManager } from '../core/auth/AuthManager';
import { t } from '../core/i18n/I18n';
import { Routes } from '../utils/RouteConstants';
import { Logger } from '../utils/Logger';
import { AppVersionInfo, getAppVersionInfo } from '../utils/AppInfo';

const TAG: string = 'PrivacyPolicyPage';

interface PrivacyPoint {
  icon: string;
  titleKey: string;
  bodyKey: string;
}

const PRIVACY_POINTS: PrivacyPoint[] = [
  { icon: '🔒', titleKey: 'priv.point1.title', bodyKey: 'priv.point1.body' },
  { icon: '☁',  titleKey: 'priv.point2.title', bodyKey: 'priv.point2.body' },
  { icon: '🚫', titleKey: 'priv.point3.title', bodyKey: 'priv.point3.body' },
  { icon: '🔑', titleKey: 'priv.point4.title', bodyKey: 'priv.point4.body' },
  { icon: '🤝', titleKey: 'priv.point5.title', bodyKey: 'priv.point5.body' },
  { icon: '⚙',  titleKey: 'priv.point6.title', bodyKey: 'priv.point6.body' }
];

@Entry
@Component
struct PrivacyPolicyPage {
  @State private theme: ThemeColors = ThemeManager.get().colors();
  @State private agreed: boolean = false;
  @State private isProcessing: boolean = false;

  @StorageLink('languageVersion') langVersion: number = 0;

  private onThemeChanged = (): void => {
    this.theme = ThemeManager.get().colors();
  };

  aboutToAppear(): void {
    this.theme = ThemeManager.get().colors();
    ThemeManager.get().subscribe(this.onThemeChanged);
  }

  aboutToDisappear(): void {
    ThemeManager.get().unsubscribe(this.onThemeChanged);
  }

  private appDisplayName(): string {
    const info: AppVersionInfo = getAppVersionInfo();
    const name: string = info.appName;
    if (name.length === 0 || name === '—'
      || name.startsWith('$string:') || name.startsWith('@string/')) {
      return info.bundleName;
    }
    return name;
  }

  async onAgree(): Promise<void> {
    if (!this.agreed || this.isProcessing) return;
    this.isProcessing = true;
    try {
      await PrivacyPrefs.accept();
      const hasAccounts: boolean = await AuthManager.hasAccounts();
      router.replaceUrl({
        url: hasAccounts ? Routes.FILE_BROWSER : Routes.ONBOARDING
      }).catch((e: Error) => {
        Logger.error(TAG, `replaceUrl failed: ${e.message}`);
      });
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `onAgree failed: ${err.message}`);
      this.isProcessing = false;
    }
  }

  onDecline(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    promptAction.showDialog({
      title: t('priv.declineTitle'),
      message: t('priv.declineBody'),
      buttons: [
        { text: t('priv.goBack'), color: '#0A5BD3' },
        { text: t('priv.exit'), color: '#D32F2F' }
      ]
    })
      .then((r: promptAction.ShowDialogSuccessResponse) => {
        if (r.index === 1) {
          ctx.terminateSelf().catch((e: Error) => {
            Logger.error(TAG, `terminateSelf failed: ${e.message}`);
          });
        }
      })
      .catch(() => { /* dismissed */ });
  }

  onViewOnline(): void {
    router.pushUrl({ url: Routes.PRIVACY_VIEWER })
      .catch((e: Error) => {
        Logger.error(TAG, `pushUrl failed: ${e.message}`);
      });
  }

  build() {
    Column() {
      Column({ space: 4 }) {
        Text(t('priv.title'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Start)
          .width('100%')
        Text(t('priv.subtitle'))
          .fontSize(13)
          .fontColor(this.theme.textSecondary)
          .textAlign(TextAlign.Start)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 24, right: 24, top: 32, bottom: 16 })

      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 12 }) {
            Image($r('app.media.app_icon'))
              .width(44).height(44)
              .objectFit(ImageFit.Contain)
              .draggable(false)
              .borderRadius(11)

            Column({ space: 2 }) {
              Text(this.appDisplayName())
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textPrimary)
                .textAlign(TextAlign.Start)
                .width('100%')
              Text(t('priv.header'))
                .fontSize(12)
                .fontColor(this.theme.textSecondary)
                .textAlign(TextAlign.Start)
                .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding(16)
          .backgroundColor(this.theme.surfaceSubtle)
          .borderRadius(14)

          ForEach(PRIVACY_POINTS, (point: PrivacyPoint) => {
            Row({ space: 14 }) {
              Column() {
                Text(point.icon).fontSize(20)
              }
              .width(40).height(40).borderRadius(10)
              .backgroundColor(this.theme.primarySoft)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)

              Column({ space: 3 }) {
                Text(t(point.titleKey))
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme.textPrimary)
                  .textAlign(TextAlign.Start)
                  .width('100%')
                Text(t(point.bodyKey))
                  .fontSize(12)
                  .fontColor(this.theme.textSecondary)
                  .textAlign(TextAlign.Start)
                  .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(this.theme.surface)
            .borderRadius(12)
            .alignItems(VerticalAlign.Top)
          }, (point: PrivacyPoint) => point.titleKey)

          Row({ space: 8 }) {
            Text('📄').fontSize(16)
            Text(t('priv.viewOnline'))
              .fontSize(14)
              .fontColor(this.theme.primary)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
            Text('›').fontSize(20).fontColor(this.theme.primary)
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 14, bottom: 14 })
          .backgroundColor(this.theme.primarySoft)
          .borderRadius(12)
          .alignItems(VerticalAlign.Center)
          .onClick(() => { this.onViewOnline(); })

          Row().height(16)
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Column({ space: 16 }) {
        Row({ space: 12 }) {
          Text(this.agreed ? '☑' : '☐')
            .fontSize(24)
            .fontColor(this.agreed
              ? this.theme.primary : this.theme.textTertiary)
            .width(28).textAlign(TextAlign.Center)

          Text(t('priv.agreeCheck'))
            .fontSize(13)
            .fontColor(this.theme.textPrimary)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .alignItems(VerticalAlign.Center)
        .onClick(() => { this.agreed = !this.agreed; })

        Row({ space: 12 }) {
          Button(t('priv.decline'))
            .layoutWeight(1)
            .backgroundColor(this.theme.chipBg)
            .fontColor(this.theme.textPrimary)
            .fontSize(15)
            .enabled(!this.isProcessing)
            .onClick(() => { this.onDecline(); })

          Button(this.isProcessing ? t('common.saving') : t('priv.agree'))
            .layoutWeight(1.5)
            .backgroundColor(this.agreed
              ? this.theme.primary : this.theme.border)
            .fontColor(this.theme.primaryContrast)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .enabled(this.agreed && !this.isProcessing)
            .onClick(() => { this.onAgree(); })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 28 })
      .backgroundColor(this.theme.surface)
      .shadow({ radius: 12, color: '#22000000', offsetX: 0, offsetY: -2 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.background)
  }
}
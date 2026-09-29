import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ThemeManager } from '../core/theme/ThemeManager';
import { ThemeColors } from '../core/theme/ThemeColors';
import { PrivacyPrefs } from '../core/settings/PrivacyPrefs';
import { AuthManager } from '../core/auth/AuthManager';
import { Routes } from '../utils/RouteConstants';
import { Logger } from '../utils/Logger';
import { AppVersionInfo, getAppVersionInfo } from '../utils/AppInfo';

const TAG: string = 'PrivacyPolicyPage';

const PRIVACY_POLICY_URL: string =
  'https://sharjeel-butt.github.io/CLDrive-HOS/';

interface PrivacyPoint {
  icon: string;
  title: string;
  body: string;
}

const PRIVACY_POINTS: PrivacyPoint[] = [
  {
    icon: '🔒',
    title: 'Your data stays on your device',
    body: 'CLDrive does not operate servers. Your files and account data are never sent to us.'
  },
  {
    icon: '☁',
    title: 'Direct cloud connection',
    body: 'Files move directly between your device and the cloud provider you choose — OneDrive, Google Drive, or Dropbox.'
  },
  {
    icon: '🚫',
    title: 'No tracking, no analytics',
    body: 'We do not collect analytics, crash reports, device identifiers, location data, or usage statistics.'
  },
  {
    icon: '🔑',
    title: 'Secure token storage',
    body: 'OAuth tokens are stored in HarmonyOS Asset Store, the operating system\u2019s hardware-backed encrypted storage.'
  },
  {
    icon: '🤝',
    title: 'Only connected providers',
    body: 'Data is shared only with the cloud providers you explicitly connect. No advertising SDKs, no telemetry services.'
  },
  {
    icon: '⚙',
    title: 'You are in control',
    body: 'Sign out, clear offline files, clear task history, or revoke app access at any time.'
  }
];

@Entry
@Component
struct PrivacyPolicyPage {
  @State private theme: ThemeColors = ThemeManager.get().colors();
  @State private agreed: boolean = false;
  @State private isProcessing: boolean = false;

  private onThemeChanged = (): void => {
    this.theme = ThemeManager.get().colors();
  };

  aboutToAppear(): void {
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
      return 'CLDrive';
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
      title: 'Decline privacy policy?',
      message: 'You must agree to the Privacy Policy to use CLDrive. ' +
        'Declining will close the app.',
      buttons: [
        { text: 'Go back', color: '#0A5BD3' },
        { text: 'Exit', color: '#D32F2F' }
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
      // ---- Header ----
      Column({ space: 4 }) {
        Text('Before you continue')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Start)
          .width('100%')
        Text('Please review and accept our Privacy Policy')
          .fontSize(13)
          .fontColor(this.theme.textSecondary)
          .textAlign(TextAlign.Start)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 24, right: 24, top: 32, bottom: 16 })

      // ---- Scrollable content ----
      Scroll() {
        Column({ space: 12 }) {
          // Branding
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
              Text('Privacy Policy')
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

          // Summary points
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
                Text(point.title)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme.textPrimary)
                  .textAlign(TextAlign.Start)
                  .width('100%')
                Text(point.body)
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
          }, (point: PrivacyPoint) => point.title)

          // View full policy link
          Row({ space: 8 }) {
            Text('📄').fontSize(16)
            Text('View full policy online')
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

      // ---- Bottom action bar ----
      Column({ space: 16 }) {
        // Agreement checkbox
        Row({ space: 12 }) {
          Text(this.agreed ? '☑' : '☐')
            .fontSize(24)
            .fontColor(this.agreed
              ? this.theme.primary : this.theme.textTertiary)
            .width(28).textAlign(TextAlign.Center)

          Text('I have read and agree to the Privacy Policy')
            .fontSize(13)
            .fontColor(this.theme.textPrimary)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .alignItems(VerticalAlign.Center)
        .onClick(() => { this.agreed = !this.agreed; })

        // Buttons
        Row({ space: 12 }) {
          Button('Decline')
            .layoutWeight(1)
            .backgroundColor(this.theme.chipBg)
            .fontColor(this.theme.textPrimary)
            .fontSize(15)
            .enabled(!this.isProcessing)
            .onClick(() => { this.onDecline(); })

          Button(this.isProcessing ? 'Saving...' : 'Agree & Continue')
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
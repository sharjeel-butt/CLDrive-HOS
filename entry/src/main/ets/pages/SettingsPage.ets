import { router } from '@kit.ArkUI';
import { ThemeManager } from '../core/theme/ThemeManager';
import { ThemeMode } from '../core/theme/ThemeMode';
import { ThemeColors } from '../core/theme/ThemeColors';
import { Logger } from '../utils/Logger';

const TAG: string = 'SettingsPage';

interface ThemeOption {
  mode: ThemeMode;
  label: string;
  subtitle: string;
  icon: string;
}

@Entry
@Component
struct SettingsPage {
  @State private theme: ThemeColors = ThemeManager.get().colors();
  @State private currentMode: ThemeMode = ThemeManager.get().getPreference();

  // Collapse state for the Appearance card.
  @State private appearanceExpanded: boolean = true;

  private readonly options: ThemeOption[] = [
    {
      mode: ThemeMode.LIGHT,
      label: 'Light',
      subtitle: 'Always use the light theme',
      icon: '☀'
    },
    {
      mode: ThemeMode.DARK,
      label: 'Dark',
      subtitle: 'Always use the dark theme',
      icon: '☾'
    },
    {
      mode: ThemeMode.SYSTEM,
      label: 'Use system settings',
      subtitle: 'Follow your device theme',
      icon: '⚙'
    }
  ];

  private onThemeChange = (): void => {
    this.theme = ThemeManager.get().colors();
    this.currentMode = ThemeManager.get().getPreference();
  };

  aboutToAppear(): void {
    ThemeManager.get().subscribe(this.onThemeChange);
  }

  aboutToDisappear(): void {
    ThemeManager.get().unsubscribe(this.onThemeChange);
  }

  build() {
    Column() {
      this.buildHeader()

      Scroll() {
        Column({ space: 24 }) {
          // ---- Appearance section ----
          this.buildSectionLabel('APPEARANCE')

          Column() {
            this.buildAppearanceHeader()
            if (this.appearanceExpanded) {
              Divider()
                .color(this.theme.divider)
                .margin({ left: 20, right: 20 })
              this.buildOptionRow(this.options[0])
              this.buildOptionRow(this.options[1])
              this.buildOptionRow(this.options[2])
            }
          }
          .width('100%')
          .backgroundColor(this.theme.surface)
          .borderRadius(14)

          // ---- About section ----
          this.buildSectionLabel('ABOUT')

          Column() {
            this.buildAboutRow('Version', '1.0.0')
            Divider().color(this.theme.divider).margin({ left: 20, right: 20 })
            this.buildAboutRow('Provider', 'OneDrive · Google Drive')
            Divider().color(this.theme.divider).margin({ left: 20, right: 20 })
            this.buildAboutRow('Cloud', 'Microsoft Graph v1.0 · Drive v3')
          }
          .width('100%')
          .backgroundColor(this.theme.surface)
          .borderRadius(14)

          Row().height(32)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.background)
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  @Builder
  buildHeader() {
    Row({ space: 12 }) {
      Text('←')
        .fontSize(24)
        .fontColor(this.theme.textPrimary)
        .width(40)
        .textAlign(TextAlign.Center)
        .onClick(() => { router.back(); })

      Text('Settings')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textPrimary)
        .layoutWeight(1)

      Row().width(40)
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  buildSectionLabel(label: string) {
    Text(label)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.theme.textTertiary)
      .width('100%')
      .padding({ left: 8, top: 4, bottom: 8 })
      .textAlign(TextAlign.Start)
  }

  // ---------------------------------------------------------------------------
  // Appearance card header — tappable to expand / collapse
  // ---------------------------------------------------------------------------

  @Builder
  buildAppearanceHeader() {
    Row({ space: 14 }) {
      Column() {
        Text(this.theme.isDark ? '☾' : '☀')
          .fontSize(20)
          .fontColor(this.theme.primary)
      }
      .width(36)
      .height(36)
      .borderRadius(10)
      .backgroundColor(this.theme.primarySoft)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 2 }) {
        Text('Dark mode')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Start)
          .width('100%')

        Text(this.currentModeLabel())
          .fontSize(12)
          .fontColor(this.theme.textSecondary)
          .textAlign(TextAlign.Start)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // Chevron — rotates based on expanded state.
      Text(this.appearanceExpanded ? '▾' : '▸')
        .fontSize(18)
        .fontColor(this.theme.textTertiary)
        .width(24)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.appearanceExpanded = !this.appearanceExpanded;
    })
  }

  private currentModeLabel(): string {
    if (this.currentMode === ThemeMode.LIGHT) return 'Light';
    if (this.currentMode === ThemeMode.DARK) return 'Dark';
    return 'Following system';
  }

  // ---------------------------------------------------------------------------
  // Option row (radio)
  // ---------------------------------------------------------------------------

  @Builder
  buildOptionRow(option: ThemeOption) {
    Row({ space: 14 }) {
      Text(option.icon)
        .fontSize(18)
        .fontColor(this.theme.textSecondary)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)

      Column({ space: 2 }) {
        Text(option.label)
          .fontSize(15)
          .fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Start)
          .width('100%')

        Text(option.subtitle)
          .fontSize(12)
          .fontColor(this.theme.textSecondary)
          .textAlign(TextAlign.Start)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column() {
        if (this.currentMode === option.mode) {
          Column()
            .width(10)
            .height(10)
            .borderRadius(5)
            .backgroundColor(this.theme.primaryContrast)
        }
      }
      .width(22)
      .height(22)
      .borderRadius(11)
      .backgroundColor(
        this.currentMode === option.mode
          ? this.theme.primary
          : this.theme.background
      )
      .border({
        width: 2,
        color: this.currentMode === option.mode
          ? this.theme.primary
          : this.theme.border
      })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      ThemeManager.get().setPreference(option.mode)
        .catch((e: Error) => {
          Logger.error(TAG, `setPreference failed: ${e.message}`);
        });
    })
  }

  // ---------------------------------------------------------------------------
  // About rows
  // ---------------------------------------------------------------------------

  @Builder
  buildAboutRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(this.theme.textPrimary)
        .layoutWeight(1)

      Text(value)
        .fontSize(14)
        .fontColor(this.theme.textSecondary)
        .textAlign(TextAlign.End)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
  }
}
import { router, promptAction } from '@kit.ArkUI';
import { ThemeManager } from '../core/theme/ThemeManager';
import { ThemeMode } from '../core/theme/ThemeMode';
import { ThemeColors } from '../core/theme/ThemeColors';
import { UiPrefs } from '../core/settings/UiPrefs';
import { LanguageManager } from '../core/i18n/LanguageManager';
import {
  LanguageOption, LANGUAGES, LangCode, languageByCode, availableLanguages
} from '../core/i18n/Language';
import { t } from '../core/i18n/I18n';
import { Logger } from '../utils/Logger';
import { AppVersionInfo, getAppVersionInfo } from '../utils/AppInfo';
import { Routes } from '../utils/RouteConstants';

const TAG: string = 'SettingsPage';

const SIZE_HEADER_ICON_EXPANDED = 24;
const SIZE_HEADER_ICON_COLLAPSED = 20;
const SIZE_ROW_ICON = 20;
const SIZE_ROW_BOX = 40;
const SIZE_CHEVRON = 20;
const SIZE_TOGGLE_BOX = 22;
const SIZE_LANG_SHEET_CLOSE = 18;
const SIZE_LANG_SHEET_CHECK = 18;

interface ThemeOption {
  mode: ThemeMode;
  labelKey: string;
  subtitleKey: string;
  iconRes: Resource;
}

@Entry
@Component
struct SettingsPage {
  @State private theme: ThemeColors = ThemeManager.get().colors();
  @State private currentMode: ThemeMode = ThemeManager.get().getPreference();
  @State private appearanceExpanded: boolean = true;

  @State private headerCollapsed: boolean = false;

  @State private collapseSidebarByDefault: boolean = true;
  @State private uiPrefsLoaded: boolean = false;

  @State private currentLang: LangCode = 'en';
  @State private langPickerOpen: boolean = false;

  @StorageLink('languageVersion') langVersion: number = 0;

  private readonly options: ThemeOption[] = [
    {
      mode: ThemeMode.LIGHT,
      labelKey: 'set.theme.light',
      subtitleKey: 'set.theme.lightSub',
      iconRes: $r('app.media.ic_sun')
    },
    {
      mode: ThemeMode.DARK,
      labelKey: 'set.theme.dark',
      subtitleKey: 'set.theme.darkSub',
      iconRes: $r('app.media.ic_moon')
    },
    {
      mode: ThemeMode.SYSTEM,
      labelKey: 'set.theme.system',
      subtitleKey: 'set.theme.systemSub',
      iconRes: $r('app.media.ic_settings')
    }
  ];

  private onThemeChange = (): void => {
    this.theme = ThemeManager.get().colors();
    this.currentMode = ThemeManager.get().getPreference();
  };

  aboutToAppear(): void {
    ThemeManager.get().subscribe(this.onThemeChange);
    this.currentLang = LanguageManager.get();
    this.loadUiPrefs();
  }

  aboutToDisappear(): void {
    ThemeManager.get().unsubscribe(this.onThemeChange);
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

  private async loadUiPrefs(): Promise<void> {
    try {
      this.collapseSidebarByDefault =
        await UiPrefs.getCollapseSidebarGroups();
      this.uiPrefsLoaded = true;
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `loadUiPrefs failed: ${err.message}`);
    }
  }

  private versionLabel(): string {
    const info: AppVersionInfo = getAppVersionInfo();
    return info.versionName;
  }

  private buildNumber(): string {
    const info: AppVersionInfo = getAppVersionInfo();
    return info.versionCode.toString();
  }

  private currentModeLabel(): string {
    if (this.currentMode === ThemeMode.LIGHT) return t('set.theme.light');
    if (this.currentMode === ThemeMode.DARK) return t('set.theme.dark');
    return t('set.theme.following');
  }

  build() {
    Stack() {
      Column() {
        this.buildHeader()

        Scroll() {
          Column({ space: 24 }) {
            // ---- Appearance ----
            this.buildSectionLabel(t('set.section.appear'))

            Column() {
              this.buildAppearanceHeader()
              if (this.appearanceExpanded) {
                Divider().color(this.theme.divider).margin({ left: 20, right: 20 })
                this.buildOptionRow(this.options[0])
                this.buildOptionRow(this.options[1])
                this.buildOptionRow(this.options[2])
              }
            }
            .width('100%')
            .backgroundColor(this.theme.surface)
            .borderRadius(14)

            // ---- UI Customization ----
            this.buildSectionLabel(t('set.section.ui'))

            Column() {
              this.buildSidebarCollapseRow()
            }
            .width('100%')
            .backgroundColor(this.theme.surface)
            .borderRadius(14)

            // ---- Language ----
            this.buildSectionLabel(t('set.section.lang'))

            Column() {
              this.buildLanguageRow()
            }
            .width('100%')
            .backgroundColor(this.theme.surface)
            .borderRadius(14)

            // ---- About ----
            this.buildSectionLabel(t('set.section.about'))

            Column() {
              this.buildAboutRow(t('set.version'), this.versionLabel())
              Divider().color(this.theme.divider).margin({ left: 20, right: 20 })
              this.buildAboutRow(t('set.build'), this.buildNumber())
              Divider().color(this.theme.divider).margin({ left: 20, right: 20 })
              this.buildAboutRow(t('set.provider'), t('set.providerVal'))
              Divider().color(this.theme.divider).margin({ left: 20, right: 20 })
              this.buildAboutRow(t('set.cloud'), t('set.cloudVal'))
              Divider().color(this.theme.divider).margin({ left: 20, right: 20 })
              this.buildPrivacyPolicyRow()
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
        .onScroll((xOffset: number, yOffset: number) => {
          const shouldCollapse: boolean = yOffset > 16;
          if (shouldCollapse !== this.headerCollapsed) {
            this.headerCollapsed = shouldCollapse;
          }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme.background)

      if (this.langPickerOpen) {
        Column() {
          Column()
            .width('100%')
            .layoutWeight(1)
            .backgroundColor(this.theme.overlay)
            .onClick(() => { this.langPickerOpen = false; })
          this.buildLanguagePickerSheet()
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.background)
  }

  @Builder
  buildHeader() {
    Row({ space: 12 }) {
      Row() {
        this.appIcon(
          $r('app.media.ic_back'),
          this.headerCollapsed ? SIZE_HEADER_ICON_COLLAPSED : SIZE_HEADER_ICON_EXPANDED,
          this.theme.textPrimary
        )
      }
      .width(this.headerCollapsed ? 36 : 44)
      .height(this.headerCollapsed ? 36 : 44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { router.back(); })

      if (!this.headerCollapsed) {
        Text(t('set.title'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textPrimary)
          .layoutWeight(1)
          .transition(TransitionEffect.OPACITY.animation({ duration: 150 }))
      } else {
        Row().layoutWeight(1)
      }

      Row().width(this.headerCollapsed ? 36 : 44)
    }
    .width('100%')
    .height(this.headerCollapsed ? 44 : 56)
    .padding({
      left: 8,
      right: 8,
      top: this.headerCollapsed ? 4 : 8,
      bottom: this.headerCollapsed ? 4 : 8
    })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.theme.background)
    .animation({
      duration: 180,
      curve: Curve.EaseInOut
    })
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

  @Builder
  buildAppearanceHeader() {
    Row({ space: 14 }) {
      Column() {
        this.appIcon(
          this.theme.isDark ? $r('app.media.ic_moon') : $r('app.media.ic_sun'),
          SIZE_ROW_ICON, this.theme.primary
        )
      }
      .width(SIZE_ROW_BOX).height(SIZE_ROW_BOX)
      .borderRadius(10)
      .backgroundColor(this.theme.primarySoft)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 2 }) {
        Text(t('set.darkMode'))
          .fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Start).width('100%')
        Text(this.currentModeLabel())
          .fontSize(12).fontColor(this.theme.textSecondary)
          .textAlign(TextAlign.Start).width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      this.appIcon(
        this.appearanceExpanded
          ? $r('app.media.ic_chevron_down')
          : $r('app.media.ic_chevron_right'),
        SIZE_CHEVRON, this.theme.textTertiary
      )
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.appearanceExpanded = !this.appearanceExpanded; })
  }

  @Builder
  buildOptionRow(option: ThemeOption) {
    Row({ space: 14 }) {
      Column() {
        this.appIcon(option.iconRes, SIZE_ROW_ICON, this.theme.textSecondary)
      }
      .width(SIZE_ROW_BOX).height(SIZE_ROW_BOX)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 2 }) {
        Text(t(option.labelKey))
          .fontSize(15).fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Start).width('100%')
        Text(t(option.subtitleKey))
          .fontSize(12).fontColor(this.theme.textSecondary)
          .textAlign(TextAlign.Start).width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column() {
        if (this.currentMode === option.mode) {
          Column().width(10).height(10).borderRadius(5)
            .backgroundColor(this.theme.primaryContrast)
        }
      }
      .width(SIZE_TOGGLE_BOX).height(SIZE_TOGGLE_BOX)
      .borderRadius(SIZE_TOGGLE_BOX / 2)
      .backgroundColor(this.currentMode === option.mode
        ? this.theme.primary : this.theme.background)
      .border({
        width: 2,
        color: this.currentMode === option.mode
          ? this.theme.primary : this.theme.border
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

  @Builder
  buildSidebarCollapseRow() {
    Row({ space: 14 }) {
      Column() {
        this.appIcon($r('app.media.ic_list'), SIZE_ROW_ICON, this.theme.primary)
      }
      .width(SIZE_ROW_BOX).height(SIZE_ROW_BOX)
      .borderRadius(10)
      .backgroundColor(this.theme.primarySoft)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 2 }) {
        Text(t('set.collapse'))
          .fontSize(15).fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Start).width('100%')
        Text(t('set.collapseSub'))
          .fontSize(12).fontColor(this.theme.textSecondary)
          .textAlign(TextAlign.Start).width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({
        type: ToggleType.Switch,
        isOn: this.collapseSidebarByDefault
      })
        .selectedColor(this.theme.primary)
        .enabled(this.uiPrefsLoaded)
        .onChange((isOn: boolean) => {
          this.collapseSidebarByDefault = isOn;
          UiPrefs.setCollapseSidebarGroups(isOn)
            .catch((e: Error) => {
              Logger.error(TAG, `setCollapseSidebarGroups failed: ${e.message}`);
              this.collapseSidebarByDefault = !isOn;
            });
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  buildLanguageRow() {
    Row({ space: 14 }) {
      Column() {
        this.appIcon($r('app.media.ic_language'), SIZE_ROW_ICON, this.theme.primary)
      }
      .width(SIZE_ROW_BOX).height(SIZE_ROW_BOX)
      .borderRadius(10)
      .backgroundColor(this.theme.primarySoft)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 2 }) {
        Text(t('set.lang'))
          .fontSize(15).fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Start).width('100%')
        Text(languageByCode(this.currentLang).nativeName)
          .fontSize(12).fontColor(this.theme.textSecondary)
          .textAlign(TextAlign.Start).width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      this.appIcon($r('app.media.ic_chevron_right'),
        SIZE_CHEVRON, this.theme.textTertiary)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.langPickerOpen = true; })
  }

  @Builder
  buildLanguagePickerSheet() {
    Column() {
      Row()
        .width(40).height(4).borderRadius(2)
        .backgroundColor(this.theme.border)
        .margin({ top: 8, bottom: 12 })

      Row() {
        Column({ space: 2 }) {
          Text(t('lang.title'))
            .fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor(this.theme.textPrimary)
            .textAlign(TextAlign.Start).width('100%')
          Text(t('lang.subtitle'))
            .fontSize(11).fontColor(this.theme.textTertiary)
            .textAlign(TextAlign.Start).width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row() {
          this.appIcon($r('app.media.ic_close'),
            SIZE_LANG_SHEET_CLOSE, this.theme.textSecondary)
        }
        .width(36).height(36)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.langPickerOpen = false; })
      }
      .width('100%')
      .padding({ left: 20, right: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      Divider().color(this.theme.divider)

      List({ space: 1 }) {
        ForEach(availableLanguages(), (lang: LanguageOption) => {
          ListItem() {
            Row({ space: 14 }) {
              Column({ space: 3 }) {
                Text(lang.englishName)
                  .fontSize(15).fontColor(this.theme.textPrimary)
                  .textAlign(TextAlign.Start).width('100%')
                Text(lang.nativeName)
                  .fontSize(12).fontColor(this.theme.textSecondary)
                  .textAlign(TextAlign.Start).width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              if (this.currentLang === lang.code) {
                this.appIcon($r('app.media.ic_check'),
                  SIZE_LANG_SHEET_CHECK, this.theme.primary)
              }
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 12, bottom: 12 })
            .backgroundColor(this.currentLang === lang.code
              ? this.theme.chipSelectedBg : Color.Transparent)
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              this.currentLang = lang.code;
              LanguageManager.set(lang.code)
                .then(() => { this.langPickerOpen = false; })
                .catch((e: Error) => {
                  Logger.error(TAG, `set language failed: ${e.message}`);
                });
            })
          }
        }, (lang: LanguageOption) => lang.code)
      }
      .width('100%')
      .constraintSize({ maxHeight: 480 })
      .divider({ strokeWidth: 1, color: this.theme.divider })
    }
    .width('100%')
    .backgroundColor(this.theme.surface)
    .borderRadius({ topLeft: 20, topRight: 20 })
    .shadow({ radius: 20, color: '#22000000', offsetX: 0, offsetY: -4 })
  }

  @Builder
  buildAboutRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(15)
        .fontColor(this.theme.textPrimary)

      Text(value)
        .fontSize(14)
        .fontColor(this.theme.textSecondary)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
  }

  @Builder
  buildPrivacyPolicyRow() {
    Row({ space: 12 }) {
      this.appIcon($r('app.media.ic_privacy_lock'),
        SIZE_ROW_ICON, this.theme.primary)

      Text(t('set.privacy'))
        .fontSize(15)
        .fontColor(this.theme.primary)
        .layoutWeight(1)

      this.appIcon($r('app.media.ic_chevron_right'),
        SIZE_CHEVRON, this.theme.primary)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      router.pushUrl({ url: Routes.PRIVACY_VIEWER })
        .catch((e: Error) => {
          Logger.error(TAG, `pushUrl privacy viewer failed: ${e.message}`);
        });
    })
  }
}
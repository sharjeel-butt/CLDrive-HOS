import { router, promptAction } from '@kit.ArkUI';
import { ThemeManager } from '../core/theme/ThemeManager';
import { ThemeMode } from '../core/theme/ThemeMode';
import { ThemeColors } from '../core/theme/ThemeColors';
import { UiPrefs } from '../core/settings/UiPrefs';
import { OfflineStore, CacheInfo } from '../core/services/OfflineStore';
import { Logger } from '../utils/Logger';
import { AppVersionInfo, getAppVersionInfo } from '../utils/AppInfo';

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
  @State private appearanceExpanded: boolean = true;

  // ---- Collapsing header ----
  @State private headerCollapsed: boolean = false;

  // ---- UI customization ----
  @State private collapseSidebarByDefault: boolean = true;
  @State private uiPrefsLoaded: boolean = false;

  // ---- Cache state ----
  @State private cacheFileCount: number = 0;
  @State private cacheTotalBytes: number = 0;
  @State private cacheLoading: boolean = true;
  @State private cacheClearing: boolean = false;

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
    this.loadCacheInfo();
    this.loadUiPrefs();
  }

  aboutToDisappear(): void {
    ThemeManager.get().unsubscribe(this.onThemeChange);
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

  private async loadCacheInfo(): Promise<void> {
    this.cacheLoading = true;
    try {
      const info: CacheInfo = await OfflineStore.getCacheInfo();
      this.cacheFileCount = info.fileCount;
      this.cacheTotalBytes = info.totalBytes;
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `loadCacheInfo failed: ${err.message}`);
    } finally {
      this.cacheLoading = false;
    }
  }

  private onClearCache(): void {
    if (this.cacheFileCount === 0) return;

    promptAction.showDialog({
      title: 'Clear offline cache?',
      message: `${this.cacheFileCount} file${this.cacheFileCount === 1 ? '' : 's'} (${SettingsPage.formatSize(this.cacheTotalBytes)}) will be deleted. Files marked offline will need to be re-downloaded to open offline again.`,
      buttons: [
        { text: 'Cancel', color: '#666666' },
        { text: 'Clear', color: '#D32F2F' }
      ]
    })
      .then(async (r: promptAction.ShowDialogSuccessResponse) => {
        if (r.index !== 1) return;

        this.cacheClearing = true;
        try {
          await OfflineStore.clearAll();
          this.cacheFileCount = 0;
          this.cacheTotalBytes = 0;
          promptAction.showToast({ message: 'Cache cleared' });
        } catch (e) {
          const err: Error = e as Error;
          Logger.error(TAG, `clearAll failed: ${err.message}`);
          promptAction.showToast({ message: `Failed: ${err.message}` });
        } finally {
          this.cacheClearing = false;
        }
      })
      .catch(() => { /* dismissed */ });
  }

  private static formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    }
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  }

  private cacheSummary(): string {
    if (this.cacheLoading) return 'Calculating...';
    if (this.cacheFileCount === 0) return 'No files cached';
    const sizeStr: string = SettingsPage.formatSize(this.cacheTotalBytes);
    return this.cacheFileCount === 1
      ? `1 file · ${sizeStr}`
      : `${this.cacheFileCount} files · ${sizeStr}`;
  }

  private versionLabel(): string {
    const info: AppVersionInfo = getAppVersionInfo();
    return info.versionName;
  }

  private buildNumber(): string {
    const info: AppVersionInfo = getAppVersionInfo();
    return info.versionCode.toString();
  }

  build() {
    Column() {
      this.buildHeader()

      Scroll() {
        Column({ space: 24 }) {
          // ---- Appearance ----
          this.buildSectionLabel('APPEARANCE')

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
          this.buildSectionLabel('UI CUSTOMIZATION')

          Column() {
            this.buildSidebarCollapseRow()
          }
          .width('100%')
          .backgroundColor(this.theme.surface)
          .borderRadius(14)

          // ---- Storage ----
          this.buildSectionLabel('STORAGE')

          Column() {
            this.buildStorageHeader()
            Divider().color(this.theme.divider).margin({ left: 20, right: 20 })
            this.buildClearCacheRow()
          }
          .width('100%')
          .backgroundColor(this.theme.surface)
          .borderRadius(14)

          // ---- About ----
          this.buildSectionLabel('ABOUT')

          Column() {
            this.buildAboutRow('Version', this.versionLabel())
            Divider().color(this.theme.divider).margin({ left: 20, right: 20 })
            this.buildAboutRow('Build', this.buildNumber())
            Divider().color(this.theme.divider).margin({ left: 20, right: 20 })
            this.buildAboutRow('Provider', 'OneDrive · Google Drive · Dropbox')
            Divider().color(this.theme.divider).margin({ left: 20, right: 20 })
            this.buildAboutRow('Cloud', 'Microsoft Graph v1.0 · Drive v3 · Dropbox v2')
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
        // Collapse once the user has scrolled past ~16 vp; expand again
        // when they return near the top. Hysteresis via the flag check
        // avoids re-rendering on every scroll tick.
        const shouldCollapse: boolean = yOffset > 16;
        if (shouldCollapse !== this.headerCollapsed) {
          this.headerCollapsed = shouldCollapse;
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.background)
  }

  // ---------------------------------------------------------------------------
  // Header / section label
  // ---------------------------------------------------------------------------

  @Builder
  buildHeader() {
    Row({ space: 12 }) {
      Text('←')
        .fontSize(this.headerCollapsed ? 20 : 24)
        .fontColor(this.theme.textPrimary)
        .width(this.headerCollapsed ? 32 : 40)
        .textAlign(TextAlign.Center)
        .onClick(() => { router.back(); })

      if (!this.headerCollapsed) {
        Text('Settings')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textPrimary)
          .layoutWeight(1)
          .transition(TransitionEffect.OPACITY.animation({ duration: 150 }))
      } else {
        Row().layoutWeight(1)
      }

      Row().width(this.headerCollapsed ? 32 : 40)
    }
    .width('100%')
    .height(this.headerCollapsed ? 40 : 52)
    .padding({
      left: 8,
      right: 8,
      top: this.headerCollapsed ? 6 : 12,
      bottom: this.headerCollapsed ? 6 : 12
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

  // ---------------------------------------------------------------------------
  // Appearance section
  // ---------------------------------------------------------------------------

  @Builder
  buildAppearanceHeader() {
    Row({ space: 14 }) {
      Column() {
        Text(this.theme.isDark ? '☾' : '☀')
          .fontSize(20)
          .fontColor(this.theme.primary)
      }
      .width(36).height(36).borderRadius(10)
      .backgroundColor(this.theme.primarySoft)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 2 }) {
        Text('Dark mode')
          .fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Start).width('100%')
        Text(this.currentModeLabel())
          .fontSize(12).fontColor(this.theme.textSecondary)
          .textAlign(TextAlign.Start).width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.appearanceExpanded ? '▾' : '▸')
        .fontSize(18).fontColor(this.theme.textTertiary)
        .width(24).textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.appearanceExpanded = !this.appearanceExpanded; })
  }

  private currentModeLabel(): string {
    if (this.currentMode === ThemeMode.LIGHT) return 'Light';
    if (this.currentMode === ThemeMode.DARK) return 'Dark';
    return 'Following system';
  }

  @Builder
  buildOptionRow(option: ThemeOption) {
    Row({ space: 14 }) {
      Text(option.icon)
        .fontSize(18).fontColor(this.theme.textSecondary)
        .width(36).height(36).textAlign(TextAlign.Center)

      Column({ space: 2 }) {
        Text(option.label)
          .fontSize(15).fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Start).width('100%')
        Text(option.subtitle)
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
      .width(22).height(22).borderRadius(11)
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

  // ---------------------------------------------------------------------------
  // UI customization section
  // ---------------------------------------------------------------------------

  @Builder
  buildSidebarCollapseRow() {
    Row({ space: 14 }) {
      Column() {
        Text('▸')
          .fontSize(18).fontColor(this.theme.primary)
      }
      .width(36).height(36).borderRadius(10)
      .backgroundColor(this.theme.primarySoft)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 2 }) {
        Text('Collapse sidebar groups')
          .fontSize(15).fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Start).width('100%')
        Text('Provider folders start collapsed each launch')
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

  // ---------------------------------------------------------------------------
  // Storage section
  // ---------------------------------------------------------------------------

  @Builder
  buildStorageHeader() {
    Row({ space: 14 }) {
      Column() {
        Text('📦').fontSize(20)
      }
      .width(36).height(36).borderRadius(10)
      .backgroundColor(this.theme.primarySoft)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 2 }) {
        Text('Offline files')
          .fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Start).width('100%')
        Text(this.cacheSummary())
          .fontSize(12).fontColor(this.theme.textSecondary)
          .textAlign(TextAlign.Start).width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.cacheLoading) {
        LoadingProgress().width(20).height(20).color(this.theme.primary)
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  buildClearCacheRow() {
    Row({ space: 14 }) {
      Text('🗑').fontSize(18)
        .fontColor(this.cacheFileCount > 0 ? this.theme.error : this.theme.textTertiary)
        .width(36).height(36).textAlign(TextAlign.Center)

      Text('Clear cache')
        .fontSize(15)
        .fontColor(this.cacheFileCount > 0 ? this.theme.error : this.theme.textTertiary)
        .layoutWeight(1)

      if (this.cacheClearing) {
        LoadingProgress().width(18).height(18).color(this.theme.error)
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (this.cacheFileCount === 0 || this.cacheClearing) return;
      this.onClearCache();
    })
  }

  // ---------------------------------------------------------------------------
  // About rows
  // ---------------------------------------------------------------------------

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
}
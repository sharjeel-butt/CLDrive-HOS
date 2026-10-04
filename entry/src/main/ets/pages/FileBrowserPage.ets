import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import {
  FileBrowserViewModel, ProviderGroup, Crumb,
  ActivityGroup,
  ACTIVITY_TAB_ALL, ACTIVITY_TAB_PENDING,
  ACTIVITY_TAB_SUCCESS, ACTIVITY_TAB_FAILED
} from '../viewmodels/FileBrowserViewModel';
import { CloudProviderType } from '../core/models/CloudProviderType';
import { CloudItem } from '../core/models/CloudItem';
import { CloudItemType } from '../core/models/CloudItemType';
import { AccountInfo } from '../core/models/AccountInfo';
import { StorageInfo } from '../core/models/StorageInfo';
import { ICloudProvider } from '../core/interfaces/ICloudProvider';
import { CloudProviderFactory } from '../core/providers/CloudProviderFactory';
import {
  Operation, OperationType, OperationStatus, OperationItemKind,
  operationTypeLabel, operationStatusLabel,
  isActiveStatus, canRetry
} from '../core/models/Operation';
import { OperationTracker } from '../core/services/OperationTracker';
import { OfflineStore, CacheInfo } from '../core/services/OfflineStore';
import { ThemeManager } from '../core/theme/ThemeManager';
import { ThemeColors } from '../core/theme/ThemeColors';
import { ProviderIcon } from '../components/ProviderIcon';
import { FileIcon } from '../components/FileIcon';
import { Routes } from '../utils/RouteConstants';
import { t, tNamed } from '../core/i18n/I18n';
import { Logger } from '../utils/Logger';

const TAG: string = 'FileBrowserPage';
const RETRY_ENABLED: boolean = true;

// ---- Top bar ----
const SIZE_TOPBAR_PRIMARY = 28;
const SIZE_TOPBAR_ACTION = 26;
const SIZE_CRUMB_CHEVRON = 12;

// ---- Selection bars ----
const SIZE_SELECTION_CLOSE = 24;
const SIZE_SELECTION_ACTION = 26;

// ---- Bottom bar ----
const SIZE_BOTTOM_SEARCH = 22;
const SIZE_BOTTOM_ADD = 30;

// ---- Upload popover ----
const SIZE_UPLOAD_MENU_ICON = 24;

// ---- Search overlay ----
const SIZE_SEARCH_BACK = 26;
const SIZE_SEARCH_EMPTY = 42;

// ---- Sort menu ----
const SIZE_SORT_CHECK = 18;

// ---- Filter chips ----
const SIZE_FILTER_CHIP = 14;

// ---- Item rows ----
const SIZE_ROW_VISUAL = 56;
const SIZE_ROW_FOLDER_ICON = 30;
const SIZE_ROW_BADGE = 18;
const SIZE_ROW_MORE = 26;
const ROW_DIVIDER_START = 86;

// ---- Grid tiles ----
const SIZE_GRID_FILEICON = 52;
const SIZE_GRID_BADGE_BOX = 24;
const SIZE_GRID_BADGE_ICON = 14;

// ---- Item actions sheet ----
const SIZE_SHEET_HEADER_FOLDER_BOX = 72;
const SIZE_SHEET_HEADER_FOLDER_ICON = 40;
const SIZE_SHEET_DELETE_ICON = 30;
const SIZE_SHEET_ROW_ICON = 26;

// ---- Tasks panel ----
const SIZE_TASKS_CLOSE = 18;
const SIZE_TASKS_CHIP_ICON = 12;
const SIZE_TASKS_STATUS = 20;
const SIZE_TASKS_RETRY = 22;
const SIZE_TASKS_KIND_ICON = 20;
const SIZE_TASKS_TYPE_ICON = 13;
const SIZE_TASKS_EMPTY = 44;

// ---- Sidebar ----
const SIZE_SIDEBAR_STORAGE = 20;
const SIZE_SIDEBAR_OFFLINE = 18;
const SIZE_SIDEBAR_CLEAR = 18;
const SIZE_SIDEBAR_FOOTER = 26;
const SIZE_SIDEBAR_PROVIDER_CHEVRON = 16;
const SIZE_SIDEBAR_ACCOUNT_CHECK = 18;
const SIZE_SIDEBAR_ACCOUNT_SIGNOUT = 20;

// ---- Empty states ----
const SIZE_EMPTY_ILLUSTRATION = 64;

interface SortOption {
  key: string;
  labelKey: string;
}

const SORT_OPTIONS: SortOption[] = [
  { key: 'name_asc',  labelKey: 'fb.sort.nameAsc' },
  { key: 'name_desc', labelKey: 'fb.sort.nameDesc' },
  { key: 'date_desc', labelKey: 'fb.sort.dateDesc' },
  { key: 'date_asc',  labelKey: 'fb.sort.dateAsc' },
  { key: 'size_desc', labelKey: 'fb.sort.sizeDesc' }
];

@Entry
@Component
struct FileBrowserPage {
  @State vm: FileBrowserViewModel = new FileBrowserViewModel();
  @State private theme: ThemeColors = ThemeManager.get().colors();

  @State private operations: Operation[] = [];
  @State private hasAnyOps: boolean = false;
  @State private canClearCompleted: boolean = false;
  @State private canClearAll: boolean = false;
  @State private activeOpCount: number = 0;
  @State private hasFinishedOps: boolean = false;
  @State private listVersion: number = 0;

  @State private tabAllCount: number = 0;
  @State private tabPendingCount: number = 0;
  @State private tabSuccessCount: number = 0;
  @State private tabFailedCount: number = 0;

  @State private isRefreshing: boolean = false;
  @State private sortMenuOpen: boolean = false;

  @State private selectionScale: number = 1.0;

  @State private cloudStorage: StorageInfo | null = null;
  @State private cloudStorageLoading: boolean = false;
  @State private offlineBytes: number = 0;
  @State private offlineCount: number = 0;
  @State private offlineClearing: boolean = false;

  @State private tasksIconColor: string = ThemeManager.get().colors().textTertiary;
  @State private tasksShowDot: boolean = false;

  @StorageLink('languageVersion') langVersion: number = 0;

  private crumbScroller: Scroller = new Scroller();

  // ===========================================================================
  // Icon helpers
  // ===========================================================================

  @Builder
  appIcon(media: Resource, size: number, color: string) {
    Image(media)
      .width(size)
      .height(size)
      .fillColor(color)
      .draggable(false)
      .objectFit(ImageFit.Contain)
  }

  private operationIconRes(type: OperationType): Resource {
    switch (type) {
      case OperationType.COPY: return $r('app.media.ic_copy');
      case OperationType.MOVE: return $r('app.media.ic_move');
      case OperationType.DELETE: return $r('app.media.ic_delete');
      case OperationType.DOWNLOAD: return $r('app.media.ic_download');
      case OperationType.UPLOAD: return $r('app.media.ic_upload');
      default: return $r('app.media.ic_file');
    }
  }

  private operationKindRes(kind: OperationItemKind): Resource {
    if (kind === OperationItemKind.FOLDER) return $r('app.media.ic_folder');
    return $r('app.media.ic_file');
  }

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  private onOperationsChanged = (ops: Operation[]): void => {
    this.operations = ops;
    this.vm.operations = ops;

    let all: number = 0;
    let pending: number = 0;
    let success: number = 0;
    let failed: number = 0;
    let anyCompleted: boolean = false;
    let anyFinished: boolean = false;

    for (let i = 0; i < ops.length; i++) {
      const s: OperationStatus = ops[i].status;
      all++;
      if (s === OperationStatus.QUEUED || s === OperationStatus.RUNNING) {
        pending++;
      } else if (s === OperationStatus.SUCCESS) {
        success++;
        anyCompleted = true;
        anyFinished = true;
      } else if (s === OperationStatus.FAILED
        || s === OperationStatus.CANCELLED) {
        failed++;
        anyFinished = true;
      }
    }

    this.tabAllCount = all;
    this.tabPendingCount = pending;
    this.tabSuccessCount = success;
    this.tabFailedCount = failed;
    this.hasAnyOps = ops.length > 0;
    this.canClearCompleted = anyCompleted;
    this.canClearAll = anyFinished;
    this.activeOpCount = pending;
    this.hasFinishedOps = anyFinished;

    this.tasksIconColor = this.computeTasksIconColor(
      pending, success, failed, all
    );
    this.tasksShowDot = all > 0;

    this.listVersion = this.listVersion + 1;
  };

  private onThemeChanged = (): void => {
    this.theme = ThemeManager.get().colors();
  };

  aboutToAppear(): void {
    this.vm.attachScroller(this.crumbScroller);
    this.vm.setContext(getContext(this) as common.UIAbilityContext);
    OperationTracker.get().subscribe(this.onOperationsChanged);
    ThemeManager.get().subscribe(this.onThemeChanged);
    this.vm.init();
    this.refreshStorageInfo();
  }

  aboutToDisappear(): void {
    OperationTracker.get().unsubscribe(this.onOperationsChanged);
    ThemeManager.get().unsubscribe(this.onThemeChanged);
  }

  onPageShow(): void {
    this.vm.onPageShow();
    this.refreshStorageInfo();
  }

  // ===========================================================================
  // Storage card
  // ===========================================================================

  private async refreshStorageInfo(): Promise<void> {
    const accountId: string = this.vm.activeAccountId;
    if (accountId.length === 0) {
      this.offlineBytes = 0;
      this.offlineCount = 0;
      this.cloudStorage = null;
      return;
    }

    try {
      const cache: CacheInfo =
        await OfflineStore.getCacheInfoForAccount(accountId);
      this.offlineBytes = cache.totalBytes;
      this.offlineCount = cache.fileCount;
    } catch (e) {
      const err: Error = e as Error;
      Logger.warn(TAG, `getCacheInfoForAccount failed: ${err.message}`);
      this.offlineBytes = 0;
      this.offlineCount = 0;
    }

    const account = this.vm.activeAccount;
    if (account === null) {
      this.cloudStorage = null;
      return;
    }

    this.cloudStorageLoading = true;
    try {
      const provider: ICloudProvider =
        CloudProviderFactory.getProvider(accountId, account.provider);
      this.cloudStorage = await provider.getStorageInfo();
    } catch (e) {
      const err: Error = e as Error;
      Logger.warn(TAG, `getStorageInfo failed: ${err.message}`);
      this.cloudStorage = null;
    } finally {
      this.cloudStorageLoading = false;
    }
  }

  private cloudStoragePercent(): number {
    if (this.cloudStorage === null) return 0;
    if (this.cloudStorage.isUnlimited) return 0;
    if (this.cloudStorage.total <= 0) return 0;
    const pct: number =
      (this.cloudStorage.used / this.cloudStorage.total) * 100;
    return pct > 100 ? 100 : pct;
  }

  private cloudStorageLabel(): string {
    if (this.cloudStorage === null) return '';
    if (this.cloudStorage.isUnlimited) {
      return t('fb.storageUnlimited');
    }
    return tNamed('fb.storageOf', new Map([
      ['used', FileBrowserViewModel.formatSize(this.cloudStorage.used)],
      ['total', FileBrowserViewModel.formatSize(this.cloudStorage.total)]
    ]));
  }

  private confirmClearOffline(): void {
    if (this.offlineCount === 0 || this.offlineClearing) return;
    const account = this.vm.activeAccount;
    const label: string = account !== null ? account.displayName : '';

    promptAction.showDialog({
      title: t('set.cache.confirm'),
      message: `${this.offlineCount} ${this.offlineCount === 1
        ? t('fb.item') : t('fb.items')} (${FileBrowserViewModel.formatSize(this.offlineBytes)}) — ${label}`,
      buttons: [
        { text: t('common.cancel'), color: '#666666' },
        { text: t('set.cache.clear'), color: '#D32F2F' }
      ]
    })
      .then((r: promptAction.ShowDialogSuccessResponse) => {
        if (r.index !== 1) return;
        this.performClearOffline();
      })
      .catch(() => { /* dismissed */ });
  }

  private async performClearOffline(): Promise<void> {
    const accountId: string = this.vm.activeAccountId;
    if (accountId.length === 0) return;

    this.offlineClearing = true;
    try {
      await OfflineStore.clearForAccount(accountId);
      await this.refreshStorageInfo();
      await this.vm.loadOfflineIdsPublic();
      promptAction.showToast({ message: t('set.cache.cleared') });
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `clearForAccount failed: ${err.message}`);
      promptAction.showToast({
        message: `${t('set.cache.failed')}: ${err.message}`
      });
    } finally {
      this.offlineClearing = false;
    }
  }

  // ===========================================================================
  // Selection counter animation
  // ===========================================================================

  private bounceSelectionCounter(): void {
    animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
      this.selectionScale = 1.15;
    });
    animateTo({ duration: 180, curve: Curve.EaseIn, delay: 120 }, () => {
      this.selectionScale = 1.0;
    });
  }

  private handleToggleSelection(itemId: string): void {
    this.vm.toggleSelection(itemId);
    this.bounceSelectionCounter();
  }

  private handleEnterSelectionMode(itemId: string): void {
    this.vm.enterSelectionMode(itemId);
    this.bounceSelectionCounter();
  }

  private handleSelectAll(): void {
    this.vm.selectAll();
    this.bounceSelectionCounter();
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  private async onPullToRefresh(): Promise<void> {
    const ok: boolean = await this.vm.refreshCurrentFolder();
    this.isRefreshing = false;
    if (!ok && this.vm.items.length > 0) {
      promptAction.showToast({ message: t('fb.couldNotRefresh') });
    }
  }

  private groupOpsByTab(tab: string): ActivityGroup[] {
    const filtered: Operation[] = [];
    for (let i = 0; i < this.operations.length; i++) {
      const op: Operation = this.operations[i];
      if (FileBrowserViewModel.operationMatchesTab(op, tab)) {
        filtered.push(op);
      }
    }

    const groups: ActivityGroup[] = [];
    let currentLabel: string = '';
    let currentList: Operation[] = [];

    for (let i = 0; i < filtered.length; i++) {
      const op: Operation = filtered[i];
      const label: string = FileBrowserViewModel.dateLabel(op.startedAt);
      if (label !== currentLabel) {
        if (currentList.length > 0) {
          groups.push({ dateLabel: currentLabel, operations: currentList });
        }
        currentLabel = label;
        currentList = [op];
      } else {
        currentList.push(op);
      }
    }
    if (currentList.length > 0) {
      groups.push({ dateLabel: currentLabel, operations: currentList });
    }
    return groups;
  }

  private currentTabCount(): number {
    if (this.vm.activityTab === ACTIVITY_TAB_ALL) return this.tabAllCount;
    if (this.vm.activityTab === ACTIVITY_TAB_PENDING) return this.tabPendingCount;
    if (this.vm.activityTab === ACTIVITY_TAB_SUCCESS) return this.tabSuccessCount;
    return this.tabFailedCount;
  }

  private computeTasksIconColor(
    pending: number,
    success: number,
    failed: number,
    all: number
  ): string {
    if (pending > 0) return this.theme.primary;
    if (all === 0) return this.theme.textTertiary;
    if (failed === 0 && success > 0) return this.theme.success;
    if (success === 0 && failed > 0) return this.theme.error;
    if (success > 0 && failed > 0) return this.theme.warning;
    return this.theme.textTertiary;
  }

  // ===========================================================================
  // Root build
  // ===========================================================================

  build() {
    Stack() {
      Column() {
        if (this.vm.isSelectionMode) {
          this.buildSelectionTopBar()
        } else {
          this.buildTopBar()
        }

        this.buildContent()

        if (this.vm.isSelectionMode) {
          this.buildSelectionActionBar()
        }
      }
      .width('100%')
      .height('100%')

      if (!this.vm.isSelectionMode && !this.vm.isSearchActive) {
        Column() {
          Blank()
          this.buildBottomBar()
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }

      if (this.vm.isSidebarOpen) {
        Row() {
          this.buildSidebar()
          Column()
            .layoutWeight(1)
            .height('100%')
            .backgroundColor(this.theme.overlay)
            .onClick(() => { this.vm.closeSidebar(); })
        }
        .width('100%')
        .height('100%')
      }

      if (this.vm.selectedItem !== null) {
        Column() {
          Column()
            .width('100%')
            .layoutWeight(1)
            .backgroundColor(this.theme.overlay)
            .onClick(() => { this.vm.closeActionsSheet(); })
          this.buildItemActionsSheet()
        }
        .width('100%')
        .height('100%')
      }

      if (this.vm.showRenameDialog) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.theme.overlay)
            .onClick(() => { this.vm.cancelRename(); })
          this.buildRenameDialog()
        }
        .width('100%')
        .height('100%')
      }

      if (this.vm.showMovePicker) {
        this.buildMovePicker()
      }

      if (this.vm.showCreateFolderDialog) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.theme.overlay)
            .onClick(() => { this.vm.cancelCreateFolder(); })
          this.buildCreateFolderDialog()
        }
        .width('100%')
        .height('100%')
      }

      if (this.vm.isActivityPanelOpen) {
        Column() {
          Column()
            .width('100%')
            .layoutWeight(1)
            .backgroundColor(this.theme.overlay)
            .onClick(() => { this.vm.closeActivityPanel(); })
          this.buildActivityPanel()
        }
        .width('100%')
        .height('100%')
      }

      if (this.vm.showUploadMenu) {
        Stack({ alignContent: Alignment.BottomEnd }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#33000000')
            .onClick(() => { this.vm.closeUploadMenu(); })
          this.buildUploadPopover()
        }
        .width('100%')
        .height('100%')
      }

      if (this.sortMenuOpen) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#33000000')
            .onClick(() => { this.sortMenuOpen = false; })
          this.buildSortMenu()
        }
        .width('100%')
        .height('100%')
      }

      if (this.vm.isSearchActive) {
        this.buildSearchOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.background)
  }

  // ===========================================================================
  // Top bar
  // ===========================================================================

  @Builder
  buildTopBar() {
    Column() {
      Row({ space: 10 }) {
        Row() {
          this.appIcon($r('app.media.ic_menu'), SIZE_TOPBAR_PRIMARY, this.theme.primary)
        }
        .width(40).height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.refreshStorageInfo();
          this.vm.openSidebar();
        })

        ProviderIcon({
          provider: this.vm.activeAccount !== null
            ? this.vm.activeAccount.provider
            : CloudProviderType.ONEDRIVE,
          iconSize: 34
        })

        Column({ space: 2 }) {
          Text(this.vm.activeAccount !== null
            ? this.vm.activeAccount.displayName
            : t('fb.files'))
            .fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.theme.textPrimary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Start).width('100%')

          if (this.vm.activeAccount !== null
            && this.vm.activeAccount.email !== undefined
            && this.vm.activeAccount.email.length > 0) {
            Text(this.vm.activeAccount.email)
              .fontSize(12).fontColor(this.theme.textSecondary)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Start).width('100%')
          } else {
            Text(FileBrowserViewModel.providerLabel(
              this.vm.activeAccount !== null
                ? this.vm.activeAccount.provider
                : CloudProviderType.ONEDRIVE
            ))
              .fontSize(12).fontColor(this.theme.textSecondary)
              .maxLines(1).textAlign(TextAlign.Start).width('100%')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row() {
          this.appIcon(
            this.vm.viewMode === 'list'
              ? $r('app.media.ic_grid')
              : $r('app.media.ic_list'),
            SIZE_TOPBAR_ACTION,
            this.theme.primary
          )
        }
        .width(40).height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.vm.toggleViewMode(); })

        Row() {
          this.appIcon($r('app.media.ic_sort'), SIZE_TOPBAR_ACTION, this.theme.primary)
        }
        .width(40).height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.sortMenuOpen = !this.sortMenuOpen; })

        this.buildActivityButton()

        if (this.vm.canGoBack()) {
          Row() {
            this.appIcon($r('app.media.ic_back'), SIZE_TOPBAR_ACTION, this.theme.primary)
          }
          .width(32).height(40)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.vm.goBack(); })
        }
      }
      .width('100%').alignItems(VerticalAlign.Center)

      if (this.vm.crumbs.length > 1) {
        Row() {
          Row().width(90)
          Scroll(this.crumbScroller) {
            Row({ space: 6 }) {
              ForEach(this.vm.crumbs, (crumb: Crumb, index: number) => {
                Row({ space: 6 }) {
                  Text(crumb.name)
                    .fontSize(12)
                    .fontWeight(index === this.vm.crumbs.length - 1
                      ? FontWeight.Medium : FontWeight.Normal)
                    .fontColor(index === this.vm.crumbs.length - 1
                      ? this.theme.textPrimary : this.theme.primary)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .textAlign(TextAlign.Start)
                    .onClick(() => { this.vm.goToCrumb(index); })
                  if (index < this.vm.crumbs.length - 1) {
                    this.appIcon($r('app.media.ic_chevron_right'),
                      SIZE_CRUMB_CHEVRON, this.theme.textTertiary)
                  }
                }
              }, (crumb: Crumb) => crumb.id)
            }
            .height(24)
          }
          .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
          .align(Alignment.Start).layoutWeight(1)
        }
        .width('100%').alignItems(VerticalAlign.Center).margin({ top: 4 })
      }
    }
    .width('100%').alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.theme.background)
    .border({ width: { bottom: 1 }, color: this.theme.divider })
  }

  @Builder
  buildActivityButton() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        this.appIcon($r('app.media.ic_tasks'),
          SIZE_TOPBAR_ACTION, this.tasksIconColor)
      }
      .width(40).height(40)
      .justifyContent(FlexAlign.Center)

      if (this.activeOpCount > 0) {
        Text(`${this.activeOpCount}`)
          .fontSize(10).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          .backgroundColor(this.theme.error).borderRadius(9)
          .padding({ left: 5, right: 5, top: 1, bottom: 1 })
          .constraintSize({ minWidth: 18, minHeight: 18 })
          .textAlign(TextAlign.Center)
      } else if (this.tasksShowDot) {
        Text(' ')
          .width(8).height(8).borderRadius(4)
          .backgroundColor(this.tasksIconColor)
          .margin({ top: 4, right: 6 })
      }
    }
    .width(40).height(40)
    .onClick(() => { this.vm.openActivityPanel(); })
  }

  // ===========================================================================
  // Sort menu
  // ===========================================================================

  @Builder
  buildSortMenu() {
    Column() {
      Text(t('fb.sortBy'))
        .fontSize(11).fontWeight(FontWeight.Medium)
        .fontColor(this.theme.textTertiary)
        .padding({ left: 16, right: 16, top: 14, bottom: 8 })
        .width('100%').textAlign(TextAlign.Start)

      ForEach(SORT_OPTIONS, (opt: SortOption) => {
        this.buildSortOption(opt)
      }, (opt: SortOption) => opt.key)
    }
    .width(240)
    .backgroundColor(this.theme.surface)
    .borderRadius(16)
    .shadow({ radius: 24, color: '#33000000', offsetX: 0, offsetY: 6 })
    .margin({ right: 16, top: 60 })
  }

  @Builder
  buildSortOption(opt: SortOption) {
    Row({ space: 12 }) {
      Text(t(opt.labelKey))
        .fontSize(14)
        .fontColor(this.vm.sortKey === opt.key
          ? this.theme.primary : this.theme.textPrimary)
        .fontWeight(this.vm.sortKey === opt.key
          ? FontWeight.Medium : FontWeight.Normal)
        .layoutWeight(1)

      if (this.vm.sortKey === opt.key) {
        this.appIcon($r('app.media.ic_check'), SIZE_SORT_CHECK, this.theme.primary)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.vm.setSortKey(opt.key);
      this.sortMenuOpen = false;
    })
  }

  // ===========================================================================
  // Selection bars
  // ===========================================================================

  @Builder
  buildSelectionTopBar() {
    Row({ space: 12 }) {
      Row() {
        this.appIcon($r('app.media.ic_close'), SIZE_SELECTION_CLOSE, this.theme.textPrimary)
      }
      .width(40).height(40)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.vm.exitSelectionMode(); })

      Text(tNamed('fb.selectedN',
        new Map([['n', `${this.vm.selectedCount()}`]])))
        .fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.theme.textPrimary)
        .layoutWeight(1)
        .scale({ x: this.selectionScale, y: this.selectionScale })

      if (this.vm.allSelected()) {
        Button(t('fb.deselectAll'))
          .fontSize(13).backgroundColor(Color.Transparent).fontColor(this.theme.primary)
          .onClick(() => { this.vm.deselectAll(); })
      } else {
        Button(t('fb.selectAll'))
          .fontSize(13).backgroundColor(Color.Transparent).fontColor(this.theme.primary)
          .onClick(() => { this.handleSelectAll(); })
      }
    }
    .width('100%')
    .padding({ left: 8, right: 12, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.theme.background)
    .border({ width: { bottom: 1 }, color: this.theme.divider })
    .transition(TransitionEffect.OPACITY.animation({ duration: 150 }))
  }

  @Builder
  buildSelectionActionBar() {
    Row() {
      this.buildSelectionAction($r('app.media.ic_copy'), t('fb.copy'), (): void => {
        this.vm.onBatchCopy();
      })
      this.buildSelectionAction($r('app.media.ic_move'), t('fb.move'), (): void => {
        this.vm.onBatchMove();
      })
      this.buildSelectionAction($r('app.media.ic_download'), t('fb.download'), (): void => {
        this.vm.onBatchDownload();
      })
      this.buildSelectionAction($r('app.media.ic_delete'), t('fb.delete'), (): void => {
        this.vm.onBatchDelete();
      })
    }
    .width('100%')
    .padding({ top: 10, bottom: 16 })
    .backgroundColor(this.theme.background)
    .border({ width: { top: 1 }, color: this.theme.divider })
    .transition(TransitionEffect.OPACITY.animation({ duration: 150 }))
  }

  @Builder
  buildSelectionAction(iconRes: Resource, label: string, action: () => void) {
    Column({ space: 6 }) {
      this.appIcon(iconRes, SIZE_SELECTION_ACTION, this.theme.primary)
      Text(label).fontSize(12).fontColor(this.theme.primary)
    }
    .layoutWeight(1).alignItems(HorizontalAlign.Center)
    .onClick(action)
  }

  // ===========================================================================
  // Bottom bar
  // ===========================================================================

  @Builder
  buildBottomBar() {
    Row({ space: 12 }) {
      Row({ space: 10 }) {
        this.appIcon($r('app.media.ic_search'), SIZE_BOTTOM_SEARCH, this.theme.primary)
        Text(t('fb.search'))
          .fontSize(14).fontColor(this.theme.textPrimary).layoutWeight(1)
      }
      .layoutWeight(1).height(52)
      .padding({ left: 20, right: 20 })
      .backgroundColor(this.theme.isDark ? '#1AFFFFFF' : '#1A000000')
      .backgroundEffect({
        radius: 40,
        saturation: 1.8,
        brightness: 1.05,
        color: '#00000000'
      })
      .borderRadius(26)
      .border({
        width: 0.5,
        color: this.theme.isDark ? '#33FFFFFF' : '#33000000'
      })
      .clip(true)
      .shadow({
        radius: 10,
        color: this.theme.isDark ? '#33000000' : '#12000000',
        offsetX: 0, offsetY: 4
      })
      .alignItems(VerticalAlign.Center)
      .onClick(() => { this.vm.openSearch(); })

      Row() {
        this.appIcon($r('app.media.ic_add'), SIZE_BOTTOM_ADD, '#FFFFFF')
      }
      .width(60).height(60).borderRadius(30)
      .backgroundColor(this.theme.primary)
      .justifyContent(FlexAlign.Center)
      .border({
        width: 0.5,
        color: this.theme.isDark ? '#33FFFFFF' : '#22FFFFFF'
      })
      .clip(true)
      .shadow({
        radius: 8,
        color: this.theme.isDark ? '#40000000' : '#260A5BD3',
        offsetX: 0, offsetY: 5
      })
      .onClick(() => { this.vm.openUploadMenu(); })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 24, top: 8 })
    .alignItems(VerticalAlign.Center)
  }

  // ===========================================================================
  // Upload popover
  // ===========================================================================

  @Builder
  buildUploadPopover() {
    Column() {
      Row({ space: 14 }) {
        this.appIcon($r('app.media.ic_create_folder'),
          SIZE_UPLOAD_MENU_ICON, this.theme.primary)
        Text(t('fb.newFolder'))
          .fontSize(16).fontColor(this.theme.textPrimary).layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 18 })
      .onClick(() => { this.vm.openNewFolderPrompt(); })

      Row({ space: 14 }) {
        this.appIcon($r('app.media.ic_upload'),
          SIZE_UPLOAD_MENU_ICON, this.theme.primary)
        Text(t('fb.uploadFile'))
          .fontSize(16).fontColor(this.theme.textPrimary).layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 18 })
      .onClick(() => { this.vm.onUploadFile(); })

      if (this.vm.isUploadFolderEnabled()) {
        Row({ space: 14 }) {
          this.appIcon($r('app.media.ic_upload_folder'),
            SIZE_UPLOAD_MENU_ICON, this.theme.primary)
          Text(t('fb.uploadFolder'))
            .fontSize(16).fontColor(this.theme.textPrimary).layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 18, bottom: 18 })
        .onClick(() => { this.vm.onUploadFolder(); })
      }
    }
    .width(240)
    .backgroundColor(this.theme.surface)
    .borderRadius(18)
    .shadow({ radius: 24, color: '#33000000', offsetX: 0, offsetY: 6 })
    .margin({ right: 16, bottom: 100 })
  }

  // ===========================================================================
  // Search overlay
  // ===========================================================================

  @Builder
  buildSearchOverlay() {
    Column() {
      Row({ space: 8 }) {
        Row() {
          this.appIcon($r('app.media.ic_back'), SIZE_SEARCH_BACK, this.theme.textPrimary)
        }
        .width(40).height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.vm.closeSearch(); })

        TextInput({
          text: this.vm.searchQuery,
          placeholder: t('fb.searchPlaceholder')
        })
          .fontSize(15)
          .fontColor(this.theme.textPrimary)
          .placeholderColor(this.theme.textTertiary)
          .layoutWeight(1)
          .backgroundColor(this.theme.chipBg)
          .borderRadius(22)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onChange((value: string) => { this.vm.setSearchQuery(value); })
      }
      .width('100%')
      .padding({ left: 8, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.theme.surface)
      .alignItems(VerticalAlign.Center)

      Divider().color(this.theme.divider)

      if (this.vm.isSearching) {
        Column({ space: 12 }) {
          LoadingProgress().width(36).height(36).color(this.theme.primary)
          Text(t('fb.searching')).fontSize(13).fontColor(this.theme.textSecondary)
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else if (this.vm.searchError.length > 0) {
        Column({ space: 10 }) {
          this.appIcon($r('app.media.ic_error'), SIZE_SEARCH_EMPTY, this.theme.textTertiary)
          Text(t('fb.searchFailed'))
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
          Text(this.vm.searchError)
            .fontSize(13).fontColor(this.theme.textSecondary)
            .textAlign(TextAlign.Center).padding({ left: 32, right: 32 })
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else if (this.vm.searchQuery.trim().length === 0) {
        Column({ space: 10 }) {
          this.appIcon($r('app.media.ic_search'), SIZE_SEARCH_EMPTY, this.theme.textTertiary)
          Text(t('fb.startTyping'))
            .fontSize(14).fontColor(this.theme.textSecondary)
          Text(t('fb.searchDesc'))
            .fontSize(12).fontColor(this.theme.textTertiary)
            .textAlign(TextAlign.Center).padding({ left: 32, right: 32 })
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else if (this.vm.searchResults.length === 0) {
        Column({ space: 10 }) {
          this.appIcon($r('app.media.ic_folder'), SIZE_SEARCH_EMPTY, this.theme.textTertiary)
          Text(t('fb.noSearchResults'))
            .fontSize(14).fontColor(this.theme.textSecondary)
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else {
        List({ space: 1 }) {
          ForEach(this.vm.searchResults, (item: CloudItem) => {
            ListItem() { this.buildSearchResultRow(item) }
          }, (item: CloudItem) => item.id)
        }
        .layoutWeight(1).width('100%')
        .divider({ strokeWidth: 1, color: this.theme.divider })
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.theme.background)
  }

  @Builder
  buildSearchResultRow(item: CloudItem) {
    Row({ space: 14 }) {
      if (item.type === CloudItemType.FOLDER) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(48).height(48)
            .borderRadius(12)
            .backgroundColor(this.theme.primarySoft)
          this.appIcon($r('app.media.ic_folder'), 28, this.theme.primary)
        }
        .width(48).height(48)
      } else if (item.thumbnailUrl !== undefined
        && item.thumbnailUrl.length > 0) {
        Image(item.thumbnailUrl)
          .width(48).height(48)
          .borderRadius(12)
          .objectFit(ImageFit.Cover)
          .draggable(false)
      } else {
        FileIcon({
          fileName: item.name,
          mimeType: item.mimeType !== undefined ? item.mimeType : '',
          badgeSize: 48
        })
      }

      Column({ space: 2 }) {
        Text(item.name)
          .fontSize(15).fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })

        if (item.type === CloudItemType.FILE && item.size !== undefined) {
          Text(FileBrowserViewModel.formatSize(item.size))
            .fontSize(12).fontColor(this.theme.textSecondary)
        } else {
          Text(t('fb.folder')).fontSize(12).fontColor(this.theme.textSecondary)
        }
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)

      if (item.isShared === true) {
        Row() {
          this.appIcon($r('app.media.ic_shared'), SIZE_ROW_BADGE, this.theme.textSecondary)
        }
        .margin({ right: 4 })
      }

      if (item.type === CloudItemType.FILE
        && this.vm.isDownloading(item.id)) {
        LoadingProgress().width(22).height(22).color(this.theme.primary)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.theme.surface)
    .onClick(() => { this.vm.onSearchResultTap(item); })
  }

  // ===========================================================================
  // Content
  // ===========================================================================

  @Builder
  buildContent() {
    if (this.vm.isLoading) {
      Column({ space: 12 }) {
        LoadingProgress().width(36).height(36).color(this.theme.primary)
        Text(t('fb.loading')).fontSize(13).fontColor(this.theme.textSecondary)
      }
      .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
    } else if (this.vm.errorMessage.length > 0) {
      Column({ space: 12 }) {
        Text(t('fb.somethingWrong'))
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
        Text(this.vm.errorMessage)
          .fontSize(13).fontColor(this.theme.textSecondary)
          .textAlign(TextAlign.Center)
        Button(t('common.retry')).onClick(() => {
          this.vm.loadFolder(this.vm.currentFolderId);
        })
      }
      .layoutWeight(1).justifyContent(FlexAlign.Center).padding(24).width('100%')
    } else if (this.vm.items.length === 0) {
      this.buildEmptyStateWithRefresh()
    } else {
      Column() {
        this.buildFilterChips()
        Divider().color(this.theme.divider).margin({ left: 16, right: 16 })

        if (this.vm.filteredItems().length === 0) {
          this.buildNoFilterMatches()
        } else if (this.vm.viewMode === 'grid') {
          this.buildGridWithRefresh()
        } else {
          this.buildListWithRefresh()
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
  }

  @Builder
  buildNoFilterMatches() {
    Column({ space: 12 }) {
      this.appIcon($r('app.media.ic_search'), SIZE_SEARCH_EMPTY, this.theme.textTertiary)
      Text(t('fb.noFilterMatches'))
        .fontSize(14).fontColor(this.theme.textSecondary)
        .textAlign(TextAlign.Center)
      Button(t('fb.showAll'))
        .fontSize(13)
        .height(40)
        .padding({ left: 22, right: 22 })
        .backgroundColor(this.theme.chipBg)
        .fontColor(this.theme.textPrimary)
        .onClick(() => { this.vm.clearFilter(); })
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: 80 })
  }

  @Builder
  buildListWithRefresh() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      List({ space: 1 }) {
        ForEach(this.vm.filteredItems(), (item: CloudItem) => {
          ListItem() { this.buildItemRow(item) }
        }, (item: CloudItem) => item.id)

        ListItem() { Row().height(100) }
      }
      .width('100%')
      .height('100%')
      .divider({ strokeWidth: 1, color: this.theme.divider, startMargin: ROW_DIVIDER_START })
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
    }
    .onRefreshing(() => { this.onPullToRefresh(); })
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  buildGridWithRefresh() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      Grid() {
        ForEach(this.vm.filteredItems(), (item: CloudItem) => {
          GridItem() { this.buildGridTile(item) }
        }, (item: CloudItem) => item.id)

        GridItem() { Row().height(100) }
        .columnStart(0).columnEnd(2)
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(10)
      .rowsGap(14)
      .padding({ left: 14, right: 14, top: 12 })
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
    }
    .onRefreshing(() => { this.onPullToRefresh(); })
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  buildGridTile(item: CloudItem) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (item.type === CloudItemType.FOLDER) {
          Column()
            .width('100%').aspectRatio(1)
            .borderRadius(14)
            .backgroundColor(this.theme.primarySoft)
          this.appIcon($r('app.media.ic_folder'), 44, this.theme.primary)
        } else if (item.thumbnailUrl !== undefined
          && item.thumbnailUrl.length > 0) {
          Image(item.thumbnailUrl)
            .width('100%').aspectRatio(1)
            .borderRadius(14)
            .objectFit(ImageFit.Cover)
            .draggable(false)
        } else {
          Column()
            .width('100%').aspectRatio(1)
            .borderRadius(14)
            .backgroundColor(this.theme.chipBg)
          FileIcon({
            fileName: item.name,
            mimeType: item.mimeType !== undefined ? item.mimeType : '',
            badgeSize: SIZE_GRID_FILEICON
          })
        }

        if (item.type === CloudItemType.FILE
          && this.vm.isDownloading(item.id)) {
          Column()
            .width('100%').aspectRatio(1)
            .borderRadius(14)
            .backgroundColor(this.theme.overlay)
          LoadingProgress().width(32).height(32).color('#FFFFFF')
        }

        if (this.vm.isSelectionMode) {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(28).height(28).borderRadius(14)
              .backgroundColor(this.vm.isSelected(item.id)
                ? this.theme.primary
                : 'rgba(0,0,0,0.4)')
            if (this.vm.isSelected(item.id)) {
              this.appIcon($r('app.media.ic_check'), 16, '#FFFFFF')
            }
          }
          .width(28).height(28)
          .position({ x: 6, y: 6 })
        }

        if (!this.vm.isSelectionMode && item.isShared === true) {
          Column() {
            this.appIcon($r('app.media.ic_shared'),
              SIZE_GRID_BADGE_ICON, '#FFFFFF')
          }
          .width(SIZE_GRID_BADGE_BOX).height(SIZE_GRID_BADGE_BOX)
          .borderRadius(SIZE_GRID_BADGE_BOX / 2)
          .backgroundColor(this.theme.textSecondary)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .position({ x: 6, y: 6 })
        }

        if (!this.vm.isSelectionMode
          && item.type === CloudItemType.FILE
          && this.vm.isOffline(item.id)) {
          Column() {
            this.appIcon($r('app.media.ic_cloud_offline'),
              SIZE_GRID_BADGE_ICON, '#FFFFFF')
          }
          .width(SIZE_GRID_BADGE_BOX).height(SIZE_GRID_BADGE_BOX)
          .borderRadius(SIZE_GRID_BADGE_BOX / 2)
          .backgroundColor(this.theme.primary)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .position({
            x: 6,
            y: item.isShared === true ? 38 : 6
          })
        }
      }
      .width('100%')

      Text(item.name)
        .fontSize(12)
        .fontColor(this.theme.textPrimary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .onClick(() => {
      if (this.vm.isSelectionMode) {
        this.handleToggleSelection(item.id);
      } else if (item.type === CloudItemType.FOLDER) {
        this.vm.openFolder(item);
      } else {
        this.vm.openFile(item);
      }
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction(() => {
          if (!this.vm.isSelectionMode) {
            this.handleEnterSelectionMode(item.id);
          }
        })
    )
  }

  @Builder
  buildFilterChips() {
    Scroll() {
      Row({ space: 8 }) {
        this.buildFilterChip('all',      $r('app.media.ic_filter_all'),    t('fb.filter.all'))
        this.buildFilterChip('image',    $r('app.media.ic_filter_image'),  t('fb.filter.images'))
        this.buildFilterChip('video',    $r('app.media.ic_filter_video'),  t('fb.filter.videos'))
        this.buildFilterChip('document', $r('app.media.ic_filter_doc'),    t('fb.filter.docs'))
        this.buildFilterChip('audio',    $r('app.media.ic_filter_audio'),  t('fb.filter.audio'))
        this.buildFilterChip('other',    $r('app.media.ic_filter_other'),  t('fb.filter.other'))
      }
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .backgroundColor(this.theme.background)
  }

  @Builder
  buildFilterChip(key: string, iconRes: Resource, label: string) {
    Row({ space: 6 }) {
      this.appIcon(iconRes, SIZE_FILTER_CHIP,
        this.vm.activeFilter === key
          ? this.theme.primary : this.theme.textSecondary)
      Text(label)
        .fontSize(12)
        .fontWeight(this.vm.activeFilter === key
          ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.vm.activeFilter === key
          ? this.theme.primary : this.theme.textSecondary)
    }
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .backgroundColor(this.vm.activeFilter === key
      ? this.theme.chipSelectedBg : this.theme.chipBg)
    .borderRadius(18)
    .border({
      width: this.vm.activeFilter === key ? 1 : 0,
      color: this.theme.primary
    })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.vm.setFilter(key); })
  }

  @Builder
  buildEmptyStateWithRefresh() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column({ space: 18 }) {
          Stack({ alignContent: Alignment.BottomStart }) {
            Column()
              .width(160).height(120)
              .borderRadius(20)
              .backgroundColor(this.theme.chipBg)

            Column()
              .width(64).height(16)
              .backgroundColor(this.theme.chipSelectedBg)
              .borderRadius({ topLeft: 10, topRight: 6 })
              .position({ x: 0, y: 0 })

            Column() {
              this.appIcon($r('app.media.ic_folder'),
                SIZE_EMPTY_ILLUSTRATION, this.theme.primary)
            }
            .position({ x: 48, y: 34 })
          }
          .width(160)
          .height(120)

          Column({ space: 8 }) {
            Text(t('fb.emptyFolder'))
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)
              .textAlign(TextAlign.Center)

            Text(t('fb.emptyFolderHint'))
              .fontSize(13)
              .fontColor(this.theme.textSecondary)
              .textAlign(TextAlign.Center)
              .padding({ left: 40, right: 40 })
          }

          Row({ space: 10 }) {
            Button(t('fb.uploadFile'))
              .fontSize(13)
              .height(44)
              .padding({ left: 22, right: 22 })
              .backgroundColor(this.theme.primary)
              .fontColor(this.theme.primaryContrast)
              .onClick(() => { this.vm.onUploadFile(); })

            Button(t('fb.newFolder'))
              .fontSize(13)
              .height(44)
              .padding({ left: 22, right: 22 })
              .backgroundColor(this.theme.chipBg)
              .fontColor(this.theme.textPrimary)
              .onClick(() => { this.vm.openNewFolderPrompt(); })
          }
          .margin({ top: 4 })
        }
        .width('100%')
        .padding({ top: 80, bottom: 80 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .onRefreshing(() => { this.onPullToRefresh(); })
    .layoutWeight(1)
    .width('100%')
  }

  // ===========================================================================
  // Item row
  // ===========================================================================

  @Builder
  buildItemRow(item: CloudItem) {
    Row({ space: 14 }) {
      if (this.vm.isSelectionMode) {
        Text(this.vm.isSelected(item.id) ? '☑' : '☐')
          .fontSize(24)
          .fontColor(this.vm.isSelected(item.id)
            ? this.theme.primary : this.theme.textTertiary)
          .width(28).textAlign(TextAlign.Center)
      }

      if (item.type === CloudItemType.FOLDER) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(SIZE_ROW_VISUAL).height(SIZE_ROW_VISUAL)
            .borderRadius(14)
            .backgroundColor(this.theme.primarySoft)
          this.appIcon($r('app.media.ic_folder'),
            SIZE_ROW_FOLDER_ICON, this.theme.primary)
        }
        .width(SIZE_ROW_VISUAL).height(SIZE_ROW_VISUAL)
      } else if (item.thumbnailUrl !== undefined
        && item.thumbnailUrl.length > 0) {
        Image(item.thumbnailUrl)
          .width(SIZE_ROW_VISUAL).height(SIZE_ROW_VISUAL)
          .borderRadius(14)
          .objectFit(ImageFit.Cover)
          .draggable(false)
      } else {
        FileIcon({
          fileName: item.name,
          mimeType: item.mimeType !== undefined ? item.mimeType : '',
          badgeSize: SIZE_ROW_VISUAL
        })
      }

      Column({ space: 4 }) {
        Text(item.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 6 }) {
          if (item.type === CloudItemType.FILE && item.size !== undefined) {
            Text(FileBrowserViewModel.formatSize(item.size))
              .fontSize(12).fontColor(this.theme.textSecondary)
          } else if (item.type === CloudItemType.FOLDER
            && item.childCount !== undefined) {
            Text(item.childCount === 1
              ? `1 ${t('fb.item')}`
              : `${item.childCount} ${t('fb.items')}`)
              .fontSize(12).fontColor(this.theme.textSecondary)
          }

          if (item.modifiedAt > 0
            && (item.type === CloudItemType.FILE
              || (item.childCount !== undefined && item.childCount > 0))) {
            Text('·').fontSize(12).fontColor(this.theme.textTertiary)
          }

          if (item.modifiedAt > 0) {
            Text(FileBrowserViewModel.relativeDate(item.modifiedAt))
              .fontSize(12).fontColor(this.theme.textSecondary)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (!this.vm.isSelectionMode) {
        if (item.isShared === true) {
          Row() {
            this.appIcon($r('app.media.ic_shared'),
              SIZE_ROW_BADGE, this.theme.textSecondary)
          }
          .margin({ right: 6 })
        }

        if (item.type === CloudItemType.FILE && this.vm.isOffline(item.id)) {
          Row() {
            this.appIcon($r('app.media.ic_cloud_offline'),
              SIZE_ROW_BADGE, this.theme.primary)
          }
          .margin({ right: 4 })
        }
      }

      if (!this.vm.isSelectionMode) {
        if (item.type === CloudItemType.FILE
          && this.vm.isDownloading(item.id)) {
          LoadingProgress().width(24).height(24).color(this.theme.primary)
            .margin({ left: 8, right: 12 })
        } else {
          Row() {
            this.appIcon($r('app.media.ic_more'),
              SIZE_ROW_MORE, this.theme.textSecondary)
          }
          .width(44).height(44)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.vm.onShowItemActions(item); })
        }
      }
    }
    .width('100%')
    .padding({
      left: this.vm.isSelectionMode ? 8 : 16,
      right: 8,
      top: 14, bottom: 14
    })
    .backgroundColor(
      this.vm.isSelectionMode && this.vm.isSelected(item.id)
        ? this.theme.chipSelectedBg : this.theme.surface
    )
    .onClick(() => {
      if (this.vm.isSelectionMode) {
        this.handleToggleSelection(item.id);
      } else if (item.type === CloudItemType.FOLDER) {
        this.vm.openFolder(item);
      } else {
        this.vm.openFile(item);
      }
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction(() => {
          if (!this.vm.isSelectionMode) {
            this.handleEnterSelectionMode(item.id);
          }
        })
    )
  }

  // ===========================================================================
  // Item actions sheet
  // ===========================================================================

  @Builder
  buildItemActionsSheet() {
    Column() {
      Row()
        .width(40).height(4).borderRadius(2).backgroundColor(this.theme.border)
        .margin({ top: 8, bottom: 16 })

      this.buildSheetHeader()
      this.buildDeleteButton()

      Column() {
        if (this.vm.selectedItem !== null
          && this.vm.selectedItem.type === CloudItemType.FILE) {
          this.buildOpenRow()
        }
        this.buildDownloadRow()
        this.buildOfflineRow()
        this.buildRenameRow()
        this.buildMoveRow()
        this.buildCopyRow()
        this.buildDetailsRow()
      }
      .width('100%').margin({ top: 8 })

      Row().height(24)
    }
    .width('100%')
    .backgroundColor(this.theme.surface)
    .borderRadius({ topLeft: 20, topRight: 20 })
    .shadow({ radius: 20, color: '#22000000', offsetX: 0, offsetY: -4 })
  }

  @Builder
  buildSheetHeader() {
    Column({ space: 8 }) {
      if (this.vm.selectedItem !== null
        && this.vm.selectedItem.type === CloudItemType.FOLDER) {
        Column() {
          this.appIcon($r('app.media.ic_folder'),
            SIZE_SHEET_HEADER_FOLDER_ICON, this.theme.primary)
        }
        .width(SIZE_SHEET_HEADER_FOLDER_BOX)
        .height(SIZE_SHEET_HEADER_FOLDER_BOX)
        .borderRadius(16)
        .backgroundColor(this.theme.primarySoft)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.vm.selectedItem !== null) {
        FileIcon({
          fileName: this.vm.selectedItem.name,
          mimeType: this.vm.selectedItem.mimeType !== undefined
            ? this.vm.selectedItem.mimeType : '',
          badgeSize: SIZE_SHEET_HEADER_FOLDER_BOX, rounded: true
        })
      }

      Text(this.vm.selectedItem !== null ? this.vm.selectedItem.name : '')
        .fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.theme.textPrimary)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 24, right: 24 })

      if (this.vm.selectedItem !== null
        && this.vm.selectedItem.type === CloudItemType.FILE
        && this.vm.selectedItem.size !== undefined) {
        Text(`${FileBrowserViewModel.formatSize(this.vm.selectedItem.size)} · ${FileBrowserViewModel.formatDate(this.vm.selectedItem.modifiedAt)}`)
          .fontSize(13).fontColor(this.theme.textSecondary)
      } else if (this.vm.selectedItem !== null) {
        Text(`${t('fb.folder')} · ${FileBrowserViewModel.formatDate(this.vm.selectedItem.modifiedAt)}`)
          .fontSize(13).fontColor(this.theme.textSecondary)
      }
    }
    .width('100%').alignItems(HorizontalAlign.Center)
    .padding({ top: 8, bottom: 20 })
  }

  @Builder
  buildDeleteButton() {
    Row() {
      Column({ space: 6 }) {
        this.appIcon($r('app.media.ic_delete'),
          SIZE_SHEET_DELETE_ICON, this.theme.error)
        Text(t('fb.delete')).fontSize(14).fontColor(this.theme.error)
      }
      .width('100%').padding({ top: 20, bottom: 20 })
      .backgroundColor(this.theme.surfaceSubtle).borderRadius(12)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    }
    .width('100%').padding({ left: 16, right: 16 })
    .onClick(() => { this.vm.onDeleteItem(); })
  }

  @Builder
  buildOpenRow() {
    Row({ space: 16 }) {
      this.appIcon($r('app.media.ic_open'), SIZE_SHEET_ROW_ICON, this.theme.textSecondary)
      Text(t('fb.open')).fontSize(16).fontColor(this.theme.textPrimary).layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
    .onClick(() => {
      if (this.vm.selectedItem !== null) {
        const item = this.vm.selectedItem;
        this.vm.closeActionsSheet();
        this.vm.openFile(item);
      }
    })
  }

  @Builder
  buildDownloadRow() {
    Row({ space: 16 }) {
      if (this.vm.selectedItem !== null
        && this.vm.isDownloading(this.vm.selectedItem.id)) {
        LoadingProgress().width(SIZE_SHEET_ROW_ICON).height(SIZE_SHEET_ROW_ICON)
          .color(this.theme.primary)
      } else {
        this.appIcon($r('app.media.ic_download'),
          SIZE_SHEET_ROW_ICON, this.theme.textSecondary)
      }
      Text(this.vm.selectedItem !== null
        && this.vm.isDownloading(this.vm.selectedItem.id)
        ? t('fb.downloading') : t('fb.download'))
        .fontSize(16)
        .fontColor(this.vm.canDownloadSelected()
          ? this.theme.textPrimary : this.theme.textTertiary)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
    .onClick(() => { this.vm.onDownloadItem(); })
  }

  @Builder
  buildOfflineRow() {
    Row({ space: 16 }) {
      this.appIcon($r('app.media.ic_cloud_offline'),
        SIZE_SHEET_ROW_ICON, this.theme.textSecondary)
      Text(t('fb.makeOffline')).fontSize(16).fontColor(this.theme.textPrimary)
        .layoutWeight(1)

      Toggle({
        type: ToggleType.Switch,
        isOn: this.vm.selectedItem !== null
          && this.vm.isOffline(this.vm.selectedItem.id)
      })
        .selectedColor(this.theme.primary)
        .onChange((isOn: boolean) => {
          if (this.vm.selectedItem === null) return;
          const currentlyOffline: boolean =
            this.vm.isOffline(this.vm.selectedItem.id);
          if (isOn === currentlyOffline) return;
          this.vm.onToggleOffline(isOn);
        })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
  }

  @Builder
  buildRenameRow() {
    Row({ space: 16 }) {
      this.appIcon($r('app.media.ic_edit'), SIZE_SHEET_ROW_ICON, this.theme.textSecondary)
      Text(t('fb.rename')).fontSize(16).fontColor(this.theme.textPrimary).layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
    .onClick(() => { this.vm.onRenameItem(); })
  }

  @Builder
  buildMoveRow() {
    Row({ space: 16 }) {
      this.appIcon($r('app.media.ic_move'), SIZE_SHEET_ROW_ICON, this.theme.textSecondary)
      Text(t('fb.move')).fontSize(16).fontColor(this.theme.textPrimary).layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
    .onClick(() => { this.vm.onMoveItem(); })
  }

  @Builder
  buildCopyRow() {
    Row({ space: 16 }) {
      this.appIcon($r('app.media.ic_copy'), SIZE_SHEET_ROW_ICON, this.theme.textSecondary)
      Text(t('fb.copy')).fontSize(16).fontColor(this.theme.textPrimary).layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
    .onClick(() => { this.vm.onCopyItem(); })
  }

  @Builder
  buildDetailsRow() {
    Row({ space: 16 }) {
      this.appIcon($r('app.media.ic_info'), SIZE_SHEET_ROW_ICON, this.theme.textSecondary)
      Text(t('fb.details')).fontSize(16).fontColor(this.theme.textPrimary).layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
    .onClick(() => { this.vm.onShowDetails(); })
  }

  // ===========================================================================
  // Rename dialog
  // ===========================================================================

  @Builder
  buildRenameDialog() {
    Column({ space: 16 }) {
      Text(t('fb.renameTitle'))
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
        .width('100%').textAlign(TextAlign.Start)

      TextInput({ text: this.vm.renameText, placeholder: t('fb.renamePlaceholder') })
        .fontSize(15)
        .fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textTertiary)
        .backgroundColor(this.theme.chipBg)
        .onChange((value: string) => { this.vm.renameText = value; })

      Row({ space: 12 }) {
        Button(t('common.cancel'))
          .layoutWeight(1)
          .backgroundColor(this.theme.chipBg)
          .fontColor(this.theme.textPrimary)
          .onClick(() => { this.vm.cancelRename(); })

        Button(this.vm.isProcessing ? t('fb.renaming') : t('fb.rename'))
          .layoutWeight(1)
          .backgroundColor(this.theme.primary)
          .fontColor(this.theme.primaryContrast)
          .enabled(!this.vm.isProcessing)
          .onClick(() => { this.vm.performRename(); })
      }
      .width('100%')
    }
    .width('85%').padding(20)
    .backgroundColor(this.theme.surface).borderRadius(16)
  }

  // ===========================================================================
  // Move / Copy picker
  // ===========================================================================

  @Builder
  buildMovePicker() {
    Column() {
      Row({ space: 12 }) {
        Row() {
          this.appIcon($r('app.media.ic_back'), 26, this.theme.textPrimary)
        }
        .width(36).height(36)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.vm.closeMovePicker(); })

        Text(this.vm.pickerTitle())
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.theme.textPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Start).layoutWeight(1)

        Button(t('fb.newFolder'))
          .fontSize(13)
          .backgroundColor(this.theme.primarySoft)
          .fontColor(this.theme.primary)
          .onClick(() => { this.vm.openCreateFolderPrompt(); })
      }
      .width('100%')
      .padding({ left: 8, right: 16, top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.theme.surface)

      Row() {
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.vm.movePickerCrumbs, (crumb: Crumb, index: number) => {
              Row({ space: 6 }) {
                Text(crumb.name)
                  .fontSize(12)
                  .fontWeight(index === this.vm.movePickerCrumbs.length - 1
                    ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(index === this.vm.movePickerCrumbs.length - 1
                    ? this.theme.textPrimary : this.theme.primary)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .textAlign(TextAlign.Start)
                  .onClick(() => { this.vm.movePickerGoToCrumb(index); })
                if (index < this.vm.movePickerCrumbs.length - 1) {
                  this.appIcon($r('app.media.ic_chevron_right'),
                    SIZE_CRUMB_CHEVRON, this.theme.textTertiary)
                }
              }
            }, (crumb: Crumb) => crumb.id)
          }
          .height(24).padding({ left: 16, right: 16 })
        }
        .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        .align(Alignment.Start).width('100%')
      }
      .width('100%').padding({ top: 10, bottom: 10 })
      .backgroundColor(this.theme.surface)

      Divider().color(this.theme.divider)

      if (this.vm.movePickerLoading) {
        Column({ space: 12 }) {
          LoadingProgress().width(32).height(32).color(this.theme.primary)
          Text(t('fb.loadingFolders'))
            .fontSize(13).fontColor(this.theme.textSecondary)
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else if (this.vm.movePickerError.length > 0) {
        Column({ space: 12 }) {
          Text(t('fb.couldNotLoadFolders'))
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
          Text(this.vm.movePickerError)
            .fontSize(13).fontColor(this.theme.textSecondary)
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).padding(24).width('100%')
      } else if (this.vm.movePickerItems.length === 0) {
        Column({ space: 10 }) {
          this.appIcon($r('app.media.ic_folder'), 44, this.theme.textTertiary)
          Text(t('fb.noSubfolders'))
            .fontSize(14).fontColor(this.theme.textSecondary)
          Text(t('fb.noSubfoldersHint'))
            .fontSize(12).fontColor(this.theme.textTertiary)
            .textAlign(TextAlign.Center).padding({ left: 32, right: 32 })
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else {
        List({ space: 1 }) {
          ForEach(this.vm.movePickerItems, (folder: CloudItem) => {
            ListItem() {
              Row({ space: 14 }) {
                Stack({ alignContent: Alignment.Center }) {
                  Column()
                    .width(40).height(40)
                    .borderRadius(10)
                    .backgroundColor(this.theme.primarySoft)
                  this.appIcon($r('app.media.ic_folder'), 22, this.theme.primary)
                }
                .width(40).height(40)

                Text(folder.name)
                  .fontSize(15).fontColor(this.theme.textPrimary)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)

                this.appIcon($r('app.media.ic_chevron_right'),
                  18, this.theme.textTertiary)
              }
              .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .alignItems(VerticalAlign.Center)
              .backgroundColor(this.theme.surface)
              .onClick(() => { this.vm.movePickerOpenFolder(folder); })
            }
          }, (folder: CloudItem) => folder.id)
        }
        .layoutWeight(1).width('100%')
        .divider({ strokeWidth: 1, color: this.theme.divider })
      }

      Divider().color(this.theme.divider)
      Row({ space: 12 }) {
        Button(t('common.cancel'))
          .layoutWeight(1)
          .backgroundColor(this.theme.chipBg)
          .fontColor(this.theme.textPrimary)
          .onClick(() => { this.vm.closeMovePicker(); })

        Button(this.vm.pickerConfirmLabel())
          .layoutWeight(1)
          .backgroundColor(this.vm.canConfirmHere()
            ? this.theme.primary : this.theme.border)
          .fontColor(this.theme.primaryContrast)
          .enabled(this.vm.canConfirmHere())
          .onClick(() => { this.vm.performPickerConfirm(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 20 })
      .backgroundColor(this.theme.surface)
    }
    .width('100%').height('100%')
    .backgroundColor(this.theme.background)
  }

  // ===========================================================================
  // Create folder dialog
  // ===========================================================================

  @Builder
  buildCreateFolderDialog() {
    Column({ space: 16 }) {
      Text(t('fb.newFolder'))
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
        .width('100%').textAlign(TextAlign.Start)

      Text(`${t('fb.willCreateInside')} ${this.currentPickerFolderName()}`)
        .fontSize(12).fontColor(this.theme.textSecondary)
        .width('100%').textAlign(TextAlign.Start)
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })

      TextInput({ text: this.vm.newFolderName, placeholder: t('fb.folderNamePlaceholder') })
        .fontSize(15)
        .fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textTertiary)
        .backgroundColor(this.theme.chipBg)
        .onChange((value: string) => { this.vm.newFolderName = value; })

      Row({ space: 12 }) {
        Button(t('common.cancel'))
          .layoutWeight(1)
          .backgroundColor(this.theme.chipBg)
          .fontColor(this.theme.textPrimary)
          .onClick(() => { this.vm.cancelCreateFolder(); })

        Button(this.vm.isCreatingFolder ? t('fb.creating') : t('fb.create'))
          .layoutWeight(1)
          .backgroundColor(this.theme.primary)
          .fontColor(this.theme.primaryContrast)
          .enabled(!this.vm.isCreatingFolder)
          .onClick(() => { this.vm.performCreateFolder(); })
      }
      .width('100%')
    }
    .width('85%').padding(20)
    .backgroundColor(this.theme.surface).borderRadius(16)
  }

  private currentPickerFolderName(): string {
    if (this.vm.createFolderTargetId === this.vm.currentFolderId) {
      const crumbs: Crumb[] = this.vm.crumbs;
      if (crumbs.length > 0) return crumbs[crumbs.length - 1].name;
    }
    const pickerCrumbs: Crumb[] = this.vm.movePickerCrumbs;
    if (pickerCrumbs.length === 0) return t('fb.files');
    return pickerCrumbs[pickerCrumbs.length - 1].name;
  }

  // ===========================================================================
  // Tasks panel
  // ===========================================================================

  @Builder
  buildActivityPanel() {
    Column() {
      Row()
        .width(40).height(4).borderRadius(2)
        .backgroundColor(this.theme.border)
        .margin({ top: 8, bottom: 12 })

      Row() {
        Column({ space: 2 }) {
          Text(t('fb.tasks'))
            .fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor(this.theme.textPrimary)
            .textAlign(TextAlign.Start).width('100%')

          Text(t('fb.recent500'))
            .fontSize(11).fontColor(this.theme.textTertiary)
            .textAlign(TextAlign.Start).width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row() {
          this.appIcon($r('app.media.ic_close'), SIZE_TASKS_CLOSE, this.theme.textSecondary)
        }
        .width(36).height(36)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.vm.closeActivityPanel(); })
      }
      .width('100%')
      .padding({ left: 20, right: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      this.buildActivityTabs()

      Divider().color(this.theme.divider)

      if (this.currentTabCount() === 0) {
        this.buildActivityEmptyState()
      } else {
        this.buildActivityGroups()
      }

      if (RETRY_ENABLED
        && this.vm.activityTab === ACTIVITY_TAB_FAILED
        && this.tabFailedCount > 0) {
        Divider().color(this.theme.divider)
        Button(`${t('fb.retryAll')} (${this.tabFailedCount})`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.theme.primary)
          .fontColor(this.theme.primaryContrast)
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .margin({ left: 16, right: 16, top: 12 })
          .onClick(() => {
            this.vm.retryAllFailed();
          })
      }

      if (this.hasAnyOps) {
        Divider().color(this.theme.divider)
        Row({ space: 6 }) {
          Row({ space: 4 }) {
            this.appIcon($r('app.media.ic_check'), SIZE_TASKS_CHIP_ICON,
              this.canClearCompleted
                ? this.theme.textPrimary : this.theme.textTertiary)
            Text(t('fb.clearCompleted'))
              .fontSize(11)
              .fontColor(this.canClearCompleted
                ? this.theme.textPrimary : this.theme.textTertiary)
          }
          .height(36)
          .padding({ left: 12, right: 12 })
          .backgroundColor(this.theme.chipBg)
          .borderRadius(18)
          .alignItems(VerticalAlign.Center)
          .opacity(this.canClearCompleted ? 1.0 : 0.5)
          .onClick(() => {
            if (this.canClearCompleted) {
              this.vm.clearCompletedOperations();
            }
          })

          Row({ space: 4 }) {
            this.appIcon($r('app.media.ic_delete'), SIZE_TASKS_CHIP_ICON,
              this.canClearAll
                ? this.theme.textPrimary : this.theme.textTertiary)
            Text(t('fb.clearAll'))
              .fontSize(11)
              .fontColor(this.canClearAll
                ? this.theme.textPrimary : this.theme.textTertiary)
          }
          .height(36)
          .padding({ left: 12, right: 12 })
          .backgroundColor(this.theme.chipBg)
          .borderRadius(18)
          .alignItems(VerticalAlign.Center)
          .opacity(this.canClearAll ? 1.0 : 0.5)
          .onClick(() => {
            if (this.canClearAll) {
              this.vm.clearFinishedOperations();
            }
          })

          Row({ space: 4 }) {
            this.appIcon($r('app.media.ic_warning'), SIZE_TASKS_CHIP_ICON, this.theme.error)
            Text(t('fb.forceClear'))
              .fontSize(11)
              .fontColor(this.theme.error)
          }
          .height(36)
          .padding({ left: 12, right: 12 })
          .backgroundColor(this.theme.errorSoft)
          .borderRadius(18)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.vm.forceClearAllOperations();
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ left: 16, right: 16, top: 12, bottom: 20 })
      } else {
        Row().height(24)
      }
    }
    .width('100%')
    .backgroundColor(this.theme.surface)
    .borderRadius({ topLeft: 20, topRight: 20 })
    .shadow({ radius: 20, color: '#22000000', offsetX: 0, offsetY: -4 })
  }

  @Builder
  buildActivityTabs() {
    Row({ space: 6 }) {
      this.buildTabAll()
      this.buildTabPending()
      this.buildTabSuccess()
      this.buildTabFailed()
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 12 })
  }

  @Builder
  buildTabAll() {
    Row({ space: 4 }) {
      Text(t('fb.tab.all'))
        .fontSize(12)
        .fontWeight(this.vm.activityTab === ACTIVITY_TAB_ALL
          ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.vm.activityTab === ACTIVITY_TAB_ALL
          ? this.theme.primaryContrast : this.theme.textSecondary)

      Text(`${this.tabAllCount}`)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.vm.activityTab === ACTIVITY_TAB_ALL
          ? this.theme.primaryContrast : this.theme.textTertiary)
        .backgroundColor(this.vm.activityTab === ACTIVITY_TAB_ALL
          ? '#33FFFFFF' : this.theme.chipBg)
        .borderRadius(8)
        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
        .constraintSize({ minWidth: 14 })
        .textAlign(TextAlign.Center)
    }
    .height(32)
    .padding({ left: 12, right: 10 })
    .backgroundColor(this.vm.activityTab === ACTIVITY_TAB_ALL
      ? this.theme.primary : this.theme.chipBg)
    .borderRadius(16)
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.vm.setActivityTab(ACTIVITY_TAB_ALL); })
  }

  @Builder
  buildTabPending() {
    Row({ space: 4 }) {
      Text(t('fb.tab.pending'))
        .fontSize(12)
        .fontWeight(this.vm.activityTab === ACTIVITY_TAB_PENDING
          ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.vm.activityTab === ACTIVITY_TAB_PENDING
          ? this.theme.primaryContrast : this.theme.textSecondary)

      Text(`${this.tabPendingCount}`)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.vm.activityTab === ACTIVITY_TAB_PENDING
          ? this.theme.primaryContrast : this.theme.textTertiary)
        .backgroundColor(this.vm.activityTab === ACTIVITY_TAB_PENDING
          ? '#33FFFFFF' : this.theme.chipBg)
        .borderRadius(8)
        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
        .constraintSize({ minWidth: 14 })
        .textAlign(TextAlign.Center)
    }
    .height(32)
    .padding({ left: 12, right: 10 })
    .backgroundColor(this.vm.activityTab === ACTIVITY_TAB_PENDING
      ? this.theme.primary : this.theme.chipBg)
    .borderRadius(16)
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.vm.setActivityTab(ACTIVITY_TAB_PENDING); })
  }

  @Builder
  buildTabSuccess() {
    Row({ space: 4 }) {
      Text(t('fb.tab.done'))
        .fontSize(12)
        .fontWeight(this.vm.activityTab === ACTIVITY_TAB_SUCCESS
          ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.vm.activityTab === ACTIVITY_TAB_SUCCESS
          ? this.theme.primaryContrast : this.theme.textSecondary)

      Text(`${this.tabSuccessCount}`)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.vm.activityTab === ACTIVITY_TAB_SUCCESS
          ? this.theme.primaryContrast : this.theme.textTertiary)
        .backgroundColor(this.vm.activityTab === ACTIVITY_TAB_SUCCESS
          ? '#33FFFFFF' : this.theme.chipBg)
        .borderRadius(8)
        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
        .constraintSize({ minWidth: 14 })
        .textAlign(TextAlign.Center)
    }
    .height(32)
    .padding({ left: 12, right: 10 })
    .backgroundColor(this.vm.activityTab === ACTIVITY_TAB_SUCCESS
      ? this.theme.primary : this.theme.chipBg)
    .borderRadius(16)
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.vm.setActivityTab(ACTIVITY_TAB_SUCCESS); })
  }

  @Builder
  buildTabFailed() {
    Row({ space: 4 }) {
      Text(t('fb.tab.failed'))
        .fontSize(12)
        .fontWeight(this.vm.activityTab === ACTIVITY_TAB_FAILED
          ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.vm.activityTab === ACTIVITY_TAB_FAILED
          ? this.theme.primaryContrast : this.theme.textSecondary)

      Text(`${this.tabFailedCount}`)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.vm.activityTab === ACTIVITY_TAB_FAILED
          ? this.theme.primaryContrast : this.theme.textTertiary)
        .backgroundColor(this.vm.activityTab === ACTIVITY_TAB_FAILED
          ? '#33FFFFFF' : this.theme.chipBg)
        .borderRadius(8)
        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
        .constraintSize({ minWidth: 14 })
        .textAlign(TextAlign.Center)
    }
    .height(32)
    .padding({ left: 12, right: 10 })
    .backgroundColor(this.vm.activityTab === ACTIVITY_TAB_FAILED
      ? this.theme.primary : this.theme.chipBg)
    .borderRadius(16)
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.vm.setActivityTab(ACTIVITY_TAB_FAILED); })
  }

  @Builder
  buildActivityGroups() {
    List({ space: 1 }) {
      ForEach(this.groupOpsByTab(this.vm.activityTab),
        (group: ActivityGroup) => {
          ListItem() {
            this.buildDateHeader(group.dateLabel, group.operations.length)
          }

          ForEach(group.operations, (op: Operation) => {
            ListItem() { this.buildActivityRow(op) }
          }, (op: Operation) =>
          `${op.id}_${op.status}_${op.progress}_${op.completedAt}_${op.errorMessage}`
          )
        }, (group: ActivityGroup) =>
        `${this.vm.activityTab}_${group.dateLabel}_` +
          `${group.operations.length}_${this.listVersion}`
      )
    }
    .width('100%')
    .constraintSize({ maxHeight: 440 })
    .divider({ strokeWidth: 1, color: this.theme.divider })
  }

  @Builder
  buildDateHeader(label: string, count: number) {
    Row() {
      Text(label)
        .fontSize(12).fontWeight(FontWeight.Medium)
        .fontColor(this.theme.textSecondary).layoutWeight(1)
      Text(`${count}`)
        .fontSize(11).fontColor(this.theme.textTertiary)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 8 })
    .backgroundColor(this.theme.background)
  }

  @Builder
  buildActivityEmptyState() {
    Column({ space: 10 }) {
      this.appIcon(this.emptyStateGlyphRes(),
        SIZE_TASKS_EMPTY, this.theme.textTertiary)
      Text(this.emptyStateLabel())
        .fontSize(14).fontColor(this.theme.textSecondary)
    }
    .width('100%').height(200).justifyContent(FlexAlign.Center)
  }

  private emptyStateGlyphRes(): Resource {
    if (this.vm.activityTab === ACTIVITY_TAB_PENDING) return $r('app.media.ic_pending');
    if (this.vm.activityTab === ACTIVITY_TAB_FAILED) return $r('app.media.ic_error');
    return $r('app.media.ic_check');
  }

  private emptyStateLabel(): string {
    if (this.vm.activityTab === ACTIVITY_TAB_ALL) return t('fb.noRecentTasks');
    if (this.vm.activityTab === ACTIVITY_TAB_PENDING) return t('fb.noPendingTasks');
    if (this.vm.activityTab === ACTIVITY_TAB_SUCCESS) return t('fb.noCompletedTasks');
    return t('fb.noFailedTasks');
  }

  @Builder
  buildActivityRow(op: Operation) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        this.appIcon(this.operationKindRes(op.itemKind),
          SIZE_TASKS_KIND_ICON, this.theme.textSecondary)
        this.appIcon(this.operationIconRes(op.type),
          SIZE_TASKS_TYPE_ICON, this.theme.primary)
      }
      .width(36).alignItems(HorizontalAlign.Center)

      Column({ space: 3 }) {
        Text(op.itemName)
          .fontSize(14).fontColor(this.theme.textPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Start).width('100%')

        Row({ space: 6 }) {
          Text(operationTypeLabel(op.type))
            .fontSize(11).fontColor(this.theme.textSecondary)
          if (op.batchTotal > 0) {
            Text(`· ${op.batchIndex} / ${op.batchTotal}`)
              .fontSize(11).fontColor(this.theme.textSecondary)
          }
          Text(`· ${op.isRetry && op.status === OperationStatus.RUNNING
            ? t('fb.retrying')
            : operationStatusLabel(op.status)}`)
            .fontSize(11).fontColor(this.statusColor(op.status))
        }

        if (op.status === OperationStatus.FAILED && op.errorMessage.length > 0) {
          Text(op.errorMessage)
            .fontSize(11).fontColor(this.theme.error)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)

      if (op.status === OperationStatus.RUNNING && op.progress >= 0) {
        Stack({ alignContent: Alignment.Center }) {
          Progress({
            value: op.progress, total: 100, type: ProgressType.Ring
          })
            .color(this.theme.primary)
            .style({ strokeWidth: 3 })
            .width(38).height(38)
          Text(`${op.progress}`)
            .fontSize(9).fontWeight(FontWeight.Medium)
            .fontColor(this.theme.textSecondary)
        }
        .width(38).height(38)
      } else if (RETRY_ENABLED && canRetry(op)) {
        Row() {
          this.appIcon($r('app.media.ic_retry'),
            SIZE_TASKS_RETRY, this.theme.primary)
        }
        .width(36).height(36)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.vm.retrySingleOperation(op.id); })
      } else if (isActiveStatus(op.status)) {
        LoadingProgress().width(20).height(20).color(this.theme.primary)
      } else if (op.status === OperationStatus.SUCCESS) {
        this.appIcon($r('app.media.ic_check'),
          SIZE_TASKS_STATUS, this.theme.success)
      } else if (op.status === OperationStatus.FAILED) {
        this.appIcon($r('app.media.ic_error'),
          SIZE_TASKS_STATUS, this.theme.error)
      } else {
        this.appIcon($r('app.media.ic_close'),
          SIZE_TASKS_STATUS, this.theme.textTertiary)
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
  }

  private statusColor(status: OperationStatus): string {
    switch (status) {
      case OperationStatus.RUNNING: return this.theme.primary;
      case OperationStatus.SUCCESS: return this.theme.success;
      case OperationStatus.FAILED: return this.theme.error;
      case OperationStatus.CANCELLED: return this.theme.textSecondary;
      default: return this.theme.textSecondary;
    }
  }

  // ===========================================================================
  // Sidebar
  // ===========================================================================

  @Builder
  buildSidebar() {
    Column() {
      Row({ space: 12 }) {
        Image($r('app.media.app_icon'))
          .width(44).height(44)
          .objectFit(ImageFit.Contain)
          .draggable(false)
          .borderRadius(11)

        Column({ space: 2 }) {
          Text(this.appDisplayName())
            .fontSize(22).fontWeight(FontWeight.Bold)
            .fontColor(this.theme.textPrimary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Start).width('100%')

          Text(t('app.tagline'))
            .fontSize(12).fontColor(this.theme.textSecondary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Start).width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 20, right: 20, top: 32, bottom: 20 })

      Divider().color(this.theme.divider)
      this.buildStorageCard()
      Divider().color(this.theme.divider)

      Text(t('fb.accounts'))
        .fontSize(11).fontColor(this.theme.textTertiary)
        .fontWeight(FontWeight.Medium)
        .padding({ left: 20, top: 16, bottom: 8 }).width('100%')

      List() {
        ForEach(this.vm.groups, (group: ProviderGroup) => {
          ListItem() { this.buildProviderHeader(group) }
          if (this.vm.isExpanded(group.type)) {
            ForEach(group.accounts, (account: AccountInfo) => {
              ListItem() { this.buildAccountChildRow(account) }
            }, (account: AccountInfo) => account.accountId)
          }
        }, (group: ProviderGroup) => group.type)
      }
      .layoutWeight(1).width('100%')

      Divider().color(this.theme.divider)
      this.buildSidebarFooter()
    }
    .width(280).height('100%')
    .backgroundColor(this.theme.surface)
  }

  @Builder
  buildStorageCard() {
    Column({ space: 14 }) {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          this.appIcon($r('app.media.ic_storage'),
            SIZE_SIDEBAR_STORAGE, this.theme.primary)
          Text(t('fb.storage'))
            .fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor(this.theme.textPrimary)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.cloudStorageLoading && this.cloudStorage === null) {
          Row({ space: 8 }) {
            LoadingProgress().width(14).height(14).color(this.theme.primary)
            Text(t('set.cache.calc'))
              .fontSize(11).fontColor(this.theme.textSecondary)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        } else if (this.cloudStorage === null) {
          Text('—')
            .fontSize(11).fontColor(this.theme.textSecondary)
            .width('100%').textAlign(TextAlign.Start)
        } else {
          if (!this.cloudStorage.isUnlimited) {
            Stack({ alignContent: Alignment.Start }) {
              Row()
                .width('100%').height(6)
                .backgroundColor(this.theme.chipBg)
                .borderRadius(3)
              Row()
                .width(`${this.cloudStoragePercent()}%`).height(6)
                .backgroundColor(this.cloudStoragePercent() > 85
                  ? this.theme.error : this.theme.primary)
                .borderRadius(3)
            }
            .width('100%')
            .height(6)
          }

          Text(this.cloudStorageLabel())
            .fontSize(11).fontColor(this.theme.textSecondary)
            .width('100%').textAlign(TextAlign.Start)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        Row({ space: 8 }) {
          this.appIcon($r('app.media.ic_cloud_offline'),
            SIZE_SIDEBAR_OFFLINE, this.theme.textSecondary)
          Text(t('fb.offlineCache'))
            .fontSize(12).fontWeight(FontWeight.Medium)
            .fontColor(this.theme.textPrimary)
            .layoutWeight(1)

          if (this.offlineClearing) {
            LoadingProgress().width(16).height(16).color(this.theme.error)
          } else if (this.offlineCount > 0) {
            Row() {
              this.appIcon($r('app.media.ic_delete'),
                SIZE_SIDEBAR_CLEAR, this.theme.error)
            }
            .width(32).height(32)
            .borderRadius(16)
            .justifyContent(FlexAlign.Center)
            .onClick(() => { this.confirmClearOffline(); })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.offlineCount === 0) {
          Text(t('fb.storageEmpty'))
            .fontSize(11).fontColor(this.theme.textSecondary)
            .width('100%').textAlign(TextAlign.Start)
        } else {
          Text(`${this.offlineCount} ${this.offlineCount === 1
            ? t('fb.item') : t('fb.items')} · ${FileBrowserViewModel.formatSize(this.offlineBytes)}`)
            .fontSize(11).fontColor(this.theme.textSecondary)
            .width('100%').textAlign(TextAlign.Start)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildSidebarFooter() {
    Row() {
      this.buildFooterAction(
        $r('app.media.ic_add_account'),
        t('fb.addAccount'),
        this.theme.primary,
        (): void => { this.vm.onAddAccount(); }
      )

      this.buildFooterAction(
        $r('app.media.ic_settings'),
        t('fb.settings'),
        this.theme.textSecondary,
        (): void => {
          this.vm.closeSidebar();
          router.pushUrl({ url: Routes.SETTINGS })
            .catch((e: Error) => { /* log */ });
        }
      )

      this.buildFooterAction(
        $r('app.media.ic_exit'),
        t('fb.exit'),
        this.theme.error,
        (): void => { this.vm.onExitApp(); }
      )
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 14, bottom: 18 })
    .justifyContent(FlexAlign.SpaceAround)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.theme.surface)
  }

  @Builder
  buildFooterAction(
    iconRes: Resource,
    label: string,
    color: string,
    action: () => void
  ) {
    Column({ space: 4 }) {
      this.appIcon(iconRes, SIZE_SIDEBAR_FOOTER, color)
      Text(label)
        .fontSize(10)
        .fontColor(color)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 6, bottom: 6 })
    .onClick(action)
  }

  private appDisplayName(): string {
    return 'CLDrive';
  }

  @Builder
  buildProviderHeader(group: ProviderGroup) {
    Row({ space: 10 }) {
      this.appIcon(
        this.vm.isExpanded(group.type)
          ? $r('app.media.ic_chevron_down')
          : $r('app.media.ic_chevron_right'),
        SIZE_SIDEBAR_PROVIDER_CHEVRON,
        this.theme.textSecondary
      )
      ProviderIcon({ provider: group.type, iconSize: 26 })
      Text(group.label)
        .fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.theme.textPrimary)
        .layoutWeight(1)
      Text(`${group.accounts.length}`)
        .fontSize(11).fontColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg)
        .borderRadius(10).padding({ left: 8, right: 8, top: 2, bottom: 2 })
    }
    .width('100%').padding({ left: 12, right: 16, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.vm.toggleExpanded(group.type); })
  }

  @Builder
  buildAccountChildRow(account: AccountInfo) {
    Row({ space: 10 }) {
      Column()
        .width(2).height(40)
        .backgroundColor(this.theme.border)
        .margin({ left: 15, right: 4 })

      Column() {
        Text(FileBrowserViewModel.initialOf(account))
          .fontSize(13).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
      }
      .width(32).height(32).borderRadius(16)
      .backgroundColor(FileBrowserViewModel.colorForProvider(account.provider))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 2 }) {
        Text(account.displayName)
          .fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.theme.textPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(account.email !== undefined && account.email.length > 0
          ? account.email
          : FileBrowserViewModel.providerLabel(account.provider))
          .fontSize(11).fontColor(this.theme.textSecondary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (account.accountId === this.vm.activeAccountId) {
        Row({ space: 4 }) {
          this.appIcon($r('app.media.ic_check'),
            SIZE_SIDEBAR_ACCOUNT_CHECK, this.theme.primary)

          Row() {
            this.appIcon($r('app.media.ic_sign_out'),
              SIZE_SIDEBAR_ACCOUNT_SIGNOUT, this.theme.warning)
          }
          .width(32).height(32)
          .borderRadius(16)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.vm.onSignOut(); })
        }
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding({ left: 0, right: 16, top: 10, bottom: 10 })
    .backgroundColor(account.accountId === this.vm.activeAccountId
      ? this.theme.chipSelectedBg : Color.Transparent)
    .onClick(() => {
      this.vm.onSwitchAccount(account.accountId);
      setTimeout(() => { this.refreshStorageInfo(); }, 300);
    })
  }
}
import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import {
  FileBrowserViewModel, ProviderGroup, Crumb
} from '../viewmodels/FileBrowserViewModel';
import { CloudProviderType } from '../core/models/CloudProviderType';
import { CloudItem } from '../core/models/CloudItem';
import { CloudItemType } from '../core/models/CloudItemType';
import { AccountInfo } from '../core/models/AccountInfo';
import {
  Operation, OperationType, OperationStatus, OperationItemKind,
  operationTypeIcon, operationTypeLabel, operationStatusLabel,
  operationItemKindIcon, isActiveStatus
} from '../core/models/Operation';
import { OperationTracker } from '../core/services/OperationTracker';
import { ThemeManager } from '../core/theme/ThemeManager';
import { ThemeColors } from '../core/theme/ThemeColors';
import { ProviderIcon } from '../components/ProviderIcon';
import { FileIcon } from '../components/FileIcon';
import { Routes } from '../utils/RouteConstants';

@Entry
@Component
struct FileBrowserPage {
  @State vm: FileBrowserViewModel = new FileBrowserViewModel();

  // ---- Theme ----
  @State private theme: ThemeColors = ThemeManager.get().colors();

  // ---- Page-owned activity state ----
  @State private operations: Operation[] = [];
  @State private hasAnyOps: boolean = false;
  @State private canClearCompleted: boolean = false;
  @State private canClearAll: boolean = false;
  @State private activeOpCount: number = 0;
  @State private hasFinishedOps: boolean = false;

  private crumbScroller: Scroller = new Scroller();

  private onOperationsChanged = (ops: Operation[]): void => {
    this.operations = ops;

    let completed = false;
    let finished = false;
    let active = 0;

    for (let i = 0; i < ops.length; i++) {
      const s: OperationStatus = ops[i].status;
      if (s === OperationStatus.SUCCESS) completed = true;
      if (s === OperationStatus.SUCCESS
        || s === OperationStatus.FAILED
        || s === OperationStatus.CANCELLED) {
        finished = true;
      }
      if (s === OperationStatus.QUEUED || s === OperationStatus.RUNNING) active++;
    }

    this.hasAnyOps = ops.length > 0;
    this.canClearCompleted = completed;
    this.canClearAll = finished;
    this.activeOpCount = active;
    this.hasFinishedOps = finished;
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
  }

  aboutToDisappear(): void {
    OperationTracker.get().unsubscribe(this.onOperationsChanged);
    ThemeManager.get().unsubscribe(this.onThemeChanged);
  }

  onPageShow(): void {
    this.vm.onPageShow();
  }

  // ===========================================================================
  // Build
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
        Column() {
          Column()
            .width('100%')
            .layoutWeight(1)
            .backgroundColor(this.theme.overlay)
            .onClick(() => { this.vm.closeUploadMenu(); })
          this.buildUploadMenu()
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
        Text('☰')
          .fontSize(22)
          .fontColor(this.theme.primary)
          .width(24)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.vm.openSidebar(); })

        ProviderIcon({
          provider: this.vm.activeAccount !== null
            ? this.vm.activeAccount.provider
            : CloudProviderType.ONEDRIVE,
          iconSize: 34
        })

        Column({ space: 2 }) {
          Text(this.vm.activeAccount !== null
            ? this.vm.activeAccount.displayName
            : 'Files')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Start)
            .width('100%')

          if (this.vm.activeAccount !== null
            && this.vm.activeAccount.email !== undefined
            && this.vm.activeAccount.email.length > 0) {
            Text(this.vm.activeAccount.email)
              .fontSize(12)
              .fontColor(this.theme.textSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Start)
              .width('100%')
          } else {
            Text(FileBrowserViewModel.providerLabel(
              this.vm.activeAccount !== null
                ? this.vm.activeAccount.provider
                : CloudProviderType.ONEDRIVE
            ))
              .fontSize(12)
              .fontColor(this.theme.textSecondary)
              .maxLines(1)
              .textAlign(TextAlign.Start)
              .width('100%')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.buildActivityButton()

        if (this.vm.canGoBack()) {
          Button('‹')
            .fontSize(22)
            .backgroundColor(Color.Transparent)
            .fontColor(this.theme.primary)
            .padding(0)
            .width(28)
            .onClick(() => { this.vm.goBack(); })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.vm.crumbs.length > 1) {
        Row() {
          Row().width(82)
          Scroll(this.crumbScroller) {
            Row({ space: 6 }) {
              ForEach(this.vm.crumbs, (crumb: Crumb, index: number) => {
                Row({ space: 6 }) {
                  Text(crumb.name)
                    .fontSize(12)
                    .fontWeight(index === this.vm.crumbs.length - 1
                      ? FontWeight.Medium
                      : FontWeight.Normal)
                    .fontColor(index === this.vm.crumbs.length - 1
                      ? this.theme.textPrimary
                      : this.theme.primary)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .textAlign(TextAlign.Start)
                    .onClick(() => { this.vm.goToCrumb(index); })

                  if (index < this.vm.crumbs.length - 1) {
                    Text('››').fontSize(11).fontColor(this.theme.textTertiary)
                  }
                }
              }, (crumb: Crumb) => crumb.id)
            }
            .height(22)
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .align(Alignment.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 4 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.theme.surface)
  }

  @Builder
  buildActivityButton() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Text('⟳')
        .fontSize(22)
        .fontColor(this.hasAnyOps ? this.theme.primary : this.theme.textTertiary)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)

      if (this.activeOpCount > 0) {
        Text(`${this.activeOpCount}`)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(this.theme.error)
          .borderRadius(9)
          .padding({ left: 5, right: 5, top: 1, bottom: 1 })
          .constraintSize({ minWidth: 18, minHeight: 18 })
          .textAlign(TextAlign.Center)
      } else if (this.hasFinishedOps) {
        Text(' ')
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor(this.theme.primary)
          .margin({ top: 2, right: 4 })
      }
    }
    .width(36)
    .height(36)
    .onClick(() => { this.vm.openActivityPanel(); })
  }

  // ===========================================================================
  // Selection top bar
  // ===========================================================================

  @Builder
  buildSelectionTopBar() {
    Row({ space: 12 }) {
      Text('✕')
        .fontSize(20)
        .fontColor(this.theme.textPrimary)
        .width(32)
        .textAlign(TextAlign.Center)
        .onClick(() => { this.vm.exitSelectionMode(); })

      Text(`${this.vm.selectedCount()} selected`)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.textPrimary)
        .layoutWeight(1)

      if (this.vm.allSelected()) {
        Button('Deselect all')
          .fontSize(13)
          .backgroundColor(Color.Transparent)
          .fontColor(this.theme.primary)
          .onClick(() => { this.vm.deselectAll(); })
      } else {
        Button('Select all')
          .fontSize(13)
          .backgroundColor(Color.Transparent)
          .fontColor(this.theme.primary)
          .onClick(() => { this.vm.selectAll(); })
      }
    }
    .width('100%')
    .padding({ left: 8, right: 12, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.theme.surface)
  }

  // ===========================================================================
  // Selection action bar
  // ===========================================================================

  @Builder
  buildSelectionActionBar() {
    Row() {
      this.buildSelectionAction('🗑', 'Delete', (): void => { this.vm.onBatchDelete(); })
      this.buildSelectionAction('→', 'Move', (): void => { this.vm.onBatchMove(); })
      this.buildSelectionAction('⧉', 'Copy', (): void => { this.vm.onBatchCopy(); })
    }
    .width('100%')
    .padding({ top: 10, bottom: 16 })
    .backgroundColor(this.theme.surface)
    .shadow({ radius: 12, color: '#22000000', offsetX: 0, offsetY: -2 })
  }

  @Builder
  buildSelectionAction(icon: string, label: string, action: () => void) {
    Column({ space: 4 }) {
      Text(icon).fontSize(22).fontColor(this.theme.primary)
      Text(label).fontSize(12).fontColor(this.theme.primary)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .onClick(action)
  }

  // ===========================================================================
  // Floating glass bottom bar
  // ===========================================================================

  @Builder
  buildBottomBar() {
    Row({ space: 12 }) {
      Row({ space: 10 }) {
        Text('🔍').fontSize(16).fontColor(this.theme.primary)
        Text('Search your files')
          .fontSize(14)
          .fontColor(this.theme.textPrimary)
          .layoutWeight(1)
      }
      .layoutWeight(1)
      .height(48)
      .padding({ left: 18, right: 18 })
      .backgroundColor(this.theme.isDark ? '#1AFFFFFF' : '#1A000000')
      .backgroundEffect({
        radius: 40,
        saturation: 1.8,
        brightness: 1.05,
        color: '#00000000'
      })
      .borderRadius(24)
      .border({
        width: 0.5,
        color: this.theme.isDark ? '#33FFFFFF' : '#33000000'
      })
      .clip(true)
      .shadow({
        radius: 10,
        color: this.theme.isDark ? '#33000000' : '#12000000',
        offsetX: 0,
        offsetY: 4
      })
      .alignItems(VerticalAlign.Center)
      .onClick(() => { this.vm.openSearch(); })

      Text('+')
        .fontSize(32)
        .fontColor('#FFFFFF')
        .width(56)
        .height(56)
        .borderRadius(28)
        .backgroundColor(this.theme.primary)
        .textAlign(TextAlign.Center)
        .border({
          width: 0.5,
          color: this.theme.isDark ? '#33FFFFFF' : '#22FFFFFF'
        })
        .clip(true)
        .shadow({
          radius: 8,
          color: this.theme.isDark ? '#40000000' : '#260A5BD3',
          offsetX: 0,
          offsetY: 5
        })
        .onClick(() => { this.vm.openUploadMenu(); })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 24, top: 8 })
    .alignItems(VerticalAlign.Center)
  }

  // ===========================================================================
  // Upload menu
  // ===========================================================================

  @Builder
  buildUploadMenu() {
    Column() {
      Row()
        .width(40).height(4).borderRadius(2).backgroundColor(this.theme.border)
        .margin({ top: 8, bottom: 12 })

      Text('Upload')
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
        .width('100%').padding({ left: 20, bottom: 12 })
        .textAlign(TextAlign.Start)

      Divider().color(this.theme.divider)

      Row({ space: 16 }) {
        Text('📄').fontSize(24).width(32).textAlign(TextAlign.Center)
        Text('Upload file').fontSize(16).fontColor(this.theme.textPrimary).layoutWeight(1)
        Text('›').fontSize(20).fontColor(this.theme.textTertiary)
      }
      .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .onClick(() => { this.vm.onUploadFile(); })

      Divider().color(this.theme.divider).margin({ left: 68 })

      Row({ space: 16 }) {
        Text('📁').fontSize(24).width(32).textAlign(TextAlign.Center)
        Text('Upload folder').fontSize(16).fontColor(this.theme.textPrimary).layoutWeight(1)
        Text('›').fontSize(20).fontColor(this.theme.textTertiary)
      }
      .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .onClick(() => { this.vm.onUploadFolder(); })

      Row().height(24)
    }
    .width('100%')
    .backgroundColor(this.theme.surface)
    .borderRadius({ topLeft: 20, topRight: 20 })
    .shadow({ radius: 20, color: '#22000000', offsetX: 0, offsetY: -4 })
  }

  // ===========================================================================
  // Search overlay
  // ===========================================================================

  @Builder
  buildSearchOverlay() {
    Column() {
      Row({ space: 8 }) {
        Text('←')
          .fontSize(22)
          .fontColor(this.theme.textPrimary)
          .width(36).textAlign(TextAlign.Center)
          .onClick(() => { this.vm.closeSearch(); })

        TextInput({
          text: this.vm.searchQuery,
          placeholder: 'Search your files'
        })
          .fontSize(15)
          .fontColor(this.theme.textPrimary)
          .placeholderColor(this.theme.textTertiary)
          .layoutWeight(1)
          .backgroundColor(this.theme.chipBg)
          .borderRadius(20)
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .onChange((value: string) => { this.vm.setSearchQuery(value); })
      }
      .width('100%')
      .padding({ left: 8, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.theme.surface)
      .alignItems(VerticalAlign.Center)

      Divider().color(this.theme.divider)

      if (this.vm.isSearching) {
        Column({ space: 12 }) {
          LoadingProgress().width(32).height(32).color(this.theme.primary)
          Text('Searching...').fontSize(13).fontColor(this.theme.textSecondary)
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else if (this.vm.searchError.length > 0) {
        Column({ space: 10 }) {
          Text('🔍').fontSize(42).fontColor(this.theme.textTertiary)
          Text('Search failed')
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
          Text(this.vm.searchError)
            .fontSize(13).fontColor(this.theme.textSecondary)
            .textAlign(TextAlign.Center)
            .padding({ left: 32, right: 32 })
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else if (this.vm.searchQuery.trim().length === 0) {
        Column({ space: 10 }) {
          Text('🔍').fontSize(42).fontColor(this.theme.textTertiary)
          Text('Start typing to search')
            .fontSize(14).fontColor(this.theme.textSecondary)
          Text('Search across all files in your OneDrive.')
            .fontSize(12).fontColor(this.theme.textTertiary)
            .textAlign(TextAlign.Center)
            .padding({ left: 32, right: 32 })
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else if (this.vm.searchResults.length === 0) {
        Column({ space: 10 }) {
          Text('📂').fontSize(42).fontColor(this.theme.textTertiary)
          Text('No files match your search')
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
    Row({ space: 12 }) {
      if (item.type === CloudItemType.FOLDER) {
        Text('📁').fontSize(26).width(36).textAlign(TextAlign.Center)
      } else {
        FileIcon({
          fileName: item.name,
          mimeType: item.mimeType !== undefined ? item.mimeType : '',
          badgeSize: 36
        })
      }

      Column({ space: 2 }) {
        Text(item.name)
          .fontSize(15).fontColor(this.theme.textPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })

        if (item.type === CloudItemType.FILE && item.size !== undefined) {
          Text(FileBrowserViewModel.formatSize(item.size))
            .fontSize(12).fontColor(this.theme.textSecondary)
        } else {
          Text('Folder').fontSize(12).fontColor(this.theme.textSecondary)
        }
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
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
        Text('Loading...').fontSize(13).fontColor(this.theme.textSecondary)
      }
      .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
    } else if (this.vm.errorMessage.length > 0) {
      Column({ space: 12 }) {
        Text('Something went wrong')
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
        Text(this.vm.errorMessage)
          .fontSize(13).fontColor(this.theme.textSecondary)
          .textAlign(TextAlign.Center)
        Button('Retry').onClick(() => {
          this.vm.loadFolder(this.vm.currentFolderId);
        })
      }
      .layoutWeight(1).justifyContent(FlexAlign.Center).padding(24).width('100%')
    } else if (this.vm.items.length === 0) {
      Column({ space: 12 }) {
        Text('📂').fontSize(48)
        Text('This folder is empty')
          .fontSize(15).fontColor(this.theme.textSecondary)
      }
      .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
    } else {
      List({ space: 1 }) {
        ForEach(this.vm.items, (item: CloudItem) => {
          ListItem() { this.buildItemRow(item) }
        }, (item: CloudItem) => item.id)

        ListItem() { Row().height(100) }
      }
      .layoutWeight(1).width('100%')
      .divider({ strokeWidth: 1, color: this.theme.divider })
    }
  }

  @Builder
  buildItemRow(item: CloudItem) {
    Row({ space: 12 }) {
      if (this.vm.isSelectionMode) {
        Text(this.vm.isSelected(item.id) ? '☑' : '☐')
          .fontSize(22)
          .fontColor(this.vm.isSelected(item.id)
            ? this.theme.primary
            : this.theme.textTertiary)
          .width(24).textAlign(TextAlign.Center)

        if (item.type === CloudItemType.FOLDER) {
          Text('📁').fontSize(22).width(28).textAlign(TextAlign.Center)
        } else {
          FileIcon({
            fileName: item.name,
            mimeType: item.mimeType !== undefined ? item.mimeType : '',
            badgeSize: 28
          })
        }
      } else {
        if (item.type === CloudItemType.FOLDER) {
          Text('📁').fontSize(26).width(36).textAlign(TextAlign.Center)
        } else {
          FileIcon({
            fileName: item.name,
            mimeType: item.mimeType !== undefined ? item.mimeType : '',
            badgeSize: 36
          })
        }
      }

      Column({ space: 2 }) {
        Text(item.name)
          .fontSize(15).fontColor(this.theme.textPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })

        if (item.type === CloudItemType.FILE && item.size !== undefined) {
          Text(FileBrowserViewModel.formatSize(item.size))
            .fontSize(12).fontColor(this.theme.textSecondary)
        }
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)

      if (!this.vm.isSelectionMode) {
        Text('⋮')
          .fontSize(22).fontColor(this.theme.textSecondary)
          .width(40).height(40).textAlign(TextAlign.Center)
          .onClick(() => { this.vm.onShowItemActions(item); })
      }
    }
    .width('100%')
    .padding({
      left: this.vm.isSelectionMode ? 8 : 16,
      right: 8,
      top: 12,
      bottom: 12
    })
    .backgroundColor(
      this.vm.isSelectionMode && this.vm.isSelected(item.id)
        ? this.theme.chipSelectedBg
        : this.theme.surface
    )
    .onClick(() => {
      if (this.vm.isSelectionMode) {
        this.vm.toggleSelection(item.id);
      } else if (item.type === CloudItemType.FOLDER) {
        this.vm.openFolder(item);
      }
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction(() => {
          if (!this.vm.isSelectionMode) {
            this.vm.enterSelectionMode(item.id);
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
        Text('📁').fontSize(64)
      } else if (this.vm.selectedItem !== null) {
        FileIcon({
          fileName: this.vm.selectedItem.name,
          mimeType: this.vm.selectedItem.mimeType !== undefined
            ? this.vm.selectedItem.mimeType
            : '',
          badgeSize: 72,
          rounded: true
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
        Text(`Folder · ${FileBrowserViewModel.formatDate(this.vm.selectedItem.modifiedAt)}`)
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
        Text('🗑').fontSize(26)
        Text('Delete').fontSize(14).fontColor(this.theme.error)
      }
      .width('100%').padding({ top: 20, bottom: 20 })
      .backgroundColor(this.theme.surfaceSubtle)
      .borderRadius(12)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    }
    .width('100%').padding({ left: 16, right: 16 })
    .onClick(() => { this.vm.onDeleteItem(); })
  }

  @Builder
  buildDownloadRow() {
    Row({ space: 16 }) {
      if (this.vm.selectedItem !== null
        && this.vm.isDownloading(this.vm.selectedItem.id)) {
        LoadingProgress().width(22).height(22).color(this.theme.primary)
          .margin({ left: 3, right: 3 })
      } else {
        Text('⬇').fontSize(22).fontColor(this.theme.textSecondary)
          .width(28).textAlign(TextAlign.Center)
      }
      Text(this.vm.selectedItem !== null
        && this.vm.isDownloading(this.vm.selectedItem.id)
        ? 'Downloading...' : 'Download')
        .fontSize(16)
        .fontColor(this.vm.canDownloadSelected()
          ? this.theme.textPrimary
          : this.theme.textTertiary)
        .layoutWeight(1)
    }
    .width('100%').padding({ left: 24, right: 24, top: 14, bottom: 14 })
    .onClick(() => { this.vm.onDownloadItem(); })
  }

  @Builder
  buildOfflineRow() {
    Row({ space: 16 }) {
      Text('☁').fontSize(22).fontColor(this.theme.textSecondary)
        .width(28).textAlign(TextAlign.Center)
      Text('Make available offline').fontSize(16).fontColor(this.theme.textPrimary)
        .layoutWeight(1)
      Toggle({
        type: ToggleType.Switch,
        isOn: this.vm.selectedItem !== null
          && this.vm.isOffline(this.vm.selectedItem.id)
      })
        .selectedColor(this.theme.primary)
        .onChange((isOn: boolean) => { this.vm.onToggleOffline(isOn); })
    }
    .width('100%').padding({ left: 24, right: 24, top: 14, bottom: 14 })
  }

  @Builder
  buildRenameRow() {
    Row({ space: 16 }) {
      Text('✎').fontSize(22).fontColor(this.theme.textSecondary)
        .width(28).textAlign(TextAlign.Center)
      Text('Rename').fontSize(16).fontColor(this.theme.textPrimary).layoutWeight(1)
    }
    .width('100%').padding({ left: 24, right: 24, top: 14, bottom: 14 })
    .onClick(() => { this.vm.onRenameItem(); })
  }

  @Builder
  buildMoveRow() {
    Row({ space: 16 }) {
      Text('→').fontSize(22).fontColor(this.theme.textSecondary)
        .width(28).textAlign(TextAlign.Center)
      Text('Move').fontSize(16).fontColor(this.theme.textPrimary).layoutWeight(1)
    }
    .width('100%').padding({ left: 24, right: 24, top: 14, bottom: 14 })
    .onClick(() => { this.vm.onMoveItem(); })
  }

  @Builder
  buildCopyRow() {
    Row({ space: 16 }) {
      Text('⧉').fontSize(22).fontColor(this.theme.textSecondary)
        .width(28).textAlign(TextAlign.Center)
      Text('Copy').fontSize(16).fontColor(this.theme.textPrimary).layoutWeight(1)
    }
    .width('100%').padding({ left: 24, right: 24, top: 14, bottom: 14 })
    .onClick(() => { this.vm.onCopyItem(); })
  }

  @Builder
  buildDetailsRow() {
    Row({ space: 16 }) {
      Text('ⓘ').fontSize(22).fontColor(this.theme.textSecondary)
        .width(28).textAlign(TextAlign.Center)
      Text('Details').fontSize(16).fontColor(this.theme.textPrimary).layoutWeight(1)
    }
    .width('100%').padding({ left: 24, right: 24, top: 14, bottom: 14 })
    .onClick(() => { this.vm.onShowDetails(); })
  }

  // ===========================================================================
  // Rename dialog
  // ===========================================================================

  @Builder
  buildRenameDialog() {
    Column({ space: 16 }) {
      Text('Rename').fontSize(18).fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textPrimary)
        .width('100%').textAlign(TextAlign.Start)

      TextInput({ text: this.vm.renameText, placeholder: 'New name' })
        .fontSize(15)
        .fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textTertiary)
        .backgroundColor(this.theme.chipBg)
        .onChange((value: string) => { this.vm.renameText = value; })

      Row({ space: 12 }) {
        Button('Cancel')
          .layoutWeight(1)
          .backgroundColor(this.theme.chipBg)
          .fontColor(this.theme.textPrimary)
          .onClick(() => { this.vm.cancelRename(); })
        Button(this.vm.isProcessing ? 'Renaming...' : 'Rename')
          .layoutWeight(1)
          .backgroundColor(this.theme.primary)
          .fontColor(this.theme.primaryContrast)
          .enabled(!this.vm.isProcessing)
          .onClick(() => { this.vm.performRename(); })
      }
      .width('100%')
    }
    .width('85%').padding(20)
    .backgroundColor(this.theme.surface)
    .borderRadius(16)
  }

  // ===========================================================================
  // Move / Copy picker
  // ===========================================================================

  @Builder
  buildMovePicker() {
    Column() {
      Row({ space: 12 }) {
        Text('←')
          .fontSize(24).fontColor(this.theme.textPrimary)
          .width(32).textAlign(TextAlign.Center)
          .onClick(() => { this.vm.closeMovePicker(); })

        Text(this.vm.pickerTitle())
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.theme.textPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Start).layoutWeight(1)

        Button('New folder')
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
                    ? this.theme.textPrimary
                    : this.theme.primary)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .textAlign(TextAlign.Start)
                  .onClick(() => { this.vm.movePickerGoToCrumb(index); })
                if (index < this.vm.movePickerCrumbs.length - 1) {
                  Text('››').fontSize(11).fontColor(this.theme.textTertiary)
                }
              }
            }, (crumb: Crumb) => crumb.id)
          }
          .height(22).padding({ left: 16, right: 16 })
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
          Text('Loading folders...')
            .fontSize(13).fontColor(this.theme.textSecondary)
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else if (this.vm.movePickerError.length > 0) {
        Column({ space: 12 }) {
          Text('Could not load folders')
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
          Text(this.vm.movePickerError)
            .fontSize(13).fontColor(this.theme.textSecondary)
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).padding(24).width('100%')
      } else if (this.vm.movePickerItems.length === 0) {
        Column({ space: 10 }) {
          Text('📁').fontSize(42)
          Text('No subfolders here')
            .fontSize(14).fontColor(this.theme.textSecondary)
          Text('You can still use this folder, or create a new one.')
            .fontSize(12).fontColor(this.theme.textTertiary)
            .textAlign(TextAlign.Center).padding({ left: 32, right: 32 })
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else {
        List({ space: 1 }) {
          ForEach(this.vm.movePickerItems, (folder: CloudItem) => {
            ListItem() {
              Row({ space: 12 }) {
                Text('📁').fontSize(24).width(32).textAlign(TextAlign.Center)
                Text(folder.name)
                  .fontSize(15).fontColor(this.theme.textPrimary)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                Text('›').fontSize(20).fontColor(this.theme.textTertiary)
              }
              .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
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
        Button('Cancel')
          .layoutWeight(1)
          .backgroundColor(this.theme.chipBg)
          .fontColor(this.theme.textPrimary)
          .onClick(() => { this.vm.closeMovePicker(); })
        Button(this.vm.pickerConfirmLabel())
          .layoutWeight(1)
          .backgroundColor(this.vm.canConfirmHere()
            ? this.theme.primary
            : this.theme.border)
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
      Text('New folder')
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
        .width('100%').textAlign(TextAlign.Start)
      Text(`Will be created inside: ${this.currentPickerFolderName()}`)
        .fontSize(12).fontColor(this.theme.textSecondary)
        .width('100%').textAlign(TextAlign.Start)
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      TextInput({ text: this.vm.newFolderName, placeholder: 'Folder name' })
        .fontSize(15)
        .fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textTertiary)
        .backgroundColor(this.theme.chipBg)
        .onChange((value: string) => { this.vm.newFolderName = value; })
      Row({ space: 12 }) {
        Button('Cancel')
          .layoutWeight(1)
          .backgroundColor(this.theme.chipBg)
          .fontColor(this.theme.textPrimary)
          .onClick(() => { this.vm.cancelCreateFolder(); })
        Button(this.vm.isCreatingFolder ? 'Creating...' : 'Create')
          .layoutWeight(1)
          .backgroundColor(this.theme.primary)
          .fontColor(this.theme.primaryContrast)
          .enabled(!this.vm.isCreatingFolder)
          .onClick(() => { this.vm.performCreateFolder(); })
      }
      .width('100%')
    }
    .width('85%').padding(20)
    .backgroundColor(this.theme.surface)
    .borderRadius(16)
  }

  private currentPickerFolderName(): string {
    const crumbs: Crumb[] = this.vm.movePickerCrumbs;
    if (crumbs.length === 0) return 'Root';
    return crumbs[crumbs.length - 1].name;
  }

  // ===========================================================================
  // Activity panel
  // ===========================================================================

  @Builder
  buildActivityPanel() {
    Column() {
      Row()
        .width(40).height(4).borderRadius(2).backgroundColor(this.theme.border)
        .margin({ top: 8, bottom: 12 })

      Row() {
        Text('Activity')
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
          .layoutWeight(1)
        Text('✕')
          .fontSize(18).fontColor(this.theme.textSecondary)
          .width(32).height(32).textAlign(TextAlign.Center)
          .onClick(() => { this.vm.closeActivityPanel(); })
      }
      .width('100%').padding({ left: 20, right: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      Divider().color(this.theme.divider)

      if (this.operations.length === 0) {
        Column({ space: 10 }) {
          Text('✓').fontSize(42).fontColor(this.theme.textTertiary)
          Text('No recent activity')
            .fontSize(14).fontColor(this.theme.textSecondary)
        }
        .width('100%').height(200).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 1 }) {
          ForEach(this.operations, (op: Operation) => {
            ListItem() { this.buildActivityRow(op) }
          }, (op: Operation) =>
          `${op.id}_${op.status}_${op.progress}_${op.batchIndex}_${op.errorMessage}`)
        }
        .width('100%').constraintSize({ maxHeight: 420 })
        .divider({ strokeWidth: 1, color: this.theme.divider })
      }

      if (this.hasAnyOps) {
        Divider().color(this.theme.divider)
        Row({ space: 6 }) {
          Button('Clear completed')
            .fontSize(11)
            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
            .backgroundColor(this.theme.chipBg)
            .fontColor(this.canClearCompleted
              ? this.theme.textPrimary : this.theme.textTertiary)
            .enabled(this.canClearCompleted)
            .onClick(() => { this.vm.clearCompletedOperations(); })

          Button('Clear all')
            .fontSize(11)
            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
            .backgroundColor(this.theme.chipBg)
            .fontColor(this.canClearAll
              ? this.theme.textPrimary : this.theme.textTertiary)
            .enabled(this.canClearAll)
            .onClick(() => { this.vm.clearFinishedOperations(); })

          Button('Force clear')
            .fontSize(11)
            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
            .backgroundColor(this.theme.errorSoft)
            .fontColor(this.theme.error)
            .onClick(() => { this.vm.forceClearAllOperations(); })
        }
        .width('100%').justifyContent(FlexAlign.SpaceBetween)
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
  buildActivityRow(op: Operation) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(operationItemKindIcon(op.itemKind))
          .fontSize(18).fontColor(this.theme.textSecondary)
        Text(operationTypeIcon(op.type))
          .fontSize(12).fontColor(this.theme.primary)
      }
      .width(32).alignItems(HorizontalAlign.Center)

      Column({ space: 3 }) {
        Text(op.itemName)
          .fontSize(14).fontColor(this.theme.textPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Start).width('100%')

        Row({ space: 6 }) {
          Text(operationTypeLabel(op.type))
            .fontSize(11).fontColor(this.theme.textSecondary)
          if (op.batchTotal > 0) {
            Text(`· ${op.batchIndex} of ${op.batchTotal}`)
              .fontSize(11).fontColor(this.theme.textSecondary)
          }
          Text(`· ${operationStatusLabel(op.status)}`)
            .fontSize(11).fontColor(this.statusColor(op.status))
        }

        if (op.status === OperationStatus.RUNNING && op.progress >= 0) {
          Progress({ value: op.progress, total: 100, type: ProgressType.Linear })
            .color(this.theme.primary).width('100%').height(3).margin({ top: 4 })
        }

        if (op.status === OperationStatus.FAILED && op.errorMessage.length > 0) {
          Text(op.errorMessage)
            .fontSize(11).fontColor(this.theme.error)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)

      if (isActiveStatus(op.status)) {
        LoadingProgress().width(18).height(18).color(this.theme.primary)
      } else if (op.status === OperationStatus.SUCCESS) {
        Text('✓').fontSize(18).fontColor(this.theme.success)
      } else if (op.status === OperationStatus.FAILED) {
        Text('!').fontSize(18).fontColor(this.theme.error).fontWeight(FontWeight.Bold)
      } else {
        Text('—').fontSize(16).fontColor(this.theme.textTertiary)
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  private statusColor(status: OperationStatus): string {
    switch (status) {
      case OperationStatus.RUNNING: return this.theme.primary;
      case OperationStatus.SUCCESS: return this.theme.success;
      case OperationStatus.FAILED: return this.theme.error;
      default: return this.theme.textSecondary;
    }
  }

  // ===========================================================================
  // Sidebar
  // ===========================================================================

  @Builder
  buildSidebar() {
    Column() {
      Column({ space: 4 }) {
        Text('CLDrive')
          .fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
        Text('Cloud file manager')
          .fontSize(12).fontColor(this.theme.textSecondary)
      }
      .alignItems(HorizontalAlign.Start).width('100%')
      .padding({ left: 20, right: 20, top: 32, bottom: 20 })

      Divider().color(this.theme.divider)

      Text('ACCOUNTS')
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
      this.buildAddAccountRow()
      Divider().color(this.theme.divider)
      this.buildSettingsRow()
      Divider().color(this.theme.divider)
      if (this.vm.activeAccount !== null) {
        this.buildSignOutRow()
        Divider().color(this.theme.divider)
      }
      this.buildExitRow()
    }
    .width(280).height('100%')
    .backgroundColor(this.theme.surface)
  }

  @Builder
  buildAddAccountRow() {
    Row({ space: 12 }) {
      Text('+').fontSize(18).fontColor(this.theme.primary)
        .width(32).textAlign(TextAlign.Center)
      Text('Add account').fontSize(15).fontColor(this.theme.primary).layoutWeight(1)
      Text('›').fontSize(20).fontColor(this.theme.primary)
    }
    .width('100%').padding({ left: 16, right: 20, top: 16, bottom: 16 })
    .onClick(() => { this.vm.onAddAccount(); })
  }

  @Builder
  buildSettingsRow() {
    Row({ space: 12 }) {
      Text('⚙').fontSize(18).fontColor(this.theme.textPrimary)
        .width(32).textAlign(TextAlign.Center)
      Text('Settings').fontSize(15).fontColor(this.theme.textPrimary).layoutWeight(1)
      Text('›').fontSize(20).fontColor(this.theme.textTertiary)
    }
    .width('100%').padding({ left: 16, right: 20, top: 16, bottom: 16 })
    .onClick(() => {
      this.vm.closeSidebar();
      router.pushUrl({ url: Routes.SETTINGS })
        .catch((e: Error) => { /* log */ });
    })
  }

  @Builder
  buildSignOutRow() {
    Row({ space: 12 }) {
      Text('⏻').fontSize(18).fontColor(this.theme.warning)
        .width(32).textAlign(TextAlign.Center)
      Text('Sign out').fontSize(15).fontColor(this.theme.warning).layoutWeight(1)
      Text('›').fontSize(20).fontColor(this.theme.warning)
    }
    .width('100%').padding({ left: 16, right: 20, top: 16, bottom: 16 })
    .onClick(() => { this.vm.onSignOut(); })
  }

  @Builder
  buildExitRow() {
    Row({ space: 12 }) {
      Text('✕').fontSize(18).fontColor(this.theme.error)
        .width(32).textAlign(TextAlign.Center)
      Text('Exit').fontSize(15).fontColor(this.theme.error).layoutWeight(1)
      Text('›').fontSize(20).fontColor(this.theme.error)
    }
    .width('100%').padding({ left: 16, right: 20, top: 16, bottom: 16 })
    .onClick(() => { this.vm.onExitApp(); })
  }

  @Builder
  buildProviderHeader(group: ProviderGroup) {
    Row({ space: 10 }) {
      Text(this.vm.isExpanded(group.type) ? '▾' : '▸')
        .fontSize(14).fontColor(this.theme.textSecondary)
        .width(16).textAlign(TextAlign.Center)
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
    .onClick(() => { this.vm.toggleExpanded(group.type); })
  }

  @Builder
  buildAccountChildRow(account: AccountInfo) {
    Row({ space: 10 }) {
      Column().width(2).height(36)
        .backgroundColor(this.theme.border)
        .margin({ left: 15, right: 4 })
      Column() {
        Text(FileBrowserViewModel.initialOf(account))
          .fontSize(13).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
      }
      .width(30).height(30).borderRadius(15)
      .backgroundColor(FileBrowserViewModel.colorForProvider(account.provider))
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
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
      .alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (account.accountId === this.vm.activeAccountId) {
        Text('✓').fontSize(16).fontColor(this.theme.primary)
      }
    }
    .width('100%').padding({ left: 0, right: 16, top: 8, bottom: 8 })
    .backgroundColor(account.accountId === this.vm.activeAccountId
      ? this.theme.chipSelectedBg
      : Color.Transparent)
    .onClick(() => { this.vm.onSwitchAccount(account.accountId); })
  }
}
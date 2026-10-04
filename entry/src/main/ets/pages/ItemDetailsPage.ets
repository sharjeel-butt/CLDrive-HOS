import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { fileUri } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { CloudProviderFactory } from '../core/providers/CloudProviderFactory';
import { CloudProviderType } from '../core/models/CloudProviderType';
import { ICloudProvider } from '../core/interfaces/ICloudProvider';
import { CloudItem } from '../core/models/CloudItem';
import { CloudItemType } from '../core/models/CloudItemType';
import { AccountInfo } from '../core/models/AccountInfo';
import { AuthManager } from '../core/auth/AuthManager';
import { DownloadInfo } from '../core/models/DownloadInfo';
import {
  OperationType, OperationItemKind, RetryPayload
} from '../core/models/Operation';
import { OperationTracker } from '../core/services/OperationTracker';
import { OfflineStore, OfflineFileRecord } from '../core/services/OfflineStore';
import { FilePreviewer } from '../core/services/FilePreviewer';
import { ThemeManager } from '../core/theme/ThemeManager';
import { ThemeColors } from '../core/theme/ThemeColors';
import { t, tNamed } from '../core/i18n/I18n';
import { formatError } from '../utils/ErrorFormatter';
import { Logger } from '../utils/Logger';
import { FileIcon } from '../components/FileIcon';

const TAG: string = 'ItemDetailsPage';

const ACTION_DELETE: number = 0;
const ACTION_DOWNLOAD: number = 1;
const ACTION_MOVE: number = 2;
const ACTION_OPEN: number = 3;

const SIZE_HEADER_ICON = 24;
const SIZE_ACTION_ICON = 28;
const SIZE_NAME_EDIT_ICON = 22;
const SIZE_PICKER_BACK = 24;
const SIZE_PICKER_ROW_ICON = 22;
const SIZE_PICKER_CHEVRON = 18;

interface DetailsParams {
  accountId: string;
  itemId: string;
}

interface FolderCrumb {
  id: string;
  name: string;
}

@Entry
@Component
struct ItemDetailsPage {
  @State private accountId: string = '';
  @State private itemId: string = '';
  @State private item: CloudItem | null = null;
  @State private isLoading: boolean = true;
  @State private errorMessage: string = '';

  @State private isOffline: boolean = false;
  @State private offlineBusy: boolean = false;

  @State private showRenameDialog: boolean = false;
  @State private renameText: string = '';
  @State private isProcessing: boolean = false;

  @State private isDownloading: boolean = false;
  @State private isOpening: boolean = false;

  @State private showMovePicker: boolean = false;
  @State private movePickerFolderId: string = 'root';
  @State private movePickerItems: CloudItem[] = [];
  @State private movePickerCrumbs: FolderCrumb[] = [];
  @State private movePickerLoading: boolean = false;
  @State private movePickerError: string = '';

  @State private theme: ThemeColors = ThemeManager.get().colors();
  @StorageLink('languageVersion') langVersion: number = 0;

  private cloudProvider: ICloudProvider | null = null;
  private context: common.UIAbilityContext | null = null;

  private onThemeChanged = (): void => {
    this.theme = ThemeManager.get().colors();
  };

  aboutToAppear(): void {
    this.theme = ThemeManager.get().colors();
    ThemeManager.get().subscribe(this.onThemeChanged);
    this.context = getContext(this) as common.UIAbilityContext;
    this.readParams();
    this.loadItem();
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

  build() {
    Stack() {
      Column() {
        this.buildHeader()
        this.buildContent()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme.background)

      if (this.showRenameDialog) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.theme.overlay)
            .onClick(() => { this.showRenameDialog = false; })
          this.buildRenameDialog()
        }
        .width('100%')
        .height('100%')
      }

      if (this.showMovePicker) {
        this.buildMovePicker()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildHeader() {
    Row({ space: 12 }) {
      Row() {
        this.appIcon($r('app.media.ic_back'), SIZE_HEADER_ICON, this.theme.textPrimary)
      }
      .width(40).height(40)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { router.back(); })

      Text(t('details.title'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textPrimary)
        .layoutWeight(1)

      Row().width(40)
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 12, bottom: 12 })
    .backgroundColor(this.theme.background)
    .border({ width: { bottom: 1 }, color: this.theme.divider })
  }

  @Builder
  buildContent() {
    if (this.isLoading) {
      Column({ space: 12 }) {
        LoadingProgress().width(36).height(36).color(this.theme.primary)
        Text(t('details.loading'))
          .fontSize(13).fontColor(this.theme.textSecondary)
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .width('100%')
    } else if (this.errorMessage.length > 0 || this.item === null) {
      Column({ space: 12 }) {
        Text(t('details.couldNotLoad'))
          .fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textPrimary)
        Text(this.errorMessage)
          .fontSize(13).fontColor(this.theme.textSecondary)
          .textAlign(TextAlign.Center)
        Button(t('common.retry')).onClick(() => { this.loadItem(); })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding(24)
      .width('100%')
    } else {
      Scroll() {
        Column() {
          this.buildIconSection()
          this.buildActionButtons()
          this.buildNameRow()
          this.buildOfflineRow()
          Divider().color(this.theme.divider).margin({ top: 8 })
          this.buildMetadata()
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
  }

  @Builder
  buildIconSection() {
    Column() {
      if (this.item !== null && this.item.type === CloudItemType.FOLDER) {
        Stack({ alignContent: Alignment.TopStart }) {
          Column()
            .width(120)
            .height(88)
            .backgroundColor(this.theme.warning)
            .borderRadius(10)
            .margin({ top: 18, left: 10 })

          Column()
            .width(56)
            .height(18)
            .backgroundColor(this.theme.warningSoft)
            .borderRadius({
              topLeft: 10,
              topRight: 6,
              bottomLeft: 0,
              bottomRight: 0
            })
            .margin({ top: 2, left: 10 })

          if (this.item.childCount !== undefined && this.item.childCount > 0) {
            Text(`${this.item.childCount}`)
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.background)
              .margin({ top: 62, left: 26 })
          }
        }
        .width(140)
        .height(120)
      }

      if (this.item !== null && this.item.type === CloudItemType.FILE) {
        Stack({ alignContent: Alignment.Center }) {
          FileIcon({
            fileName: this.item.name,
            mimeType: this.item.mimeType !== undefined ? this.item.mimeType : '',
            badgeSize: 120
          })

          if (this.isOpening) {
            Column()
              .width(120).height(120)
              .borderRadius(26)
              .backgroundColor(this.theme.overlay)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            LoadingProgress().width(36).height(36).color('#FFFFFF')
              .position({ x: 42, y: 42 })
          }
        }
        .width(120)
        .height(120)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ top: 16, bottom: 28 })
    .onClick(() => {
      if (this.item !== null && this.item.type === CloudItemType.FILE) {
        this.onOpen();
      }
    })
  }

  @Builder
  buildActionButtons() {
    Row() {
      if (this.item !== null && this.item.type === CloudItemType.FILE) {
        this.buildActionButton($r('app.media.ic_open'),
          t('details.open'), ACTION_OPEN, true)
      }
      this.buildActionButton($r('app.media.ic_delete'),
        t('details.delete'), ACTION_DELETE, true)
      this.buildActionButton($r('app.media.ic_download'),
        t('details.download'), ACTION_DOWNLOAD, this.canDownload())
      this.buildActionButton($r('app.media.ic_move'),
        t('details.move'), ACTION_MOVE, true)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .margin({ bottom: 32 })
  }

  @Builder
  buildActionButton(
    iconRes: Resource,
    label: string,
    action: number,
    enabled: boolean
  ) {
    Column({ space: 8 }) {
      if ((action === ACTION_DOWNLOAD && this.isDownloading)
        || (action === ACTION_OPEN && this.isOpening)) {
        LoadingProgress().width(SIZE_ACTION_ICON).height(SIZE_ACTION_ICON)
          .color(this.theme.primary)
      } else {
        this.appIcon(iconRes, SIZE_ACTION_ICON,
          enabled ? this.theme.textPrimary : this.theme.textTertiary)
      }

      Text(label)
        .fontSize(13)
        .fontColor(enabled ? this.theme.textPrimary : this.theme.textTertiary)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (!enabled) {
        promptAction.showToast({ message: t('details.notAvailableFolders') });
        return;
      }
      if (action === ACTION_OPEN) {
        this.onOpen();
      } else if (action === ACTION_DELETE) {
        this.onDelete();
      } else if (action === ACTION_DOWNLOAD) {
        this.onDownload();
      } else if (action === ACTION_MOVE) {
        this.onMove();
      }
    })
  }

  @Builder
  buildNameRow() {
    Row() {
      Text(this.item !== null ? this.item.name : '')
        .fontSize(18)
        .fontColor(this.theme.textPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Row() {
        this.appIcon($r('app.media.ic_edit'),
          SIZE_NAME_EDIT_ICON, this.theme.textSecondary)
      }
      .width(40).height(40)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.openRenameDialog(); })
    }
    .width('100%')
    .padding({ left: 20, right: 16, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  buildOfflineRow() {
    Row({ space: 12 }) {
      Text(t('details.makeOffline'))
        .fontSize(16)
        .fontColor(this.item !== null && this.item.type === CloudItemType.FILE
          ? this.theme.textPrimary
          : this.theme.textTertiary)
        .layoutWeight(1)

      if (this.offlineBusy) {
        LoadingProgress().width(22).height(22).color(this.theme.primary)
      } else {
        Toggle({ type: ToggleType.Switch, isOn: this.isOffline })
          .selectedColor(this.theme.primary)
          .enabled(this.item !== null
            && this.item.type === CloudItemType.FILE
            && !this.offlineBusy)
          .onChange((isOn: boolean) => {
            if (this.item === null) return;
            if (isOn === this.isOffline) return;
            if (this.item.type !== CloudItemType.FILE) {
              promptAction.showToast({ message: t('fb.offlineFolder') });
              return;
            }
            this.onToggleOffline(isOn);
          })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  buildMetadata() {
    Column() {
      this.buildMetadataRow(t('details.size'), this.sizeLabel())
      Divider().color(this.theme.divider).margin({ left: 20 })
      this.buildMetadataRow(t('details.created'), this.dateLabel(this.item?.createdAt))
      Divider().color(this.theme.divider).margin({ left: 20 })
      this.buildMetadataRow(t('details.modified'), this.dateLabel(this.item?.modifiedAt))
    }
    .width('100%')
    .padding({ top: 8 })
  }

  @Builder
  buildMetadataRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(this.theme.textPrimary)
        .layoutWeight(1)

      Text(value)
        .fontSize(15)
        .fontColor(this.theme.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 18 })
  }

  @Builder
  buildRenameDialog() {
    Column({ space: 16 }) {
      Text(t('fb.renameTitle'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textPrimary)
        .width('100%')
        .textAlign(TextAlign.Start)

      TextInput({ text: this.renameText, placeholder: t('fb.renamePlaceholder') })
        .fontSize(15)
        .fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textTertiary)
        .backgroundColor(this.theme.chipBg)
        .onChange((value: string) => { this.renameText = value; })

      Row({ space: 12 }) {
        Button(t('common.cancel'))
          .layoutWeight(1)
          .backgroundColor(this.theme.chipBg)
          .fontColor(this.theme.textPrimary)
          .onClick(() => { this.showRenameDialog = false; })

        Button(this.isProcessing ? t('fb.renaming') : t('fb.rename'))
          .layoutWeight(1)
          .backgroundColor(this.theme.primary)
          .fontColor(this.theme.primaryContrast)
          .enabled(!this.isProcessing)
          .onClick(() => { this.performRename(); })
      }
      .width('100%')
    }
    .width('85%').padding(20)
    .backgroundColor(this.theme.surface).borderRadius(16)
  }

  @Builder
  buildMovePicker() {
    Column() {
      Row({ space: 12 }) {
        Row() {
          this.appIcon($r('app.media.ic_back'), SIZE_PICKER_BACK, this.theme.textPrimary)
        }
        .width(36).height(36)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.closeMovePicker(); })

        Text(t('fb.pickDestMove'))
          .fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Start).layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 16, top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.theme.background)
      .border({ width: { bottom: 1 }, color: this.theme.divider })

      Row() {
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.movePickerCrumbs, (crumb: FolderCrumb, index: number) => {
              Row({ space: 6 }) {
                Text(crumb.name)
                  .fontSize(12)
                  .fontWeight(index === this.movePickerCrumbs.length - 1
                    ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(index === this.movePickerCrumbs.length - 1
                    ? this.theme.textPrimary : this.theme.primary)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .textAlign(TextAlign.Start)
                  .onClick(() => { this.pickerGoToCrumb(index); })
                if (index < this.movePickerCrumbs.length - 1) {
                  this.appIcon($r('app.media.ic_chevron_right'),
                    12, this.theme.textTertiary)
                }
              }
            }, (crumb: FolderCrumb) => crumb.id)
          }
          .height(24).padding({ left: 16, right: 16 })
        }
        .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        .align(Alignment.Start).width('100%')
      }
      .width('100%').padding({ top: 10, bottom: 10 })
      .backgroundColor(this.theme.background)

      Divider().color(this.theme.divider)

      if (this.movePickerLoading) {
        Column({ space: 12 }) {
          LoadingProgress().width(32).height(32).color(this.theme.primary)
          Text(t('fb.loadingFolders'))
            .fontSize(13).fontColor(this.theme.textSecondary)
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else if (this.movePickerError.length > 0) {
        Column({ space: 12 }) {
          Text(t('fb.couldNotLoadFolders'))
            .fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor(this.theme.textPrimary)
          Text(this.movePickerError)
            .fontSize(13).fontColor(this.theme.textSecondary)
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).padding(24).width('100%')
      } else if (this.movePickerItems.length === 0) {
        Column({ space: 10 }) {
          this.appIcon($r('app.media.ic_folder'), 48, this.theme.textTertiary)
          Text(t('fb.noSubfolders'))
            .fontSize(14).fontColor(this.theme.textSecondary)
          Text(t('fb.noSubfoldersHint'))
            .fontSize(12).fontColor(this.theme.textTertiary)
            .textAlign(TextAlign.Center).padding({ left: 32, right: 32 })
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else {
        List({ space: 1 }) {
          ForEach(this.movePickerItems, (folder: CloudItem) => {
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
                  SIZE_PICKER_CHEVRON, this.theme.textTertiary)
              }
              .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .alignItems(VerticalAlign.Center)
              .backgroundColor(this.theme.surface)
              .onClick(() => { this.pickerOpenFolder(folder); })
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
          .onClick(() => { this.closeMovePicker(); })

        Button(this.isProcessing ? t('fb.moving') : t('fb.moveHere'))
          .layoutWeight(1)
          .backgroundColor(this.isProcessing
            ? this.theme.border : this.theme.primary)
          .fontColor(this.theme.primaryContrast)
          .enabled(!this.isProcessing)
          .onClick(() => { this.performMove(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 20 })
      .backgroundColor(this.theme.background)
      .border({ width: { top: 1 }, color: this.theme.divider })
    }
    .width('100%').height('100%')
    .backgroundColor(this.theme.background)
  }

  // ===========================================================================
  // Params / load
  // ===========================================================================

  private readParams(): void {
    const raw: DetailsParams = router.getParams() as DetailsParams;
    if (raw === null || raw === undefined) return;
    if (raw.accountId !== undefined && raw.accountId !== null) {
      this.accountId = raw.accountId;
    }
    if (raw.itemId !== undefined && raw.itemId !== null) {
      this.itemId = raw.itemId;
    }
  }

  private async loadItem(): Promise<void> {
    if (this.accountId.length === 0 || this.itemId.length === 0) {
      this.errorMessage = t('details.missingInfo');
      this.isLoading = false;
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';
    try {
      const account: AccountInfo | null =
        await AuthManager.findAccount(this.accountId);
      if (account === null) {
        this.errorMessage = t('details.couldNotLoad');
        this.isLoading = false;
        return;
      }

      const type: CloudProviderType = account.provider;
      this.cloudProvider = CloudProviderFactory.getProvider(this.accountId, type);

      const loaded: CloudItem = await this.cloudProvider.getItem(this.itemId);
      this.item = loaded;

      await this.loadOfflineStatus();
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `loadItem failed: ${err.message}`);
      this.errorMessage = formatError(err);
    } finally {
      this.isLoading = false;
    }
  }

  private async loadOfflineStatus(): Promise<void> {
    if (this.item === null) return;
    const record: OfflineFileRecord | null =
      await OfflineStore.getById(this.item.id);
    if (record === null) {
      this.isOffline = false;
      return;
    }
    try {
      fs.accessSync(record.localPath);
      this.isOffline = true;
    } catch (_) {
      await OfflineStore.remove(this.item.id);
      this.isOffline = false;
    }
  }

  private canDownload(): boolean {
    return this.item !== null && this.item.type === CloudItemType.FILE;
  }

  private sizeLabel(): string {
    if (this.item === null) return '—';
    if (this.item.type === CloudItemType.FOLDER) {
      if (this.item.childCount !== undefined) {
        const n: number = this.item.childCount;
        return n === 1
          ? `1 ${t('details.item')}`
          : `${n} ${t('details.items')}`;
      }
      return '—';
    }
    if (this.item.size === undefined) return '—';
    return this.formatSize(this.item.size);
  }

  private dateLabel(ms: number | undefined): string {
    if (ms === undefined) return '—';
    const d = new Date(ms);
    const monthKeys: string[] = [
      'fb.month.jan', 'fb.month.feb', 'fb.month.mar', 'fb.month.apr',
      'fb.month.may', 'fb.month.jun', 'fb.month.jul', 'fb.month.aug',
      'fb.month.sep', 'fb.month.oct', 'fb.month.nov', 'fb.month.dec'
    ];
    const pad = (n: number): string => (n < 10 ? `0${n}` : `${n}`);
    const month: string = t(monthKeys[d.getMonth()]);
    return `${month} ${d.getDate()}, ${d.getFullYear()} ` +
      `${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
    }
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  }

  // ===========================================================================
  // Open
  // ===========================================================================

  private async onOpen(): Promise<void> {
    if (this.item === null || this.cloudProvider === null
      || this.context === null) return;
    if (this.item.type !== CloudItemType.FILE) return;
    if (this.isOpening) return;

    const ctx: common.UIAbilityContext = this.context;
    const provider: ICloudProvider = this.cloudProvider;

    if (this.isOffline) {
      try {
        await FilePreviewer.open(ctx, this.item, provider);
      } catch (e) {
        const readable: string = formatError(e as Error);
        Logger.error(TAG, `onOpen (offline) failed: ${readable}`);
        promptAction.showToast({
          message: `${t('fb.cannotOpen')}: ${readable}`
        });
      }
      return;
    }

    this.isOpening = true;
    try {
      await FilePreviewer.open(ctx, this.item, provider);
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `onOpen failed: ${readable}`);
      promptAction.showToast({
        message: `${t('fb.cannotOpen')}: ${readable}`
      });
    } finally {
      this.isOpening = false;
    }
  }

  // ===========================================================================
  // Rename
  // ===========================================================================

  private openRenameDialog(): void {
    if (this.item === null) return;
    this.renameText = this.item.name;
    this.showRenameDialog = true;
  }

  private async performRename(): Promise<void> {
    if (this.item === null || this.cloudProvider === null) return;

    const newName: string = this.renameText.trim();
    if (newName.length === 0) {
      promptAction.showToast({ message: t('fb.nameEmpty') });
      return;
    }
    if (newName === this.item.name) {
      this.showRenameDialog = false;
      return;
    }

    this.isProcessing = true;
    try {
      const updated: CloudItem =
        await this.cloudProvider.renameItem(this.item.id, newName);
      this.item = updated;
      this.showRenameDialog = false;
      promptAction.showToast({ message: t('details.renamed') });
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `rename failed: ${err.message}`);
      promptAction.showToast({
        message: `${t('details.renameFailed')}: ${formatError(err)}`
      });
    } finally {
      this.isProcessing = false;
    }
  }

  // ===========================================================================
  // Delete
  // ===========================================================================

  private onDelete(): void {
    if (this.item === null) return;
    const wasFolder: boolean = this.item.type === CloudItemType.FOLDER;
    const name: string = this.item.name;

    promptAction.showDialog({
      title: t('details.deleteTitle'),
      message: wasFolder
        ? tNamed('details.deleteMsgFolder', new Map([['name', name]]))
        : tNamed('details.deleteMsg', new Map([['name', name]])),
      buttons: [
        { text: t('common.cancel'), color: '#666666' },
        { text: t('details.delete'), color: '#D32F2F' }
      ]
    })
      .then((result: promptAction.ShowDialogSuccessResponse) => {
        if (result.index === 1) this.performDelete(name);
      })
      .catch((e: Error) => {
        Logger.error(TAG, `showDialog failed: ${e.message}`);
      });
  }

  private async performDelete(name: string): Promise<void> {
    if (this.item === null || this.cloudProvider === null) return;
    const id: string = this.item.id;

    try {
      await this.cloudProvider.deleteItem(id);
      const record: OfflineFileRecord | null = await OfflineStore.getById(id);
      if (record !== null) {
        try { fs.unlinkSync(record.localPath); } catch (_) { /* gone */ }
        await OfflineStore.remove(id);
      }
      promptAction.showToast({
        message: tNamed('details.deleted', new Map([['name', name]]))
      });
      router.back();
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `delete failed: ${err.message}`);
      promptAction.showToast({
        message: `${t('details.deleteFailed')}: ${formatError(err)}`
      });
    }
  }

  // ===========================================================================
  // Download
  // ===========================================================================

  private async onDownload(): Promise<void> {
    if (this.item === null || this.cloudProvider === null) return;
    if (this.item.type !== CloudItemType.FILE) {
      promptAction.showToast({ message: t('fb.onlyFilesDownload') });
      return;
    }
    if (this.isDownloading) return;

    const saveUri: string | null = await this.pickSaveLocation(this.item.name);
    if (saveUri === null) return;

    const tracker: OperationTracker = OperationTracker.get();
    const dlPayload: RetryPayload = { targetUri: saveUri };
    const opId: string = tracker.register(
      OperationType.DOWNLOAD, this.item.name, this.item.id,
      OperationItemKind.FILE, 0, 0, dlPayload
    );
    tracker.markRunning(opId);

    this.isDownloading = true;
    try {
      const info: DownloadInfo =
        await this.cloudProvider.getDownloadInfo(this.item.id);
      await this.downloadViaHttp(
        info, saveUri, this.item.name, this.item.id, opId
      );
      promptAction.showToast({
        message: `${t('fb.downloaded')}: ${this.item.name}`
      });
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `download failed: ${readable}`);
      promptAction.showToast({
        message: `${t('fb.downloadFailed')}: ${readable}`
      });
    } finally {
      this.isDownloading = false;
    }
  }

  private async pickSaveLocation(fileName: string): Promise<string | null> {
    if (this.context === null) return null;
    const ctx: common.UIAbilityContext = this.context;

    try {
      const p = new picker.DocumentViewPicker(ctx);
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [fileName];
      const result: string[] = await p.save(options);
      if (result === null || result === undefined || result.length === 0) {
        return null;
      }
      return result[0];
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.info(TAG, `pickSaveLocation cancelled: ${readable}`);
      return null;
    }
  }

  private async downloadViaHttp(
    info: DownloadInfo,
    targetUri: string,
    fileName: string,
    itemId: string,
    opId: string
  ): Promise<void> {
    if (this.context === null) throw new Error('Context not set');
    const ctx: common.UIAbilityContext = this.context;

    const tracker: OperationTracker = OperationTracker.get();
    const request = http.createHttp();
    const sandboxPath: string = `${ctx.cacheDir}/${fileName}`;

    try {
      const headerObj: Record<string, string> = {};
      info.headers.forEach((value: string, key: string): void => {
        Reflect.set(headerObj, key, value);
      });

      const requestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: headerObj,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: 120_000,
        connectTimeout: 30_000
      };

      const response = await request.request(info.url, requestOptions);

      if (response.responseCode < 200 || response.responseCode >= 300) {
        let errorBody: string = '';
        try {
          const buf: ArrayBuffer = response.result as ArrayBuffer;
          const decoder = new util.TextDecoder('utf-8');
          errorBody = decoder.decodeToString(new Uint8Array(buf));
        } catch (_) {
          errorBody = '(could not decode body)';
        }
        throw new Error(`HTTP ${response.responseCode}: ${errorBody}`);
      }

      const bytes: ArrayBuffer = response.result as ArrayBuffer;
      const sandboxFile = fs.openSync(
        sandboxPath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC
      );
      try {
        fs.writeSync(sandboxFile.fd, bytes);
      } finally {
        fs.closeSync(sandboxFile);
      }

      await this.copySandboxToDestination(sandboxPath, targetUri, fileName);

      tracker.markSuccess(opId);
      Logger.info(TAG, `Downloaded ${fileName} → ${targetUri}`);
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `downloadViaHttp failed for ${fileName}: ${readable}`);
      this.removeEmptyFile(targetUri);
      tracker.markFailed(opId, readable);
      throw new Error(readable);
    } finally {
      request.destroy();
      try {
        fs.accessSync(sandboxPath);
        fs.unlinkSync(sandboxPath);
      } catch (_) { /* already gone */ }
    }
  }

  private async copySandboxToDestination(
    sandboxPath: string,
    targetUri: string,
    fileName: string
  ): Promise<void> {
    let destFile: fs.File;
    try {
      const flags = fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC;
      if (targetUri.startsWith('file://')) {
        destFile = fs.openSync(targetUri, flags);
      } else {
        const resolved: string = new fileUri.FileUri(targetUri).path;
        destFile = fs.openSync(resolved, flags);
      }
    } catch (e) {
      const readable: string = formatError(e as Error);
      throw new Error(`Cannot open destination for "${fileName}": ${readable}`);
    }

    let srcFile: fs.File | null = null;
    try {
      const stat = fs.statSync(sandboxPath);
      const buffer = new ArrayBuffer(stat.size);

      srcFile = fs.openSync(sandboxPath, fs.OpenMode.READ_ONLY);
      fs.readSync(srcFile.fd, buffer);
      fs.closeSync(srcFile);
      srcFile = null;

      fs.writeSync(destFile.fd, buffer);
      Logger.info(TAG, `Wrote ${buffer.byteLength} bytes to ${targetUri}`);
    } catch (e) {
      const readable: string = formatError(e as Error);
      throw new Error(readable);
    } finally {
      if (srcFile !== null) {
        try { fs.closeSync(srcFile); } catch (_) { /* ignore */ }
      }
      try { fs.closeSync(destFile); } catch (_) { /* ignore */ }
    }
  }

  private removeEmptyFile(uri: string): void {
    try {
      const path: string = uri.startsWith('file://')
        ? uri.substring('file://'.length)
        : uri;
      const stat = fs.statSync(path);
      if (stat.size === 0) fs.unlinkSync(path);
    } catch (_) { /* ignore */ }
  }

  // ===========================================================================
  // Offline
  // ===========================================================================

  private async onToggleOffline(isOn: boolean): Promise<void> {
    if (this.item === null || this.cloudProvider === null) return;
    if (this.item.type !== CloudItemType.FILE) {
      promptAction.showToast({ message: t('fb.offlineFolder') });
      return;
    }

    this.offlineBusy = true;
    try {
      if (isOn) {
        await this.saveForOffline(this.item);
      } else {
        await this.removeFromOffline(this.item);
      }
    } finally {
      this.offlineBusy = false;
    }
  }

  private async saveForOffline(item: CloudItem): Promise<void> {
    if (this.cloudProvider === null || this.context === null) return;

    const ctx: common.UIAbilityContext = this.context;
    const provider: ICloudProvider = this.cloudProvider;

    const tracker: OperationTracker = OperationTracker.get();
    const opId: string = tracker.register(
      OperationType.DOWNLOAD, item.name, item.id, OperationItemKind.FILE, 0, 0
    );
    tracker.markRunning(opId);

    try {
      const offlineDir: string = ctx.filesDir;
      const safeId: string = item.id.replace(/[^a-zA-Z0-9_-]/g, '_');
      const safeName: string = item.name.replace(/[^a-zA-Z0-9._-]/g, '_');
      const prefix: string =
        safeId.length > 32 ? safeId.substring(0, 32) : safeId;
      let trimmedName: string = safeName;
      if (trimmedName.length > 120) {
        const dot: number = safeName.lastIndexOf('.');
        if (dot > 0) {
          const base: string = safeName.substring(0, dot);
          const ext: string = safeName.substring(dot);
          trimmedName = `${base.substring(0, 120 - ext.length)}${ext}`;
        } else {
          trimmedName = safeName.substring(0, 120);
        }
      }
      const localPath: string = `${offlineDir}/${prefix}_${trimmedName}`;

      const info: DownloadInfo = await provider.getDownloadInfo(item.id);
      const bytes: ArrayBuffer = await this.fetchBytes(info, item.name);

      const f = fs.openSync(
        localPath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC
      );
      try {
        fs.writeSync(f.fd, bytes);
      } finally {
        fs.closeSync(f);
      }

      const record: OfflineFileRecord = {
        cloudId: item.id,
        accountId: this.accountId,
        provider: provider.providerType,
        name: item.name,
        localPath: localPath,
        mimeType: item.mimeType !== undefined ? item.mimeType : '',
        size: item.size !== undefined ? item.size : bytes.byteLength,
        downloadedAt: Date.now()
      };
      await OfflineStore.add(record);

      this.isOffline = true;
      tracker.markSuccess(opId);
      promptAction.showToast({
        message: tNamed('fb.offlineAdded', new Map([['name', item.name]]))
      });
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `saveForOffline failed: ${readable}`);
      tracker.markFailed(opId, readable);
      promptAction.showToast({
        message: `${t('fb.offlineFailed')}: ${readable}`
      });
    }
  }

  private async removeFromOffline(item: CloudItem): Promise<void> {
    const record: OfflineFileRecord | null =
      await OfflineStore.getById(item.id);

    if (record !== null) {
      try {
        fs.unlinkSync(record.localPath);
      } catch (e) {
        const readable: string = formatError(e as Error);
        Logger.warn(TAG, `Failed to delete offline file: ${readable}`);
      }
    }

    await OfflineStore.remove(item.id);
    this.isOffline = false;

    promptAction.showToast({
      message: tNamed('fb.offlineRemoved', new Map([['name', item.name]]))
    });
  }

  private async fetchBytes(
    info: DownloadInfo,
    label: string
  ): Promise<ArrayBuffer> {
    const request = http.createHttp();
    try {
      const headerObj: Record<string, string> = {};
      info.headers.forEach((value: string, key: string): void => {
        Reflect.set(headerObj, key, value);
      });

      const opts: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: headerObj,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: 120_000,
        connectTimeout: 30_000
      };

      const response = await request.request(info.url, opts);
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode} for ${label}`);
      }
      return response.result as ArrayBuffer;
    } finally {
      request.destroy();
    }
  }

  // ===========================================================================
  // Move
  // ===========================================================================

  private onMove(): void {
    if (this.item === null || this.cloudProvider === null) return;
    this.openMovePicker();
  }

  private openMovePicker(): void {
    this.showMovePicker = true;
    this.movePickerFolderId = 'root';
    this.movePickerError = '';
    this.movePickerCrumbs = [
      { id: 'root', name: t('fb.files') }
    ];
    this.loadPickerFolder('root');
  }

  private closeMovePicker(): void {
    this.showMovePicker = false;
    this.movePickerItems = [];
    this.movePickerCrumbs = [];
    this.movePickerError = '';
  }

  private async loadPickerFolder(folderId: string): Promise<void> {
    if (this.cloudProvider === null) return;
    this.movePickerLoading = true;
    this.movePickerError = '';
    try {
      const all: CloudItem[] = await this.cloudProvider.listChildren(folderId);
      const folders: CloudItem[] = [];
      for (let i = 0; i < all.length; i++) {
        const it: CloudItem = all[i];
        if (it.type !== CloudItemType.FOLDER) continue;
        if (this.item !== null && it.id === this.item.id) continue;
        folders.push(it);
      }
      this.movePickerItems = folders;
      this.movePickerFolderId = folderId;
    } catch (e) {
      const readable: string = formatError(e as Error);
      this.movePickerError = readable;
    } finally {
      this.movePickerLoading = false;
    }
  }

  private async pickerOpenFolder(folder: CloudItem): Promise<void> {
    this.movePickerCrumbs = [
      ...this.movePickerCrumbs,
      { id: folder.id, name: folder.name }
    ];
    await this.loadPickerFolder(folder.id);
  }

  private async pickerGoToCrumb(index: number): Promise<void> {
    if (index < 0 || index >= this.movePickerCrumbs.length) return;
    if (index === this.movePickerCrumbs.length - 1) return;
    const target: FolderCrumb = this.movePickerCrumbs[index];
    this.movePickerCrumbs = this.movePickerCrumbs.slice(0, index + 1);
    await this.loadPickerFolder(target.id);
  }

  private async performMove(): Promise<void> {
    if (this.item === null || this.cloudProvider === null) return;

    const targetId: string = this.movePickerFolderId;
    const itemId: string = this.item.id;
    const itemName: string = this.item.name;

    this.isProcessing = true;
    try {
      let finalName: string | undefined = undefined;
      const siblings: CloudItem[] =
        await this.cloudProvider.listChildren(targetId);
      for (let i = 0; i < siblings.length; i++) {
        if (siblings[i].name.toLowerCase() === itemName.toLowerCase()) {
          finalName = ItemDetailsPage.findAvailableName(itemName, siblings);
          break;
        }
      }

      const updated: CloudItem =
        await this.cloudProvider.moveItem(itemId, targetId, finalName);

      this.item = updated;
      this.closeMovePicker();
      promptAction.showToast({
        message: tNamed('fb.moved', new Map([['name', updated.name]]))
      });
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `move failed: ${readable}`);
      promptAction.showToast({
        message: `${t('fb.moveCancelled')}: ${readable}`
      });
    } finally {
      this.isProcessing = false;
    }
  }

  private static findAvailableName(
    original: string,
    siblings: CloudItem[]
  ): string {
    const taken: string[] = [];
    for (let i = 0; i < siblings.length; i++) {
      taken.push(siblings[i].name.toLowerCase());
    }

    const dot: number = original.lastIndexOf('.');
    const base: string = dot > 0 ? original.substring(0, dot) : original;
    const ext: string = dot > 0 ? original.substring(dot) : '';

    for (let i = 1; i < 10000; i++) {
      const candidate: string = `${base} (${i})${ext}`;
      if (taken.indexOf(candidate.toLowerCase()) < 0) {
        return candidate;
      }
    }
    return `${base} (${Date.now()})${ext}`;
  }
}
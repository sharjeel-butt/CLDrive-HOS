import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { CloudProviderFactory } from '../core/providers/CloudProviderFactory';
import { CloudProviderType } from '../core/models/CloudProviderType';
import { ICloudProvider } from '../core/interfaces/ICloudProvider';
import { CloudItem } from '../core/models/CloudItem';
import { CloudItemType } from '../core/models/CloudItemType';
import { AccountInfo } from '../core/models/AccountInfo';
import { AuthManager } from '../core/auth/AuthManager';
import { ThemeManager } from '../core/theme/ThemeManager';
import { ThemeColors } from '../core/theme/ThemeColors';
import { t, tNamed } from '../core/i18n/I18n';
import { Logger } from '../utils/Logger';
import { FileIcon } from '../components/FileIcon';

const TAG: string = 'ItemDetailsPage';

const ACTION_DELETE: number = 0;
const ACTION_DOWNLOAD: number = 1;
const ACTION_MOVE: number = 2;

interface DetailsParams {
  accountId: string;
  itemId: string;
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
  @State private isProcessing: boolean = false;
  @State private showRenameDialog: boolean = false;
  @State private renameText: string = '';

  @State private theme: ThemeColors = ThemeManager.get().colors();

  @StorageLink('languageVersion') langVersion: number = 0;

  private cloudProvider: ICloudProvider | null = null;

  private onThemeChanged = (): void => {
    this.theme = ThemeManager.get().colors();
  };

  aboutToAppear(): void {
    this.theme = ThemeManager.get().colors();
    ThemeManager.get().subscribe(this.onThemeChanged);
    this.readParams();
    this.loadItem();
  }

  aboutToDisappear(): void {
    ThemeManager.get().unsubscribe(this.onThemeChanged);
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
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildHeader() {
    Row({ space: 12 }) {
      Text('←')
        .fontSize(24)
        .fontColor(this.theme.textPrimary)
        .width(40)
        .textAlign(TextAlign.Center)
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
    .backgroundColor(this.theme.surface)
  }

  @Builder
  buildContent() {
    if (this.isLoading) {
      Column({ space: 12 }) {
        LoadingProgress().width(36).height(36).color(this.theme.primary)
        Text(t('details.loading')).fontSize(13).fontColor(this.theme.textSecondary)
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
            .backgroundColor('#F59E0B')
            .borderRadius(10)
            .margin({ top: 18, left: 10 })

          Column()
            .width(56)
            .height(18)
            .backgroundColor('#D97706')
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
              .fontColor('#78350F')
              .margin({ top: 62, left: 26 })
          }
        }
        .width(140)
        .height(120)
      }

      if (this.item !== null && this.item.type === CloudItemType.FILE) {
        FileIcon({
          fileName: this.item.name,
          mimeType: this.item.mimeType !== undefined ? this.item.mimeType : '',
          badgeSize: 120
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ top: 16, bottom: 28 })
  }

  @Builder
  buildActionButtons() {
    Row() {
      this.buildActionButton('🗑', t('details.delete'), ACTION_DELETE, true)
      this.buildActionButton('⬇', t('details.download'), ACTION_DOWNLOAD, this.canDownload())
      this.buildActionButton('→', t('details.move'), ACTION_MOVE, true)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .margin({ bottom: 32 })
  }

  @Builder
  buildActionButton(
    icon: string,
    label: string,
    action: number,
    enabled: boolean
  ) {
    Column({ space: 8 }) {
      Text(icon)
        .fontSize(28)
        .fontColor(enabled ? this.theme.textPrimary : this.theme.textTertiary)

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
      if (action === ACTION_DELETE) {
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

      Text('✎')
        .fontSize(22)
        .fontColor(this.theme.textSecondary)
        .width(40)
        .textAlign(TextAlign.Center)
        .onClick(() => { this.openRenameDialog(); })
    }
    .width('100%')
    .padding({ left: 20, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  buildOfflineRow() {
    Row() {
      Text(t('details.makeOffline'))
        .fontSize(16)
        .fontColor(this.theme.textPrimary)
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.isOffline })
        .selectedColor(this.theme.primary)
        .onChange((isOn: boolean) => {
          this.isOffline = isOn;
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 16 })
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

  // ---------------------------------------------------------------------------
  // Params / load
  // ---------------------------------------------------------------------------

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
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `loadItem failed: ${err.message}`);
      this.errorMessage = err.message;
    } finally {
      this.isLoading = false;
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
    const months: string[] = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const pad = (n: number): string => (n < 10 ? `0${n}` : `${n}`);
    const month: string = months[d.getMonth()];
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
        message: `${t('details.renameFailed')}: ${err.message}`
      });
    } finally {
      this.isProcessing = false;
    }
  }

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
      promptAction.showToast({
        message: tNamed('details.deleted', new Map([['name', name]]))
      });
      router.back();
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `delete failed: ${err.message}`);
      promptAction.showToast({
        message: `${t('details.deleteFailed')}: ${err.message}`
      });
    }
  }

  private async onDownload(): Promise<void> {
    if (this.item === null || this.cloudProvider === null) return;
    if (this.item.type !== CloudItemType.FILE) {
      promptAction.showToast({ message: t('fb.onlyFilesDownload') });
      return;
    }

    try {
      const context = getContext(this) as common.UIAbilityContext;
      const targetPath: string = `${context.cacheDir}/${this.item.name}`;
      await this.cloudProvider.downloadFile(this.item.id, targetPath);
      promptAction.showToast({
        message: `${t('details.downloadedToCache')} ${this.item.name}`
      });
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `download failed: ${err.message}`);
      promptAction.showToast({
        message: `${t('fb.downloadFailed')}: ${err.message}`
      });
    }
  }

  private onMove(): void {
    promptAction.showToast({ message: t('details.moveComingSoon') });
  }
}
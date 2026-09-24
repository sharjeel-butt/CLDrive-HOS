import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { CloudProviderFactory } from '../core/providers/CloudProviderFactory';
import { CloudProviderType } from '../core/models/CloudProviderType';
import { ICloudProvider } from '../core/interfaces/ICloudProvider';
import { CloudItem } from '../core/models/CloudItem';
import { CloudItemType } from '../core/models/CloudItemType';
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
  private cloudProvider: ICloudProvider | null = null;

  aboutToAppear(): void {
    this.readParams();
    this.loadItem();
  }

  build() {
    Stack() {
      Column() {
        this.buildHeader()
        this.buildContent()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')

      if (this.showRenameDialog) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#66000000')
            .onClick(() => {
              this.showRenameDialog = false;
            })

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
        .fontColor('#000000')
        .width(40)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          router.back();
        })

      Text('Details')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#000000')
        .layoutWeight(1)

      // Blank slot keeps the title left-aligned with the row.
      Row().width(40)
    }
    .width('100%')
    .padding({
      left: 8,
      right: 8,
      top: 12,
      bottom: 12
    })
    .backgroundColor(Color.White)
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @Builder
  buildContent() {
    if (this.isLoading) {
      Column({ space: 12 }) {
        LoadingProgress().width(36).height(36)
        Text('Loading...').fontSize(13).fontColor('#666666')
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .width('100%')
    } else if (this.errorMessage.length > 0 || this.item === null) {
      Column({ space: 12 }) {
        Text('Could not load details').fontSize(16).fontWeight(FontWeight.Bold)
        Text(this.errorMessage).fontSize(13).fontColor('#666666')
          .textAlign(TextAlign.Center)
        Button('Retry').onClick(() => {
          this.loadItem();
        })
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
          Divider().color('#EEEEEE').margin({ top: 8 })
          this.buildMetadata()
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
  }

  // ---------------------------------------------------------------------------
  // Header — back arrow + "Details" title, nothing else
  // ---------------------------------------------------------------------------

  @Builder
  buildIconSection() {
    Column() {
      // Folder: yellow folder graphic with count badge
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

      // File: large type-specific badge
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

  // ---------------------------------------------------------------------------
  // Content
  // ---------------------------------------------------------------------------

  @Builder
  buildActionButtons() {
    Row() {
      this.buildActionButton('🗑', 'Delete', ACTION_DELETE, true)
      this.buildActionButton('⬇', 'Download', ACTION_DOWNLOAD, this.canDownload())
      this.buildActionButton('→', 'Move', ACTION_MOVE, true)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .margin({ bottom: 32 })
  }

  // ---------------------------------------------------------------------------
  // Icon with count badge (folders) or file glyph
  // ---------------------------------------------------------------------------

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
        .fontColor(enabled ? '#333333' : '#CCCCCC')

      Text(label)
        .fontSize(13)
        .fontColor(enabled ? '#333333' : '#CCCCCC')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (!enabled) {
        promptAction.showToast({ message: 'Not available for folders' });
        return;
      }
      if (action === ACTION_DELETE) {
        this.onDelete();
      } else if (action ===
        ACTION_DOWNLOAD) {
        this.onDownload();
      } else if (action === ACTION_MOVE) {
        this.onMove();
      }
    })
  }

  // ---------------------------------------------------------------------------
  // Three action buttons: Delete · Download · Move
  // ---------------------------------------------------------------------------

  @Builder
  buildNameRow() {
    Row() {
      Text(this.item !== null ? this.item.name : '')
        .fontSize(18)
        .fontColor('#000000')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Text('✎')
        .fontSize(22)
        .fontColor('#666666')
        .width(40)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.openRenameDialog();
        })
    }
    .width('100%')
    .padding({
      left: 20,
      right: 16,
      top: 12,
      bottom: 12
    })
  }

  @Builder
  buildOfflineRow() {
    Row() {
      Text('Make available offline')
        .fontSize(16)
        .fontColor('#000000')
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.isOffline })
        .selectedColor('#0078D4')
        .onChange((isOn: boolean) => {
          this.isOffline = isOn;
          // Persisting and wiring to @ohos.file.cloudSync is a future milestone.
        })
    }
    .width('100%')
    .padding({
      left: 20,
      right: 20,
      top: 12,
      bottom: 16
    })
  }

  @Builder
  buildMetadata() {
    Column() {
      this.buildMetadataRow('Size', this.sizeLabel())
      Divider().color('#F0F0F0').margin({ left: 20 })
      this.buildMetadataRow('Created', this.dateLabel(this.item?.createdAt))
      Divider().color('#F0F0F0').margin({ left: 20 })
      this.buildMetadataRow('Modified', this.dateLabel(this.item?.modifiedAt))
    }
    .width('100%')
    .padding({ top: 8 })
  }

  // ---------------------------------------------------------------------------
  // Name row (with rename icon)
  // ---------------------------------------------------------------------------

  @Builder
  buildMetadataRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor('#333333')
        .layoutWeight(1)

      Text(value)
        .fontSize(15)
        .fontColor('#666666')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({
      left: 20,
      right: 20,
      top: 18,
      bottom: 18
    })
  }

  // ---------------------------------------------------------------------------
  // Offline toggle
  // ---------------------------------------------------------------------------

  @Builder
  buildRenameDialog() {
    Column({ space: 16 }) {
      Text('Rename')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#000000')
        .width('100%')
        .textAlign(TextAlign.Start)

      TextInput({ text: this.renameText, placeholder: 'New name' })
        .fontSize(15)
        .onChange((value: string) => {
          this.renameText = value;
        })

      Row({ space: 12 }) {
        Button('Cancel')
          .layoutWeight(1)
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .onClick(() => {
            this.showRenameDialog = false;
          })

        Button(this.isProcessing ? 'Renaming...' : 'Rename')
          .layoutWeight(1)
          .backgroundColor('#0078D4')
          .fontColor(Color.White)
          .enabled(!this.isProcessing)
          .onClick(() => {
            this.performRename();
          })
      }
      .width('100%')
    }
    .width('85%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  // ---------------------------------------------------------------------------
  // Metadata rows
  // ---------------------------------------------------------------------------

  private readParams(): void {
    const raw: object = router.getParams();
    if (raw === null || raw === undefined) {
      return;
    }

    const acc = Reflect.get(raw, 'accountId') as string;
    const itm = Reflect.get(raw, 'itemId') as string;

    if (acc !== undefined) {
      this.accountId = acc;
    }
    if (itm !== undefined) {
      this.itemId = itm;
    }
  }

  private async loadItem(): Promise<void> {
    if (this.accountId.length === 0 || this.itemId.length === 0) {
      this.errorMessage = 'Missing item information.';
      this.isLoading = false;
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';
    try {
      const type: CloudProviderType = CloudProviderType.ONEDRIVE;
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
    if (this.item === null) {
      return '—';
    }
    if (this.item.type === CloudItemType.FOLDER) {
      if (this.item.childCount !== undefined) {
        const n: number = this.item.childCount;
        return n === 1 ? '1 item' : `${n} items`;
      }
      return '—';
    }
    if (this.item.size === undefined) {
      return '—';
    }
    return this.formatSize(this.item.size);
  }

  private dateLabel(ms: number | undefined): string {
    if (ms === undefined) {
      return '—';
    }
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

  // ---------------------------------------------------------------------------
  // Rename dialog
  // ---------------------------------------------------------------------------

  private formatSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    }
    if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
    }
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  }

  private openRenameDialog(): void {
    if (this.item === null) {
      return;
    }
    this.renameText = this.item.name;
    this.showRenameDialog = true;
  }

  private async performRename(): Promise<void> {
    if (this.item === null || this.cloudProvider === null) {
      return;
    }

    const newName: string = this.renameText.trim();
    if (newName.length === 0) {
      promptAction.showToast({ message: 'Name cannot be empty' });
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
      promptAction.showToast({ message: 'Renamed' });
      Logger.info(TAG, `Renamed ${updated.id} → ${newName}`);
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `rename failed: ${err.message}`);
      promptAction.showToast({ message: `Rename failed: ${err.message}` });
    } finally {
      this.isProcessing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  private onDelete(): void {
    if (this.item === null) {
      return;
    }
    const wasFolder: boolean = this.item.type === CloudItemType.FOLDER;
    const name: string = this.item.name;

    promptAction.showDialog({
      title: 'Delete',
      message: `Delete "${name}"?${wasFolder
        ? ' Its contents will be deleted too.'
        : ''} This cannot be undone.`,
      buttons: [
        { text: 'Cancel', color: '#666666' },
        { text: 'Delete', color: '#D32F2F' }
      ]
    })
      .then((result: promptAction.ShowDialogSuccessResponse) => {
        if (result.index === 1) {
          this.performDelete(name);
        }
      })
      .catch((e: Error) => {
        Logger.error(TAG, `showDialog failed: ${e.message}`);
      });
  }

  private async performDelete(name: string): Promise<void> {
    if (this.item === null || this.cloudProvider === null) {
      return;
    }
    const id: string = this.item.id;

    try {
      await this.cloudProvider.deleteItem(id);
      Logger.info(TAG, `Deleted ${id}`);
      promptAction.showToast({ message: `"${name}" deleted` });
      // Give the toast a moment, then return to the browser which will
      // refresh its folder listing via onPageShow.
      router.back();
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `delete failed: ${err.message}`);
      promptAction.showToast({ message: `Delete failed: ${err.message}` });
    }
  }

  private async onDownload(): Promise<void> {
    if (this.item === null || this.cloudProvider === null) {
      return;
    }
    if (this.item.type !== CloudItemType.FILE) {
      promptAction.showToast({ message: 'Only files can be downloaded' });
      return;
    }

    try {
      const context = getContext(this) as common.UIAbilityContext;
      const targetPath: string = `${context.cacheDir}/${this.item.name}`;
      await this.cloudProvider.downloadFile(this.item.id, targetPath);
      Logger.info(TAG, `Downloaded to ${targetPath}`);
      promptAction.showToast({ message: `Downloaded to cache: ${this.item.name}` });
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `download failed: ${err.message}`);
      promptAction.showToast({ message: `Download failed: ${err.message}` });
    }
  }

  private onMove(): void {
    promptAction.showToast({ message: 'Move is coming soon' });
    // A full implementation needs a folder-picker overlay that calls
    // cloudProvider.moveItem(itemId, targetFolderId) once a destination
    // is chosen. Tracked for a future milestone.
  }
}
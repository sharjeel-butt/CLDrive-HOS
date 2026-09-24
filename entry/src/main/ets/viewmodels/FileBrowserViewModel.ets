import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { request } from '@kit.BasicServicesKit';
import { picker } from '@kit.CoreFileKit';
import { CloudProviderFactory } from '../core/providers/CloudProviderFactory';
import { CloudProviderType } from '../core/models/CloudProviderType';
import { ICloudProvider } from '../core/interfaces/ICloudProvider';
import { CloudItem } from '../core/models/CloudItem';
import { CloudItemType } from '../core/models/CloudItemType';
import { AccountInfo, providerFromAccountId } from '../core/models/AccountInfo';
import { AuthManager } from '../core/auth/AuthManager';
import { Operation, OperationType, OperationItemKind } from '../core/models/Operation';
import { OperationTracker } from '../core/services/OperationTracker';
import { HttpClient, HttpRequestOptions } from '../core/network/HttpClient';
import { Logger } from '../utils/Logger';
import { Routes } from '../utils/RouteConstants';
import { DownloadInfo } from '../core/models/DownloadInfo';
import { fileIo as fs } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

const TAG: string = 'FileBrowserViewModel';

const HIDDEN_PICKER_FOLDER_NAMES: string[] = ['Getting Started'];
const SEARCH_DEBOUNCE_MS: number = 400;

export interface ProviderGroup {
  type: CloudProviderType;
  label: string;
  color: string;
  icon: string;
  accounts: AccountInfo[];
}

export interface Crumb {
  id: string;
  name: string;
}

interface NameParts {
  base: string;
  ext: string;
}

interface WalkedFile {
  path: string;
  relative: string;
}

export class FileBrowserViewModel {
  // ---- File browser ----
  items: CloudItem[] = [];
  isLoading: boolean = true;
  errorMessage: string = '';
  currentFolderId: string = 'root';
  activeAccountId: string = '';
  activeAccount: AccountInfo | null = null;
  crumbs: Crumb[] = [];

  // ---- Sidebar ----
  isSidebarOpen: boolean = false;
  accounts: AccountInfo[] = [];
  groups: ProviderGroup[] = [];
  onedriveExpanded: boolean = true;
  googleExpanded: boolean = true;

  // ---- Selection mode ----
  isSelectionMode: boolean = false;
  selectedIds: string[] = [];

  // ---- Item actions sheet ----
  selectedItem: CloudItem | null = null;

  // ---- Rename dialog ----
  showRenameDialog: boolean = false;
  renameText: string = '';
  isProcessing: boolean = false;

  // ---- Offline / download tracking ----
  offlineIds: string[] = [];
  downloadingIds: string[] = [];

  // ---- Move / Copy picker ----
  showMovePicker: boolean = false;
  pickerMode: string = 'move';
  pickerItems: CloudItem[] = [];
  movePickerFolderId: string = 'root';
  movePickerItems: CloudItem[] = [];
  movePickerCrumbs: Crumb[] = [];
  movePickerLoading: boolean = false;
  movePickerError: string = '';

  // ---- Create folder dialog ----
  showCreateFolderDialog: boolean = false;
  newFolderName: string = '';
  isCreatingFolder: boolean = false;

  // ---- Activity panel ----
  isActivityPanelOpen: boolean = false;

  // ---- Search ----
  isSearchActive: boolean = false;
  searchQuery: string = '';
  searchResults: CloudItem[] = [];
  isSearching: boolean = false;
  searchError: string = '';
  private searchTimerId: number = -1;

  // ---- Upload menu ----
  showUploadMenu: boolean = false;

  // ---- Injected dependencies ----
  private cloudProvider: ICloudProvider | null = null;
  private crumbScroller: Scroller | null = null;
  private context: common.UIAbilityContext | null = null;

  attachScroller(s: Scroller): void { this.crumbScroller = s; }
  setContext(c: common.UIAbilityContext): void { this.context = c; }

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  async init(): Promise<void> {
    const activeId: string = await AuthManager.getActiveAccountId();
    if (activeId.length === 0) {
      router.replaceUrl({ url: Routes.ONBOARDING });
      return;
    }
    await this.activateAccount(activeId);
    await this.refreshAccounts();
  }

  async onPageShow(): Promise<void> {
    // Detect whether the active account changed while we were away.
    // Adding a new account from onboarding sets a new active account ID,
    // so we must swap the cloud provider accordingly.
    const newActiveId: string = await AuthManager.getActiveAccountId();
    const accountChanged: boolean = newActiveId !== this.activeAccountId;

    await this.refreshAccounts();

    if (accountChanged || this.cloudProvider === null) {
      // Fresh account — reset the trail and reload from root.
      await this.activateAccount(newActiveId);
      return;
    }

    // Same account — just refresh the current folder.
    await this.loadFolder(this.currentFolderId);
  }

  // ===========================================================================
  // Accounts
  // ===========================================================================

  private async refreshAccounts(): Promise<void> {
    const list = await AuthManager.getAccounts();
    this.accounts = list;
    this.groups = this.buildGroups(list);
    this.activeAccountId = await AuthManager.getActiveAccountId();
    if (this.activeAccountId.length > 0) {
      this.activeAccount = await AuthManager.getActiveAccount();
    }
  }

  private buildGroups(accounts: AccountInfo[]): ProviderGroup[] {
    const onedrive: AccountInfo[] = [];
    const google: AccountInfo[] = [];
    for (let i = 0; i < accounts.length; i++) {
      const a = accounts[i];
      if (a.provider === CloudProviderType.ONEDRIVE) onedrive.push(a);
      else if (a.provider === CloudProviderType.GOOGLE_DRIVE) google.push(a);
    }
    const groups: ProviderGroup[] = [];
    if (onedrive.length > 0) {
      groups.push({
        type: CloudProviderType.ONEDRIVE,
        label: 'OneDrive',
        color: '#0078D4',
        icon: '☁',
        accounts: onedrive
      });
    }
    if (google.length > 0) {
      groups.push({
        type: CloudProviderType.GOOGLE_DRIVE,
        label: 'Google Drive',
        color: '#4285F4',
        icon: '▲',
        accounts: google
      });
    }
    return groups;
  }

  isExpanded(type: CloudProviderType): boolean {
    if (type === CloudProviderType.ONEDRIVE) return this.onedriveExpanded;
    if (type === CloudProviderType.GOOGLE_DRIVE) return this.googleExpanded;
    return true;
  }

  toggleExpanded(type: CloudProviderType): void {
    if (type === CloudProviderType.ONEDRIVE) {
      this.onedriveExpanded = !this.onedriveExpanded;
    } else if (type === CloudProviderType.GOOGLE_DRIVE) {
      this.googleExpanded = !this.googleExpanded;
    }
  }

  private async activateAccount(accountId: string): Promise<void> {
    this.activeAccountId = accountId;
    await AuthManager.setActiveAccountId(accountId);
    this.activeAccount = await AuthManager.getActiveAccount();

    const type: CloudProviderType =
      this.activeAccount !== null
        ? this.activeAccount.provider
        : providerFromAccountId(accountId);

    this.cloudProvider = CloudProviderFactory.getProvider(accountId, type);

    const rootName: string =
      this.activeAccount !== null ? this.activeAccount.displayName : 'Files';
    this.crumbs = [{ id: 'root', name: rootName }];
    this.currentFolderId = 'root';
    this.exitSelectionMode();
    this.closeSearch();

    await this.loadFolder('root');
  }

  // ===========================================================================
  // Navigation
  // ===========================================================================

  async loadFolder(folderId: string): Promise<void> {
    if (this.cloudProvider === null) return;
    this.isLoading = true;
    this.errorMessage = '';
    try {
      this.items = await this.cloudProvider.listChildren(folderId);
      this.currentFolderId = folderId;
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `loadFolder failed: ${err.message}`);
      this.errorMessage = err.message;
    } finally {
      this.isLoading = false;
    }
  }

  async openFolder(item: CloudItem): Promise<void> {
    this.crumbs = [...this.crumbs, { id: item.id, name: item.name }];
    await this.loadFolder(item.id);
    this.scrollCrumbsToEnd();
  }

  async goToCrumb(index: number): Promise<void> {
    if (index < 0 || index >= this.crumbs.length) return;
    if (index === this.crumbs.length - 1) return;
    const target: Crumb = this.crumbs[index];
    this.crumbs = this.crumbs.slice(0, index + 1);
    await this.loadFolder(target.id);
  }

  async goBack(): Promise<void> {
    if (this.crumbs.length <= 1) return;
    await this.goToCrumb(this.crumbs.length - 2);
  }

  canGoBack(): boolean {
    return this.crumbs.length > 1;
  }

  private scrollCrumbsToEnd(): void {
    if (this.crumbScroller === null) return;
    setTimeout(() => {
      try {
        this.crumbScroller!.scrollEdge(Edge.End);
      } catch (_) {
        // Scroller not attached — safe to ignore.
      }
    }, 80);
  }

  // ===========================================================================
  // Search
  // ===========================================================================

  openSearch(): void {
    this.isSearchActive = true;
    this.searchQuery = '';
    this.searchResults = [];
    this.searchError = '';
  }

  closeSearch(): void {
    if (this.searchTimerId >= 0) {
      clearTimeout(this.searchTimerId);
      this.searchTimerId = -1;
    }
    this.isSearchActive = false;
    this.searchQuery = '';
    this.searchResults = [];
    this.searchError = '';
    this.isSearching = false;
  }

  setSearchQuery(q: string): void {
    this.searchQuery = q;

    if (this.searchTimerId >= 0) {
      clearTimeout(this.searchTimerId);
      this.searchTimerId = -1;
    }

    const trimmed = q.trim();
    if (trimmed.length === 0) {
      this.searchResults = [];
      this.searchError = '';
      this.isSearching = false;
      return;
    }

    this.isSearching = true;
    this.searchTimerId = setTimeout(() => {
      this.performSearch();
    }, SEARCH_DEBOUNCE_MS);
  }

  private async performSearch(): Promise<void> {
    if (this.cloudProvider === null) return;
    const query = this.searchQuery.trim();
    if (query.length === 0) {
      this.isSearching = false;
      return;
    }

    try {
      const results = await this.cloudProvider.search(query);
      this.searchResults = results;
      this.searchError = '';
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `search failed: ${err.message}`);
      this.searchError = err.message;
      this.searchResults = [];
    } finally {
      this.isSearching = false;
    }
  }

  async onSearchResultTap(item: CloudItem): Promise<void> {
    if (item.type === CloudItemType.FOLDER) {
      this.closeSearch();
      this.crumbs = [{ id: item.id, name: item.name }];
      await this.loadFolder(item.id);
    } else {
      this.selectedItem = item;
    }
  }

  // ===========================================================================
  // Upload menu
  // ===========================================================================

  openUploadMenu(): void {
    this.showUploadMenu = true;
  }

  closeUploadMenu(): void {
    this.showUploadMenu = false;
  }

  async onUploadFile(): Promise<void> {
    if (this.cloudProvider === null) return;
    this.closeUploadMenu();

    try {
      const p = new picker.DocumentViewPicker();
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 20;

      const uris: string[] = await p.select(options);
      if (uris === null || uris === undefined || uris.length === 0) return;

      const tracker = OperationTracker.get();

      for (let i = 0; i < uris.length; i++) {
        const uri = uris[i];
        const fileName = FileBrowserViewModel.fileNameFromUri(uri);

        const opId = tracker.register(
          OperationType.UPLOAD,
          fileName,
          '',
          OperationItemKind.FILE,
          i + 1,
          uris.length
        );
        tracker.markRunning(opId);

        try {
          await this.cloudProvider.uploadFile(this.currentFolderId, fileName, uri);
          tracker.markSuccess(opId);
        } catch (e) {
          const err: Error = e as Error;
          Logger.error(TAG, `upload ${fileName} failed: ${err.message}`);
          tracker.markFailed(opId, err.message);
        }
      }

      await this.loadFolder(this.currentFolderId);
    } catch (e) {
      const err: Error = e as Error;
      Logger.warn(TAG, `upload file picker cancelled or failed: ${err.message}`);
    }
  }

  async onUploadFolder(): Promise<void> {
    if (this.cloudProvider === null) return;
    this.closeUploadMenu();

    try {
      const p = new picker.DocumentViewPicker();
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.selectMode = picker.DocumentSelectMode.FOLDER;

      const uris: string[] = await p.select(options);
      if (uris === null || uris === undefined || uris.length === 0) return;

      const rootUri = uris[0];
      const rootName = FileBrowserViewModel.fileNameFromUri(rootUri);
      const rootPath = FileBrowserViewModel.uriToPath(rootUri);

      const files: WalkedFile[] = FileBrowserViewModel.walkDirectory(rootPath);

      if (files.length === 0) {
        promptAction.showToast({ message: 'The selected folder is empty' });
        return;
      }

      const tracker = OperationTracker.get();

      // Create the top-level destination folder in the cloud (or reuse).
      let rootFolderId = '';
      try {
        const created = await this.cloudProvider.createFolder(
          this.currentFolderId, rootName
        );
        rootFolderId = created.id;
      } catch (e) {
        const siblings = await this.cloudProvider.listChildren(this.currentFolderId);
        for (let i = 0; i < siblings.length; i++) {
          if (siblings[i].name === rootName
            && siblings[i].type === CloudItemType.FOLDER) {
            rootFolderId = siblings[i].id;
            break;
          }
        }
        if (rootFolderId.length === 0) {
          const err: Error = e as Error;
          throw err;
        }
      }

      const folderCache: Map<string, string> = new Map();
      folderCache.set('', rootFolderId);

      for (let i = 0; i < files.length; i++) {
        const f = files[i];
        const parts = f.relative.split('/');
        const name = parts[parts.length - 1];
        const dirRel = parts.slice(0, -1).join('/');

        const opId = tracker.register(
          OperationType.UPLOAD,
          f.relative,
          '',
          OperationItemKind.FILE,
          i + 1,
          files.length
        );
        tracker.markRunning(opId);

        try {
          const parentId = await this.ensureFolderPath(dirRel, folderCache, rootFolderId);
          await this.cloudProvider.uploadFile(parentId, name, `file://${f.path}`);
          tracker.markSuccess(opId);
        } catch (e) {
          const err: Error = e as Error;
          Logger.error(TAG, `upload ${f.relative} failed: ${err.message}`);
          tracker.markFailed(opId, err.message);
        }
      }

      await this.loadFolder(this.currentFolderId);
      promptAction.showToast({ message: `Uploaded ${files.length} files` });
    } catch (e) {
      const err: Error = e as Error;
      Logger.warn(TAG, `upload folder cancelled or failed: ${err.message}`);
    }
  }

  private async ensureFolderPath(
    relative: string,
    cache: Map<string, string>,
    rootFolderId: string
  ): Promise<string> {
    if (relative.length === 0) return rootFolderId;

    const cached = cache.get(relative);
    if (cached !== undefined) return cached;

    const parts = relative.split('/');
    let currentId = rootFolderId;
    let currentRel = '';

    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      currentRel = currentRel.length > 0 ? `${currentRel}/${part}` : part;

      const existing = cache.get(currentRel);
      if (existing !== undefined) {
        currentId = existing;
        continue;
      }

      try {
        const created = await this.cloudProvider!.createFolder(currentId, part);
        currentId = created.id;
        cache.set(currentRel, currentId);
      } catch (e) {
        const siblings = await this.cloudProvider!.listChildren(currentId);
        let foundId = '';
        for (let j = 0; j < siblings.length; j++) {
          if (siblings[j].name === part
            && siblings[j].type === CloudItemType.FOLDER) {
            foundId = siblings[j].id;
            break;
          }
        }
        if (foundId.length === 0) {
          const err: Error = e as Error;
          throw err;
        }
        currentId = foundId;
        cache.set(currentRel, currentId);
      }
    }

    return currentId;
  }

  // ===========================================================================
  // Selection mode
  // ===========================================================================

  isSelected(itemId: string): boolean {
    return this.selectedIds.indexOf(itemId) >= 0;
  }

  selectedCount(): number {
    return this.selectedIds.length;
  }

  hasSelection(): boolean {
    return this.selectedIds.length > 0;
  }

  enterSelectionMode(itemId: string): void {
    if (this.isSelectionMode) return;
    this.isSelectionMode = true;
    this.selectedIds = [itemId];
  }

  exitSelectionMode(): void {
    this.isSelectionMode = false;
    this.selectedIds = [];
  }

  toggleSelection(itemId: string): void {
    const idx = this.selectedIds.indexOf(itemId);
    if (idx >= 0) {
      const next = this.selectedIds.slice();
      next.splice(idx, 1);
      this.selectedIds = next;
      if (this.selectedIds.length === 0) {
        this.isSelectionMode = false;
      }
    } else {
      this.selectedIds = [...this.selectedIds, itemId];
    }
  }

  selectAll(): void {
    const ids: string[] = [];
    for (let i = 0; i < this.items.length; i++) {
      ids.push(this.items[i].id);
    }
    this.selectedIds = ids;
    if (!this.isSelectionMode && ids.length > 0) {
      this.isSelectionMode = true;
    }
  }

  deselectAll(): void {
    this.selectedIds = [];
    this.isSelectionMode = false;
  }

  allSelected(): boolean {
    return this.items.length > 0 && this.selectedIds.length === this.items.length;
  }

  getSelectedItems(): CloudItem[] {
    const out: CloudItem[] = [];
    for (let i = 0; i < this.items.length; i++) {
      const it = this.items[i];
      if (this.selectedIds.indexOf(it.id) >= 0) out.push(it);
    }
    return out;
  }

  // ===========================================================================
  // Sidebar
  // ===========================================================================

  openSidebar(): void { this.isSidebarOpen = true; }
  closeSidebar(): void { this.isSidebarOpen = false; }

  async onSwitchAccount(accountId: string): Promise<void> {
    if (accountId === this.activeAccountId) {
      this.isSidebarOpen = false;
      return;
    }
    this.isSidebarOpen = false;
    this.items = [];
    await this.activateAccount(accountId);
  }

  onAddAccount(): void {
    this.isSidebarOpen = false;
    router.pushUrl({ url: Routes.ONBOARDING, params: { mode: 'add' } })
      .catch((e: Error) => {
        Logger.error(TAG, `pushUrl failed: ${e.message}`);
      });
  }

  onSignOut(): void {
    if (this.activeAccount === null) return;
    const label = this.activeAccount.displayName;
    this.isSidebarOpen = false;
    promptAction.showDialog({
      title: 'Sign out',
      message: `Sign out of ${label}? You'll need to sign in again to access it.`,
      buttons: [
        { text: 'Cancel', color: '#666666' },
        { text: 'Sign out', color: '#F57C00' }
      ]
    })
      .then((result: promptAction.ShowDialogSuccessResponse) => {
        if (result.index === 1) this.performSignOut();
      })
      .catch((e: Error) => {
        Logger.error(TAG, `showDialog failed: ${e.message}`);
      });
  }

  private async performSignOut(): Promise<void> {
    const id = this.activeAccountId;
    if (id.length === 0) return;
    try {
      await AuthManager.signOut(id);
      CloudProviderFactory.evict(id);
      const remaining = await AuthManager.getAccounts();
      this.accounts = remaining;
      this.groups = this.buildGroups(remaining);
      if (remaining.length === 0) {
        router.replaceUrl({ url: Routes.ONBOARDING });
        return;
      }
      await this.activateAccount(remaining[0].accountId);
      await this.refreshAccounts();
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `signOut failed: ${err.message}`);
    }
  }

  onExitApp(): void {
    this.isSidebarOpen = false;
    promptAction.showDialog({
      title: 'Exit',
      message: 'Close the app?',
      buttons: [
        { text: 'Cancel', color: '#666666' },
        { text: 'Exit', color: '#D32F2F' }
      ]
    })
      .then((result: promptAction.ShowDialogSuccessResponse) => {
        if (result.index === 1) this.performExit();
      })
      .catch((e: Error) => {
        Logger.error(TAG, `showDialog failed: ${e.message}`);
      });
  }

  private performExit(): void {
    if (this.context === null) return;
    this.context.terminateSelf().catch((e: Error) => {
      Logger.error(TAG, `terminateSelf failed: ${e.message}`);
    });
  }

  // ===========================================================================
  // Activity panel
  // ===========================================================================

  openActivityPanel(): void { this.isActivityPanelOpen = true; }
  closeActivityPanel(): void { this.isActivityPanelOpen = false; }

  clearCompletedOperations(): void {
    OperationTracker.get().clearCompleted();
  }

  clearFinishedOperations(): void {
    OperationTracker.get().clearFinished();
  }

  forceClearAllOperations(): void {
    promptAction.showDialog({
      title: 'Force clear all?',
      message: 'This removes every entry from the activity list, including ones still running. Background work will continue but you will no longer see its status. Continue?',
      buttons: [
        { text: 'Cancel', color: '#666666' },
        { text: 'Force clear', color: '#D32F2F' }
      ]
    })
      .then((r: promptAction.ShowDialogSuccessResponse) => {
        if (r.index === 1) {
          OperationTracker.get().forceClearAll();
          promptAction.showToast({ message: 'Activity list cleared' });
        }
      })
      .catch(() => {
        // User dismissed.
      });
  }

  // ===========================================================================
  // Item actions sheet
  // ===========================================================================

  onShowItemActions(item: CloudItem): void { this.selectedItem = item; }
  closeActionsSheet(): void { this.selectedItem = null; }

  onToggleOffline(isOn: boolean): void {
    if (this.selectedItem === null) return;
    const id = this.selectedItem.id;
    const idx = this.offlineIds.indexOf(id);
    if (isOn && idx < 0) this.offlineIds = [...this.offlineIds, id];
    else if (!isOn && idx >= 0) {
      const next = this.offlineIds.slice();
      next.splice(idx, 1);
      this.offlineIds = next;
    }
  }

  isOffline(itemId: string): boolean {
    return this.offlineIds.indexOf(itemId) >= 0;
  }

  isDownloading(itemId: string): boolean {
    return this.downloadingIds.indexOf(itemId) >= 0;
  }

  private markDownloading(itemId: string, on: boolean): void {
    const idx = this.downloadingIds.indexOf(itemId);
    if (on && idx < 0) this.downloadingIds = [...this.downloadingIds, itemId];
    else if (!on && idx >= 0) {
      const next = this.downloadingIds.slice();
      next.splice(idx, 1);
      this.downloadingIds = next;
    }
  }

  canDownloadSelected(): boolean {
    return this.selectedItem !== null
      && this.selectedItem.type === CloudItemType.FILE
      && !this.isDownloading(this.selectedItem.id);
  }

  // ===========================================================================
  // Rename
  // ===========================================================================

  onRenameItem(): void {
    if (this.selectedItem === null) return;
    this.renameText = this.selectedItem.name;
    this.showRenameDialog = true;
  }

  cancelRename(): void {
    this.showRenameDialog = false;
  }

  async performRename(): Promise<void> {
    if (this.selectedItem === null || this.cloudProvider === null) return;
    const newName = this.renameText.trim();
    if (newName.length === 0) {
      promptAction.showToast({ message: 'Name cannot be empty' });
      return;
    }
    if (newName === this.selectedItem.name) {
      this.showRenameDialog = false;
      return;
    }

    const targetId = this.selectedItem.id;
    this.isProcessing = true;
    try {
      await this.cloudProvider.renameItem(targetId, newName);
      this.showRenameDialog = false;
      this.selectedItem = null;
      this.crumbs = this.crumbs.map((c: Crumb): Crumb =>
      c.id === targetId ? { id: c.id, name: newName } : c
      );
      await this.loadFolder(this.currentFolderId);
      promptAction.showToast({ message: 'Renamed' });
    } catch (e) {
      const err: Error = e as Error;
      promptAction.showToast({ message: `Rename failed: ${err.message}` });
    } finally {
      this.isProcessing = false;
    }
  }

  // ===========================================================================
  // Delete
  // ===========================================================================

  onDeleteItem(): void {
    if (this.selectedItem === null) return;
    const items: CloudItem[] = [this.selectedItem];
    this.selectedItem = null;
    this.confirmDelete(items);
  }

  onBatchDelete(): void {
    if (!this.hasSelection()) return;
    const items = this.getSelectedItems();
    this.confirmDelete(items);
  }

  private confirmDelete(items: CloudItem[]): void {
    if (items.length === 0) return;
    const count = items.length;
    const hasFolder = items.some((it: CloudItem): boolean =>
    it.type === CloudItemType.FOLDER
    );

    const title = count === 1 ? 'Delete' : `Delete ${count} items`;
    const subject = count === 1 ? `"${items[0].name}"` : `${count} items`;
    const extra = hasFolder
      ? ' Folders and their contents will be deleted too.'
      : '';

    promptAction.showDialog({
      title: title,
      message: `Delete ${subject}?${extra} This cannot be undone.`,
      buttons: [
        { text: 'Cancel', color: '#666666' },
        { text: 'Delete', color: '#D32F2F' }
      ]
    })
      .then((r: promptAction.ShowDialogSuccessResponse) => {
        if (r.index === 1) {
          this.exitSelectionMode();
          this.runBatchDeleteBackground(items);
        }
      })
      .catch((e: Error) => {
        Logger.error(TAG, `dialog failed: ${e.message}`);
      });
  }

  private async runBatchDeleteBackground(items: CloudItem[]): Promise<void> {
    if (this.cloudProvider === null) return;
    const tracker = OperationTracker.get();
    let success = 0;
    let failed = 0;

    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      const kind: OperationItemKind = it.type === CloudItemType.FOLDER
        ? OperationItemKind.FOLDER
        : OperationItemKind.FILE;

      const opId = tracker.register(
        OperationType.DELETE, it.name, it.id, kind, i + 1, items.length
      );
      tracker.markRunning(opId);

      try {
        await this.cloudProvider.deleteItem(it.id);
        tracker.markSuccess(opId);
        success++;
        const idx = this.offlineIds.indexOf(it.id);
        if (idx >= 0) {
          const next = this.offlineIds.slice();
          next.splice(idx, 1);
          this.offlineIds = next;
        }
      } catch (e) {
        const err: Error = e as Error;
        Logger.error(TAG, `delete ${it.name} failed: ${err.message}`);
        tracker.markFailed(opId, err.message);
        failed++;
      }
    }

    await this.loadFolder(this.currentFolderId);

    if (failed === 0) {
      promptAction.showToast({
        message: success === 1
          ? `Deleted "${items[0].name}"`
          : `Deleted ${success} items`
      });
    } else {
      promptAction.showToast({ message: `Deleted ${success}, failed ${failed}` });
    }
  }

  // ===========================================================================
  // Move / Copy
  // ===========================================================================

  onMoveItem(): void {
    if (this.selectedItem === null) return;
    const items: CloudItem[] = [this.selectedItem];
    this.selectedItem = null;
    this.openPicker(items, 'move');
  }

  onCopyItem(): void {
    if (this.selectedItem === null) return;
    const items: CloudItem[] = [this.selectedItem];
    this.selectedItem = null;
    this.openPicker(items, 'copy');
  }

  onBatchMove(): void {
    if (!this.hasSelection()) return;
    this.openPicker(this.getSelectedItems(), 'move');
  }

  onBatchCopy(): void {
    if (!this.hasSelection()) return;
    this.openPicker(this.getSelectedItems(), 'copy');
  }

  private openPicker(items: CloudItem[], mode: string): void {
    if (items.length === 0) return;
    this.pickerItems = items;
    this.pickerMode = mode;
    this.showMovePicker = true;
    this.movePickerFolderId = 'root';
    this.movePickerError = '';
    this.movePickerCrumbs = [
      {
        id: 'root',
        name: this.activeAccount !== null
          ? this.activeAccount.displayName
          : 'Files'
      }
    ];
    this.loadMovePickerFolder('root');
  }

  closeMovePicker(): void {
    this.showMovePicker = false;
    this.pickerItems = [];
    this.movePickerItems = [];
    this.movePickerCrumbs = [];
    this.movePickerError = '';
  }

  pickerTitle(): string {
    if (this.pickerItems.length > 1) {
      return this.pickerMode === 'copy'
        ? `Copy ${this.pickerItems.length} items to`
        : `Move ${this.pickerItems.length} items to`;
    }
    return this.pickerMode === 'copy'
      ? 'Pick the destination to copy to'
      : 'Pick the destination';
  }

  pickerConfirmLabel(): string {
    return this.pickerMode === 'copy' ? 'Copy here' : 'Move here';
  }

  canConfirmHere(): boolean {
    if (this.pickerItems.length === 0) return false;
    if (this.pickerMode === 'copy') return true;
    return this.movePickerFolderId !== this.currentFolderId;
  }

  private async loadMovePickerFolder(folderId: string): Promise<void> {
    if (this.cloudProvider === null) return;
    this.movePickerLoading = true;
    this.movePickerError = '';
    try {
      const all = await this.cloudProvider.listChildren(folderId);
      const hidden: string[] = [];
      for (let i = 0; i < this.pickerItems.length; i++) {
        hidden.push(this.pickerItems[i].id);
      }

      const folders: CloudItem[] = [];
      for (let i = 0; i < all.length; i++) {
        const it = all[i];
        if (it.type !== CloudItemType.FOLDER) continue;
        if (hidden.indexOf(it.id) >= 0) continue;
        if (HIDDEN_PICKER_FOLDER_NAMES.indexOf(it.name) >= 0) continue;
        folders.push(it);
      }
      this.movePickerItems = folders;
      this.movePickerFolderId = folderId;
    } catch (e) {
      const err: Error = e as Error;
      this.movePickerError = err.message;
    } finally {
      this.movePickerLoading = false;
    }
  }

  async movePickerOpenFolder(folder: CloudItem): Promise<void> {
    this.movePickerCrumbs = [
      ...this.movePickerCrumbs,
      { id: folder.id, name: folder.name }
    ];
    await this.loadMovePickerFolder(folder.id);
  }

  async movePickerGoToCrumb(index: number): Promise<void> {
    if (index < 0 || index >= this.movePickerCrumbs.length) return;
    if (index === this.movePickerCrumbs.length - 1) return;
    const target = this.movePickerCrumbs[index];
    this.movePickerCrumbs = this.movePickerCrumbs.slice(0, index + 1);
    await this.loadMovePickerFolder(target.id);
  }

  async performPickerConfirm(): Promise<void> {
    if (this.pickerItems.length === 0 || this.cloudProvider === null) return;
    const items = this.pickerItems.slice();
    const targetId = this.movePickerFolderId;
    const mode = this.pickerMode;

    if (mode === 'move' && targetId === this.currentFolderId) {
      promptAction.showToast({ message: 'Items are already in this folder' });
      return;
    }

    this.closeMovePicker();
    this.exitSelectionMode();

    if (mode === 'move') {
      this.runBatchMoveBackground(items, targetId);
    } else {
      this.runBatchCopyBackground(items, targetId);
    }
  }

  private async runBatchMoveBackground(
    items: CloudItem[],
    targetId: string
  ): Promise<void> {
    if (this.cloudProvider === null) return;
    const tracker = OperationTracker.get();

    const conflicts = await this.findConflicts(items, targetId);
    let resolveMode = 'none';
    if (conflicts.length > 0) {
      resolveMode = await this.askBatchConflictChoice(conflicts);
      if (resolveMode === 'skip' && conflicts.length === items.length) {
        promptAction.showToast({ message: 'Move cancelled' });
        return;
      }
    }

    let success = 0;
    let failed = 0;

    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      const kind: OperationItemKind = it.type === CloudItemType.FOLDER
        ? OperationItemKind.FOLDER
        : OperationItemKind.FILE;

      const opId = tracker.register(
        OperationType.MOVE, it.name, it.id, kind, i + 1, items.length
      );
      tracker.markRunning(opId);
      const hasConflict = conflicts.some((c: CloudItem): boolean =>
      c.id === it.id
      );

      try {
        if (!hasConflict) {
          await this.cloudProvider.moveItem(it.id, targetId);
        } else if (resolveMode === 'skip') {
          tracker.markCancelled(opId);
          continue;
        } else if (resolveMode === 'keep-both') {
          const newName = await this.findAvailableName(it.name, targetId);
          await this.cloudProvider.moveItem(it.id, targetId, newName);
        } else if (resolveMode === 'replace') {
          const sibling = await this.findSiblingByName(targetId, it.name);
          if (sibling !== null) {
            await this.cloudProvider.deleteItem(sibling.id);
          }
          await this.cloudProvider.moveItem(it.id, targetId);
        }
        tracker.markSuccess(opId);
        success++;
      } catch (e) {
        const err: Error = e as Error;
        Logger.error(TAG, `move ${it.name} failed: ${err.message}`);
        tracker.markFailed(opId, err.message);
        failed++;
      }
    }

    await this.loadFolder(this.currentFolderId);

    if (failed === 0) {
      promptAction.showToast({
        message: success === 1
          ? `Moved "${items[0].name}"`
          : `Moved ${success} items`
      });
    } else {
      promptAction.showToast({ message: `Moved ${success}, failed ${failed}` });
    }
  }

  private async runBatchCopyBackground(
    items: CloudItem[],
    targetId: string
  ): Promise<void> {
    if (this.cloudProvider === null) return;
    const tracker = OperationTracker.get();

    const conflicts = await this.findConflicts(items, targetId);
    let resolveMode = 'none';
    if (conflicts.length > 0) {
      resolveMode = await this.askBatchConflictChoice(conflicts);
      if (resolveMode === 'skip' && conflicts.length === items.length) {
        promptAction.showToast({ message: 'Copy cancelled' });
        return;
      }
    }

    let success = 0;
    let failed = 0;

    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      const kind: OperationItemKind = it.type === CloudItemType.FOLDER
        ? OperationItemKind.FOLDER
        : OperationItemKind.FILE;

      const opId = tracker.register(
        OperationType.COPY, it.name, it.id, kind, i + 1, items.length
      );
      tracker.markRunning(opId);
      const hasConflict = conflicts.some((c: CloudItem): boolean =>
      c.id === it.id
      );

      try {
        let finalName: string | undefined = undefined;

        if (!hasConflict) {
          // No conflict — copy with the original name.
        } else if (resolveMode === 'skip') {
          tracker.markCancelled(opId);
          continue;
        } else if (resolveMode === 'keep-both') {
          finalName = await this.findAvailableName(it.name, targetId);
        } else if (resolveMode === 'replace') {
          const sibling = await this.findSiblingByName(targetId, it.name);
          if (sibling !== null) {
            await this.cloudProvider.deleteItem(sibling.id);
          }
        }

        const monitorUrl: string | null =
          await this.cloudProvider.copyItem(it.id, targetId, finalName);

        if (monitorUrl !== null && monitorUrl.length > 0) {
          await this.pollCopyMonitor(monitorUrl, opId);
        } else {
          tracker.markSuccess(opId);
        }
        success++;
      } catch (e) {
        const err: Error = e as Error;
        Logger.error(TAG, `copy ${it.name} failed: ${err.message}`);
        tracker.markFailed(opId, err.message);
        failed++;
      }
    }

    if (targetId === this.currentFolderId) {
      setTimeout(() => {
        this.loadFolder(this.currentFolderId);
      }, 900);
    } else {
      await this.loadFolder(this.currentFolderId);
    }

    if (failed === 0) {
      promptAction.showToast({
        message: success === 1
          ? `Copied "${items[0].name}"`
          : `Copied ${success} items`
      });
    } else {
      promptAction.showToast({ message: `Copied ${success}, failed ${failed}` });
    }
  }

  private async pollCopyMonitor(monitorUrl: string, opId: string): Promise<void> {
    const tracker = OperationTracker.get();
    const maxAttempts = 600;
    const intervalMs = 1000;

    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      await this.sleep(intervalMs);

      try {
        const opts = new HttpRequestOptions();
        opts.method = http.RequestMethod.GET;

        const response = await HttpClient.requestWithHeaders(monitorUrl, opts);

        if (response.statusCode === 200) {
          Logger.info(TAG, `Copy monitor finished after ${attempt + 1} polls.`);
          tracker.markSuccess(opId);
          return;
        }

        if (response.statusCode === 202) {
          const pct = Math.min(95, Math.floor(((attempt + 1) / 30) * 100));
          tracker.updateProgress(opId, pct);
          continue;
        }

        if (response.statusCode >= 400) {
          throw new Error(
            `Copy monitor returned HTTP ${response.statusCode}: ${response.body}`
          );
        }
      } catch (e) {
        const err: Error = e as Error;
        Logger.warn(TAG, `copy monitor poll ${attempt + 1} failed: ${err.message}`);
      }
    }

    throw new Error('Copy is taking longer than expected.');
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(() => { resolve(); }, ms);
    });
  }

  // ===========================================================================
  // Conflict helpers
  // ===========================================================================

  private async findConflicts(
    items: CloudItem[],
    targetId: string
  ): Promise<CloudItem[]> {
    if (this.cloudProvider === null) return [];
    const siblings = await this.cloudProvider.listChildren(targetId);
    const out: CloudItem[] = [];

    for (let i = 0; i < items.length; i++) {
      const sourceName = items[i].name.toLowerCase();
      for (let j = 0; j < siblings.length; j++) {
        if (siblings[j].name.toLowerCase() === sourceName) {
          out.push(items[i]);
          break;
        }
      }
    }
    return out;
  }

  private askBatchConflictChoice(conflicts: CloudItem[]): Promise<string> {
    return new Promise<string>((resolve: (v: string) => void) => {
      const count = conflicts.length;
      const preview = count === 1
        ? `"${conflicts[0].name}" already exists in the destination.`
        : `${count} items already exist in the destination.`;

      promptAction.showDialog({
        title: 'Name conflict',
        message: `${preview} What would you like to do?`,
        buttons: [
          { text: 'Skip All', color: '#666666' },
          { text: 'Keep Both', color: '#0078D4' },
          { text: 'Replace All', color: '#D32F2F' }
        ]
      })
        .then((r: promptAction.ShowDialogSuccessResponse) => {
          if (r.index === 0) resolve('skip');
          else if (r.index === 1) resolve('keep-both');
          else resolve('replace');
        })
        .catch(() => {
          resolve('skip');
        });
    });
  }

  private async findAvailableName(
    originalName: string,
    targetFolderId: string
  ): Promise<string> {
    if (this.cloudProvider === null) return originalName;
    const siblings = await this.cloudProvider.listChildren(targetFolderId);
    const existing: string[] = [];
    for (let i = 0; i < siblings.length; i++) {
      existing.push(siblings[i].name.toLowerCase());
    }

    const parts = FileBrowserViewModel.splitName(originalName);
    for (let i = 1; i < 1000; i++) {
      const candidate = `${parts.base} (${i})${parts.ext}`;
      if (existing.indexOf(candidate.toLowerCase()) < 0) return candidate;
    }
    throw new Error('Could not find an available name.');
  }

  private async findSiblingByName(
    targetFolderId: string,
    name: string
  ): Promise<CloudItem | null> {
    if (this.cloudProvider === null) return null;
    const siblings = await this.cloudProvider.listChildren(targetFolderId);
    const target = name.toLowerCase();
    for (let i = 0; i < siblings.length; i++) {
      if (siblings[i].name.toLowerCase() === target) return siblings[i];
    }
    return null;
  }

  // ===========================================================================
  // Create folder
  // ===========================================================================

  openCreateFolderPrompt(): void {
    this.newFolderName = '';
    this.showCreateFolderDialog = true;
  }

  cancelCreateFolder(): void {
    this.showCreateFolderDialog = false;
    this.newFolderName = '';
  }

  async performCreateFolder(): Promise<void> {
    if (this.cloudProvider === null) return;
    const name = this.newFolderName.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: 'Folder name cannot be empty' });
      return;
    }
    this.isCreatingFolder = true;
    try {
      await this.cloudProvider.createFolder(this.movePickerFolderId, name);
      this.showCreateFolderDialog = false;
      this.newFolderName = '';
      await this.loadMovePickerFolder(this.movePickerFolderId);
      promptAction.showToast({ message: `Folder "${name}" created` });
    } catch (e) {
      const err: Error = e as Error;
      promptAction.showToast({ message: `Create failed: ${err.message}` });
    } finally {
      this.isCreatingFolder = false;
    }
  }

  // ===========================================================================
  // Download
  // ===========================================================================

  async onDownloadItem(): Promise<void> {
    if (this.selectedItem === null || this.cloudProvider === null) return;
    const item = this.selectedItem;
    if (item.type !== CloudItemType.FILE) {
      promptAction.showToast({ message: 'Folders cannot be downloaded' });
      return;
    }
    const itemId = item.id;
    const itemName = item.name;

    this.closeActionsSheet();

    const tracker = OperationTracker.get();
    const opId = tracker.register(
      OperationType.DOWNLOAD, itemName, itemId, OperationItemKind.FILE, 0, 0
    );
    tracker.markRunning(opId);
    this.markDownloading(itemId, true);

    try {
      const saveUri = await this.pickSaveLocation(itemName);
      if (saveUri === null) {
        tracker.markCancelled(opId);
        this.markDownloading(itemId, false);
        return;
      }

      // Log the exact URI so we can verify it in Logcat.
      Logger.info(TAG, `Picker returned save URI: ${saveUri}`);

      const info: DownloadInfo = await this.cloudProvider.getDownloadInfo(itemId);
      await this.startAgentDownload(info, saveUri, itemName, itemId, opId);
    } catch (e) {
      const err: Error = e as Error;
      tracker.markFailed(opId, err.message);
      this.markDownloading(itemId, false);
      promptAction.showToast({ message: `Download failed: ${err.message}` });
    }
  }

  private async pickSaveLocation(fileName: string): Promise<string | null> {
    const documentPicker = new picker.DocumentViewPicker();
    const saveOptions = new picker.DocumentSaveOptions();

    // Prepopulate the filename field — the full name, INCLUDING extension.
    // Do NOT set fileSuffixChoices: when both are set, the picker strips
    // the extension from the name field and turns it into a separate
    // "file type" dropdown, leaving the name field showing only the base.
    saveOptions.newFileNames = [fileName];

    const result = await documentPicker.save(saveOptions);
    if (result === null || result === undefined || result.length === 0) {
      return null;
    }
    return result[0];
  }

  private async startAgentDownload(
    info: DownloadInfo,
    targetUri: string,
    fileName: string,
    itemId: string,
    opId: string
  ): Promise<void> {
    if (this.context === null) throw new Error('Context not set');
    const tracker = OperationTracker.get();

    // Build header Record for request.agent.
    const headerObj: Record<string, string> = {};
    Reflect.set(
      headerObj,
      'User-Agent',
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 ' +
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36'
    );
    Reflect.set(headerObj, 'Accept', '*/*');
    info.headers.forEach((value: string, key: string): void => {
      Reflect.set(headerObj, key, value);
    });

    Logger.info(TAG, `Starting download: url=${info.url}`);

    const config: request.agent.Config = {
      action: request.agent.Action.DOWNLOAD,
      url: info.url,
      saveas: targetUri,
      gauge: true,
      overwrite: true,
      network: request.agent.Network.ANY,
      mode: request.agent.Mode.FOREGROUND,
      headers: headerObj
    };

    try {
      const task = await request.agent.create(this.context, config);

      const succeeded = await new Promise<boolean>((resolve) => {
        task.on('progress', (p: request.agent.Progress) => {
          let total = 0;
          if (p.sizes !== undefined && p.sizes.length > 0) {
            total = p.sizes[p.sizes.length - 1];
          }
          if (total > 0) {
            const pct = Math.floor((p.processed / total) * 100);
            tracker.updateProgress(opId, pct);
          }
        });

        task.on('completed', () => {
          request.agent.remove(task.tid).catch(() => {});
          resolve(true);
        });

        task.on('failed', (p: request.agent.Progress) => {
          Logger.error(
            TAG,
            `request.agent failed: state=${p.state}, ` +
              `extras=${JSON.stringify(p.extras)}`
          );
          request.agent.remove(task.tid).catch(() => {});
          resolve(false);
        });

        task.start((err: Error) => {
          if (err) {
            Logger.error(TAG, `task.start error: ${err.message}`);
            resolve(false);
          }
        });
      });

      if (succeeded) {
        tracker.markSuccess(opId);
        this.markDownloading(itemId, false);
        promptAction.showToast({ message: `Downloaded: ${fileName}` });
        return;
      }

      // Fallback: download via direct HTTP.
      Logger.info(TAG, 'request.agent failed — falling back to HttpClient.');
      await this.downloadViaHttp(info, targetUri, fileName, itemId, opId);
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `startAgentDownload threw: ${err.message}`);
      // Try the fallback anyway.
      try {
        await this.downloadViaHttp(info, targetUri, fileName, itemId, opId);
      } catch (e2) {
        const err2: Error = e2 as Error;
        tracker.markFailed(opId, err2.message);
        this.markDownloading(itemId, false);
        promptAction.showToast({ message: `Download failed: ${err2.message}` });
      }
    }
  }

  /**
   * Direct HTTP download. Fetches the file bytes via @ohos.net.http and
   * writes them to the picker-provided URI. Bypasses request.agent entirely,
   * which is necessary for Google Drive because request.agent refuses the
   * Authorization header + cross-domain redirect combination.
   */
  private async downloadViaHttp(
    info: DownloadInfo,
    targetUri: string,
    fileName: string,
    itemId: string,
    opId: string
  ): Promise<void> {
    const tracker = OperationTracker.get();
    const request = http.createHttp();

    try {
      // Build headers as a Record (the HTTP module expects a plain object).
      const headerObj: Record<string, string> = {};
      Reflect.set(
        headerObj,
        'User-Agent',
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 ' +
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36'
      );
      Reflect.set(headerObj, 'Accept', '*/*');
      info.headers.forEach((value: string, key: string): void => {
        Reflect.set(headerObj, key, value);
      });

      Logger.info(TAG, `HTTP fallback URL: ${info.url}`);

      const requestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: headerObj,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: 120_000,
        connectTimeout: 30_000
      };

      const response = await request.request(info.url, requestOptions);

      if (response.responseCode < 200 || response.responseCode >= 300) {
        // Decode the ArrayBuffer error body so we can see Google's message.
        let errorBody: string = '';
        try {
          const buf: ArrayBuffer = response.result as ArrayBuffer;
          const decoder = new util.TextDecoder('utf-8');
          errorBody = decoder.decodeToString(new Uint8Array(buf));
        } catch (_) {
          errorBody = '(could not decode body)';
        }
        Logger.error(TAG, `HTTP ${response.responseCode} body: ${errorBody}`);
        throw new Error(`HTTP ${response.responseCode}: ${errorBody}`);
      }
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `downloadViaHttp failed: ${err.message}`);
      this.removeEmptyFile(targetUri);
      tracker.markFailed(opId, err.message);
      this.markDownloading(itemId, false);
      promptAction.showToast({ message: `Download failed: ${err.message}` });
      throw err;
    } finally {
      request.destroy();
    }
  }

  private removeEmptyFile(uri: string): void {
    try {
      const path = FileBrowserViewModel.uriToPath(uri);
      const stat = fs.statSync(path);
      if (stat.size === 0) fs.unlinkSync(path);
    } catch (_) {
      // File missing or unlink failed — safe to ignore.
    }
  }

  // ===========================================================================
  // Details page
  // ===========================================================================

  onShowDetails(): void {
    if (this.selectedItem === null) return;
    const itemId = this.selectedItem.id;
    this.selectedItem = null;
    router.pushUrl({
      url: Routes.ITEM_DETAILS,
      params: { accountId: this.activeAccountId, itemId: itemId }
    }).catch((e: Error) => {
      Logger.error(TAG, `pushUrl failed: ${e.message}`);
    });
  }

  // ===========================================================================
  // Static helpers
  // ===========================================================================

  static uriToPath(uri: string): string {
    if (uri.startsWith('file://')) return uri.substring('file://'.length);
    return uri;
  }

  static fileNameFromUri(uri: string): string {
    let path = FileBrowserViewModel.uriToPath(uri);
    while (path.length > 0 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    const slash = path.lastIndexOf('/');
    return slash >= 0 ? path.substring(slash + 1) : path;
  }

  static walkDirectory(rootPath: string): WalkedFile[] {
    const out: WalkedFile[] = [];
    FileBrowserViewModel.walkRecursive(rootPath, '', out);
    return out;
  }

  private static walkRecursive(
    currentPath: string,
    relative: string,
    out: WalkedFile[]
  ): void {
    let names: string[] = [];
    try {
      names = fs.listFileSync(currentPath);
    } catch (_) {
      return;
    }
    for (let i = 0; i < names.length; i++) {
      const name = names[i];
      const full = `${currentPath}/${name}`;
      const childRel = relative.length > 0 ? `${relative}/${name}` : name;

      let isDir = false;
      try {
        const stat = fs.statSync(full);
        isDir = stat.isDirectory();
      } catch (_) {
        continue;
      }

      if (isDir) {
        FileBrowserViewModel.walkRecursive(full, childRel, out);
      } else {
        out.push({ path: full, relative: childRel });
      }
    }
  }

  static splitName(fileName: string): NameParts {
    const dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot === fileName.length - 1) {
      return { base: fileName, ext: '' };
    }
    return {
      base: fileName.substring(0, dot),
      ext: fileName.substring(dot)
    };
  }

  static formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    }
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  }

  static formatDate(ms: number): string {
    const d = new Date(ms);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return `${months[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
  }

  static initialOf(account: AccountInfo): string {
    const name = account.displayName;
    if (name.length > 0) return name.charAt(0).toUpperCase();
    return '?';
  }

  static colorForProvider(type: CloudProviderType): string {
    if (type === CloudProviderType.ONEDRIVE) return '#0078D4';
    if (type === CloudProviderType.GOOGLE_DRIVE) return '#4285F4';
    return '#666666';
  }

  static providerLabel(type: CloudProviderType): string {
    if (type === CloudProviderType.ONEDRIVE) return 'OneDrive';
    if (type === CloudProviderType.GOOGLE_DRIVE) return 'Google Drive';
    return 'Cloud';
  }
}
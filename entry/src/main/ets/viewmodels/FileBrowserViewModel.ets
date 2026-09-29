import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { fileUri } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import { Want, wantConstant } from '@kit.AbilityKit';
import { CloudProviderFactory } from '../core/providers/CloudProviderFactory';
import { CloudProviderType } from '../core/models/CloudProviderType';
import { ICloudProvider } from '../core/interfaces/ICloudProvider';
import { CloudItem } from '../core/models/CloudItem';
import { CloudItemType } from '../core/models/CloudItemType';
import { AccountInfo, providerFromAccountId } from '../core/models/AccountInfo';
import { AuthManager } from '../core/auth/AuthManager';
import { DownloadInfo } from '../core/models/DownloadInfo';
import {
  Operation, OperationType, OperationStatus, OperationItemKind,
  RetryPayload, canRetry
} from '../core/models/Operation';
import { OperationTracker } from '../core/services/OperationTracker';
import { OfflineStore, OfflineFileRecord } from '../core/services/OfflineStore';
import { HttpClient, HttpRequestOptions } from '../core/network/HttpClient';
import { LocalFileService } from '../utils/FileUtil';
import { formatError } from '../utils/ErrorFormatter';
import { Logger } from '../utils/Logger';
import { Routes } from '../utils/RouteConstants';

const TAG: string = 'FileBrowserViewModel';

const HIDDEN_PICKER_FOLDER_NAMES: string[] = ['Getting Started'];
const SEARCH_DEBOUNCE_MS: number = 400;

const FOLDER_DOWNLOAD_ENABLED: boolean = false;
const UPLOAD_FOLDER_ENABLED: boolean = false;

// =============================================================================
// Exported types
// =============================================================================

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

export interface ActivityGroup {
  dateLabel: string;
  operations: Operation[];
}

export const ACTIVITY_TAB_ALL: string = 'all';
export const ACTIVITY_TAB_PENDING: string = 'pending';
export const ACTIVITY_TAB_SUCCESS: string = 'success';
export const ACTIVITY_TAB_FAILED: string = 'failed';

// =============================================================================
// Internal types
// =============================================================================

interface NameParts {
  base: string;
  ext: string;
}

interface WalkedFile {
  path: string;
  relative: string;
}

interface DownloadTask {
  cloudId: string;
  relativePath: string;
  kind: OperationItemKind;
}

interface TaskCounter {
  total: number;
}

// =============================================================================
// ViewModel
// =============================================================================

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
  createFolderTargetId: string = 'root';

  // ---- Tasks panel ----
  isActivityPanelOpen: boolean = false;
  activityTab: string = ACTIVITY_TAB_ALL;
  operations: Operation[] = [];

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
    await this.loadOfflineIds();

    const activeId: string = await AuthManager.getActiveAccountId();
    if (activeId.length === 0) {
      router.replaceUrl({ url: Routes.ONBOARDING });
      return;
    }
    await this.activateAccount(activeId);
    await this.refreshAccounts();
  }

  async onPageShow(): Promise<void> {
    const newActiveId: string = await AuthManager.getActiveAccountId();
    const accountChanged: boolean = newActiveId !== this.activeAccountId;

    await this.refreshAccounts();

    if (accountChanged || this.cloudProvider === null) {
      await this.activateAccount(newActiveId);
      await this.loadOfflineIds();
      return;
    }

    await this.loadFolder(this.currentFolderId);
    await this.loadOfflineIds();
  }

  // ===========================================================================
  // Accounts
  // ===========================================================================

  private async refreshAccounts(): Promise<void> {
    const list: AccountInfo[] = await AuthManager.getAccounts();
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
      const a: AccountInfo = accounts[i];
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
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `loadFolder failed: ${readable}`);
      this.errorMessage = readable;
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
      } catch (_) { /* not attached */ }
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

    const trimmed: string = q.trim();
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
    const query: string = this.searchQuery.trim();
    if (query.length === 0) {
      this.isSearching = false;
      return;
    }

    try {
      const results: CloudItem[] = await this.cloudProvider.search(query);
      this.searchResults = results;
      this.searchError = '';
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `search failed: ${readable}`);
      this.searchError = readable;
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

  openUploadMenu(): void { this.showUploadMenu = true; }
  closeUploadMenu(): void { this.showUploadMenu = false; }

  isUploadFolderEnabled(): boolean {
    return UPLOAD_FOLDER_ENABLED;
  }

  async onUploadFile(): Promise<void> {
    if (this.cloudProvider === null || this.context === null) return;

    const ctx: common.UIAbilityContext = this.context;
    const provider: ICloudProvider = this.cloudProvider;

    this.closeUploadMenu();

    try {
      const p = new picker.DocumentViewPicker(ctx);
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 100;

      const uris: string[] = await p.select(options);
      if (uris === null || uris === undefined || uris.length === 0) return;

      Logger.info(TAG, `Upload: ${uris.length} file(s) selected`);

      let existing: CloudItem[] = [];
      try {
        existing = await provider.listChildren(this.currentFolderId);
      } catch (e) {
        const readable: string = formatError(e as Error);
        Logger.error(TAG, `listChildren failed before upload: ${readable}`);
      }

      const takenNames: string[] = [];
      for (let i = 0; i < existing.length; i++) {
        const n: string | undefined = existing[i].name;
        if (n !== undefined && n !== null && n.length > 0) {
          takenNames.push(n.toLowerCase());
        }
      }

      const tracker: OperationTracker = OperationTracker.get();

      // ===================================================================
      // PHASE 0 — Copy every picked file to the sandbox.
      //
      // Picker URIs are session-scoped. Copying now (while the grant is
      // still valid) produces a sandbox path that survives app restarts,
      // so retries never hit "Operation not permitted".
      // ===================================================================
      const sandboxPaths: string[] = [];
      const uploadNames: string[] = [];
      const opIds: string[] = [];

      for (let i = 0; i < uris.length; i++) {
        const uri: string = uris[i];

        if (uri === undefined || uri === null || uri.length === 0) {
          Logger.warn(TAG, `Skipping empty URI at index ${i}`);
          continue;
        }

        const originalName: string =
          FileBrowserViewModel.fileNameFromUri(uri);
        const safeName: string = originalName.length > 0
          ? originalName
          : `file_${i + 1}`;

        const finalName: string =
          FileBrowserViewModel.findAvailableName(safeName, takenNames);
        takenNames.push(finalName.toLowerCase());

        let sandboxPath: string = '';
        try {
          sandboxPath = await this.copyPickerUriToSandbox(uri, finalName);
        } catch (e) {
          const readable: string = formatError(e as Error);
          Logger.error(
            TAG,
            `Failed to prepare "${finalName}": ${readable}`
          );
          const failedPayload: RetryPayload = {
            parentId: this.currentFolderId,
            localUri: uri
          };
          const failedId: string = tracker.register(
            OperationType.UPLOAD, finalName, '', OperationItemKind.FILE,
            i + 1, uris.length, failedPayload
          );
          tracker.markFailed(failedId, `Could not prepare file: ${readable}`);
          continue;
        }

        const uploadPayload: RetryPayload = {
          parentId: this.currentFolderId,
          localUri: sandboxPath
        };
        const opId: string = tracker.register(
          OperationType.UPLOAD,
          finalName,
          '',
          OperationItemKind.FILE,
          i + 1,
          uris.length,
          uploadPayload
        );

        sandboxPaths.push(sandboxPath);
        uploadNames.push(finalName);
        opIds.push(opId);
      }

      // ===================================================================
      // PHASE 2 — Execute the batch sequentially.
      // ===================================================================
      let success: number = 0;
      let failed: number = 0;

      for (let i = 0; i < opIds.length; i++) {
        tracker.markRunning(opIds[i]);

        try {
          await provider.uploadFile(
            this.currentFolderId, uploadNames[i], sandboxPaths[i]
          );
          tracker.markSuccess(opIds[i]);
          success++;

          try {
            fs.unlinkSync(sandboxPaths[i]);
          } catch (_) { /* already gone */ }
        } catch (e) {
          const readable: string = formatError(e as Error);
          Logger.error(
            TAG,
            `upload "${uploadNames[i]}" failed: ${readable}`
          );
          tracker.markFailed(opIds[i], readable);
          failed++;
        }
      }

      await this.loadFolder(this.currentFolderId);

      if (failed === 0) {
        promptAction.showToast({
          message: success === 1
            ? `Uploaded 1 file`
            : `Uploaded ${success} files`
        });
      } else {
        promptAction.showToast({
          message: `Uploaded ${success}, failed ${failed}`
        });
      }
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.warn(TAG, `upload cancelled or failed: ${readable}`);
    }
  }

  async onUploadFolder(): Promise<void> {
    if (this.cloudProvider === null || this.context === null) return;

    const ctx: common.UIAbilityContext = this.context;
    const provider: ICloudProvider = this.cloudProvider;

    this.closeUploadMenu();

    try {
      const p = new picker.DocumentViewPicker(ctx);
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.selectMode = picker.DocumentSelectMode.FOLDER;

      const uris: string[] = await p.select(options);
      if (uris === null || uris === undefined || uris.length === 0) return;

      const rootUri: string = uris[0];
      const rootName: string = FileBrowserViewModel.fileNameFromUri(rootUri);
      const rootPath: string = FileBrowserViewModel.uriToPath(rootUri);

      const files: WalkedFile[] = FileBrowserViewModel.walkDirectory(rootPath);

      if (files.length === 0) {
        promptAction.showToast({ message: 'The selected folder is empty' });
        return;
      }

      const tracker: OperationTracker = OperationTracker.get();

      let rootFolderId: string = '';
      try {
        const created: CloudItem = await provider.createFolder(
          this.currentFolderId, rootName
        );
        rootFolderId = created.id;
      } catch (e) {
        const siblings: CloudItem[] =
          await provider.listChildren(this.currentFolderId);
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
        const f: WalkedFile = files[i];
        const parts: string[] = f.relative.split('/');
        const name: string = parts[parts.length - 1];
        const dirRel: string = parts.slice(0, -1).join('/');

        const opId: string = tracker.register(
          OperationType.UPLOAD,
          f.relative,
          '',
          OperationItemKind.FILE,
          i + 1,
          files.length
        );
        tracker.markRunning(opId);

        try {
          const parentId: string =
            await this.ensureFolderPath(
              dirRel, folderCache, rootFolderId, provider
            );
          await provider.uploadFile(parentId, name, `file://${f.path}`);
          tracker.markSuccess(opId);
        } catch (e) {
          const readable: string = formatError(e as Error);
          Logger.error(TAG, `upload ${f.relative} failed: ${readable}`);
          tracker.markFailed(opId, readable);
        }
      }

      await this.loadFolder(this.currentFolderId);
      promptAction.showToast({ message: `Uploaded ${files.length} files` });
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.warn(TAG, `upload folder cancelled or failed: ${readable}`);
    }
  }

  private async ensureFolderPath(
    relative: string,
    cache: Map<string, string>,
    rootFolderId: string,
    provider: ICloudProvider
  ): Promise<string> {
    if (relative.length === 0) return rootFolderId;

    const cached: string | undefined = cache.get(relative);
    if (cached !== undefined) return cached;

    const parts: string[] = relative.split('/');
    let currentId: string = rootFolderId;
    let currentRel: string = '';

    for (let i = 0; i < parts.length; i++) {
      const part: string = parts[i];
      currentRel = currentRel.length > 0 ? `${currentRel}/${part}` : part;

      const existing: string | undefined = cache.get(currentRel);
      if (existing !== undefined) {
        currentId = existing;
        continue;
      }

      try {
        const created: CloudItem = await provider.createFolder(currentId, part);
        currentId = created.id;
        cache.set(currentRel, currentId);
      } catch (e) {
        const siblings: CloudItem[] = await provider.listChildren(currentId);
        let foundId: string = '';
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

  selectedCount(): number { return this.selectedIds.length; }
  hasSelection(): boolean { return this.selectedIds.length > 0; }

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
    const idx: number = this.selectedIds.indexOf(itemId);
    if (idx >= 0) {
      const next: string[] = this.selectedIds.slice();
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
      const it: CloudItem = this.items[i];
      if (this.selectedIds.indexOf(it.id) >= 0) out.push(it);
    }
    return out;
  }

  private getSelectedFolders(selected: CloudItem[]): CloudItem[] {
    const out: CloudItem[] = [];
    for (let i = 0; i < selected.length; i++) {
      if (selected[i].type === CloudItemType.FOLDER) out.push(selected[i]);
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
    const label: string = this.activeAccount.displayName;
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
    const id: string = this.activeAccountId;
    if (id.length === 0) return;
    try {
      await AuthManager.signOut(id);
      CloudProviderFactory.evict(id);
      const remaining: AccountInfo[] = await AuthManager.getAccounts();
      this.accounts = remaining;
      this.groups = this.buildGroups(remaining);
      if (remaining.length === 0) {
        router.replaceUrl({ url: Routes.ONBOARDING });
        return;
      }
      await this.activateAccount(remaining[0].accountId);
      await this.refreshAccounts();
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `signOut failed: ${readable}`);
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
    const ctx: common.UIAbilityContext = this.context;
    ctx.terminateSelf().catch((e: Error) => {
      Logger.error(TAG, `terminateSelf failed: ${e.message}`);
    });
  }

  // ===========================================================================
  // Tasks panel
  // ===========================================================================

  openActivityPanel(): void { this.isActivityPanelOpen = true; }
  closeActivityPanel(): void { this.isActivityPanelOpen = false; }

  setActivityTab(tab: string): void { this.activityTab = tab; }

  clearCompletedOperations(): void {
    OperationTracker.get().clearCompleted();
  }

  clearFinishedOperations(): void {
    OperationTracker.get().clearFinished();
  }

  forceClearAllOperations(): void {
    promptAction.showDialog({
      title: 'Force clear all?',
      message: 'This removes every entry from the task list, including ones still running. Background work will continue but you will no longer see its status. Continue?',
      buttons: [
        { text: 'Cancel', color: '#666666' },
        { text: 'Force clear', color: '#D32F2F' }
      ]
    })
      .then((r: promptAction.ShowDialogSuccessResponse) => {
        if (r.index === 1) {
          OperationTracker.get().forceClearAll();
          promptAction.showToast({ message: 'Task list cleared' });
        }
      })
      .catch(() => { /* dismissed */ });
  }

  static operationMatchesTab(op: Operation, tab: string): boolean {
    if (tab === ACTIVITY_TAB_ALL) return true;
    if (tab === ACTIVITY_TAB_PENDING) {
      return op.status === OperationStatus.QUEUED
        || op.status === OperationStatus.RUNNING;
    }
    if (tab === ACTIVITY_TAB_SUCCESS) {
      return op.status === OperationStatus.SUCCESS;
    }
    return op.status === OperationStatus.FAILED
      || op.status === OperationStatus.CANCELLED;
  }

  static dateLabel(ms: number): string {
    const now = new Date();
    const todayStart: number = new Date(
      now.getFullYear(), now.getMonth(), now.getDate()
    ).getTime();
    const yesterdayStart: number = todayStart - 24 * 60 * 60 * 1000;

    if (ms >= todayStart) return 'Today';
    if (ms >= yesterdayStart) return 'Yesterday';

    const d = new Date(ms);
    const months: string[] = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return `${months[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
  }

  // ===========================================================================
  // Retry — preserved but hidden in the page behind RETRY_ENABLED flag
  // ===========================================================================

  async retrySingleOperation(opId: string): Promise<void> {
    const tracker: OperationTracker = OperationTracker.get();
    const op: Operation | null = tracker.getById(opId);
    if (op === null) return;

    if (!canRetry(op)) {
      promptAction.showToast({ message: 'This task cannot be retried' });
      return;
    }

    // Legacy upload tasks registered before sandbox-copy was added still
    // carry a picker URI. Re-pick the file instead.
    if (op.type === OperationType.UPLOAD) {
      const localUri: string =
        op.retryPayload !== undefined
          && op.retryPayload.localUri !== undefined
          ? op.retryPayload.localUri
          : '';
      if (!this.isSandboxPath(localUri)) {
        await this.reselectAndRetryUpload(op);
        return;
      }
    }

    tracker.markRunning(opId);
    await this.executeOperationPayload(opId, op);
  }

  async retryAllFailed(): Promise<void> {
    const tracker: OperationTracker = OperationTracker.get();
    const all: Operation[] = tracker.getAll();

    const retryable: Operation[] = [];
    let skipped: number = 0;

    for (let i = 0; i < all.length; i++) {
      const op: Operation = all[i];
      if (!canRetry(op)) continue;

      if (op.type === OperationType.UPLOAD) {
        const localUri: string =
          op.retryPayload !== undefined
            && op.retryPayload.localUri !== undefined
            ? op.retryPayload.localUri
            : '';
        if (!this.isSandboxPath(localUri)) {
          skipped++;
          continue;
        }
      }
      retryable.push(op);
    }

    if (retryable.length === 0 && skipped === 0) {
      promptAction.showToast({ message: 'No failed tasks to retry' });
      return;
    }

    if (retryable.length === 0 && skipped > 0) {
      promptAction.showToast({
        message: skipped === 1
          ? 'Tap ↻ on the failed upload to re-select the file'
          : 'Tap ↻ on each failed upload to re-select the files'
      });
      return;
    }

    for (let i = 0; i < retryable.length; i++) {
      tracker.markRunning(retryable[i].id);
    }

    let success: number = 0;
    let failed: number = 0;

    for (let i = 0; i < retryable.length; i++) {
      const op: Operation = retryable[i];
      await this.executeOperationPayload(op.id, op);

      const after: Operation | null = tracker.getById(op.id);
      if (after === null) continue;
      if (after.status === OperationStatus.SUCCESS) success++;
      else failed++;
    }

    if (skipped > 0) {
      promptAction.showToast({
        message: `Retried ${success}, ${skipped} need re-selection (tap ↻)`
      });
    } else if (failed === 0) {
      promptAction.showToast({
        message: `Retried ${success} task${success === 1 ? '' : 's'}`
      });
    } else {
      promptAction.showToast({
        message: `Retried ${success}, failed ${failed}`
      });
    }
  }

  private async executeOperationPayload(
    opId: string,
    op: Operation
  ): Promise<void> {
    if (this.cloudProvider === null) return;
    const provider: ICloudProvider = this.cloudProvider;
    const tracker: OperationTracker = OperationTracker.get();
    const payload: RetryPayload | undefined = op.retryPayload;
    if (payload === undefined) return;

    try {
      if (op.type === OperationType.DELETE) {
        const itemId: string = payload.itemId !== undefined
          ? payload.itemId : op.itemId;
        await provider.deleteItem(itemId);
        tracker.markSuccess(opId);
        return;
      }

      if (op.type === OperationType.UPLOAD) {
        const parentId: string = payload.parentId !== undefined
          ? payload.parentId : this.currentFolderId;
        const localUri: string = payload.localUri !== undefined
          ? payload.localUri : '';

        if (localUri.length === 0) {
          throw new Error('Missing local file for retry');
        }
        if (!this.isSandboxPath(localUri)) {
          throw new Error(
            'Source file is from a previous session. Tap ↻ to re-select it.'
          );
        }

        await provider.uploadFile(parentId, op.itemName, localUri);
        tracker.markSuccess(opId);

        try {
          const path: string = FileBrowserViewModel.uriToPath(localUri);
          fs.unlinkSync(path);
        } catch (_) { /* already gone */ }
        return;
      }

      if (op.type === OperationType.MOVE) {
        const targetId: string = payload.targetFolderId !== undefined
          ? payload.targetFolderId : '';
        if (targetId.length === 0) {
          throw new Error('Missing destination for retry');
        }
        let finalName: string | undefined = undefined;
        const sibling: CloudItem | null =
          await this.findSiblingByName(targetId, op.itemName);
        if (sibling !== null) {
          finalName = await this.findAvailableCloudName(op.itemName, targetId);
        }
        await provider.moveItem(op.itemId, targetId, finalName);
        tracker.markSuccess(opId);
        return;
      }

      if (op.type === OperationType.COPY) {
        const targetId: string = payload.targetFolderId !== undefined
          ? payload.targetFolderId : '';
        if (targetId.length === 0) {
          throw new Error('Missing destination for retry');
        }
        let finalName: string | undefined = undefined;
        const sibling: CloudItem | null =
          await this.findSiblingByName(targetId, op.itemName);
        if (sibling !== null) {
          finalName = await this.findAvailableCloudName(op.itemName, targetId);
        }
        const monitorUrl: string | null =
          await provider.copyItem(op.itemId, targetId, finalName);
        if (monitorUrl !== null && monitorUrl.length > 0) {
          await this.pollCopyMonitor(monitorUrl, opId);
        } else {
          tracker.markSuccess(opId);
        }
        return;
      }

      if (op.type === OperationType.DOWNLOAD) {
        const targetUri: string = payload.targetUri !== undefined
          ? payload.targetUri : '';
        if (targetUri.length === 0) {
          throw new Error('Missing download destination for retry');
        }
        const info: DownloadInfo = await provider.getDownloadInfo(op.itemId);
        await this.downloadViaHttp(info, targetUri, op.itemName, op.itemId, opId);
        return;
      }

      throw new Error(`Retry not supported for type: ${op.type}`);
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `retry ${op.itemName} failed: ${readable}`);
      tracker.markFailed(opId, readable);
    }
  }

  private async reselectAndRetryUpload(op: Operation): Promise<void> {
    if (this.cloudProvider === null || this.context === null) return;
    const ctx: common.UIAbilityContext = this.context;
    const provider: ICloudProvider = this.cloudProvider;
    const tracker: OperationTracker = OperationTracker.get();

    let confirmed: boolean = false;
    try {
      const result: promptAction.ShowDialogSuccessResponse =
        await promptAction.showDialog({
          title: 'Select the file again',
          message: `"${op.itemName}" was picked in a previous session. ` +
            `Please select it again to retry the upload.`,
          buttons: [
            { text: 'Cancel', color: '#666666' },
            { text: 'Select file', color: '#0A5BD3' }
          ]
        });
      confirmed = result.index === 1;
    } catch (_) {
      return;
    }
    if (!confirmed) return;

    let newUri: string = '';
    try {
      const p = new picker.DocumentViewPicker(ctx);
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;

      const uris: string[] = await p.select(options);
      if (uris === null || uris === undefined || uris.length === 0) return;
      newUri = uris[0];
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.warn(TAG, `reselect picker cancelled: ${readable}`);
      return;
    }

    const newName: string = FileBrowserViewModel.fileNameFromUri(newUri);
    const finalName: string = newName.length > 0 ? newName : op.itemName;

    let sandboxPath: string = '';
    try {
      sandboxPath = await this.copyPickerUriToSandbox(newUri, finalName);
    } catch (e) {
      const readable: string = formatError(e as Error);
      promptAction.showToast({
        message: `Could not prepare file: ${readable}`
      });
      return;
    }

    const parentId: string =
      op.retryPayload !== undefined
        && op.retryPayload.parentId !== undefined
        ? op.retryPayload.parentId
        : this.currentFolderId;

    const freshPayload: RetryPayload = {
      parentId: parentId,
      localUri: sandboxPath
    };
    const freshId: string = tracker.register(
      OperationType.UPLOAD,
      finalName,
      '',
      OperationItemKind.FILE,
      0,
      0,
      freshPayload
    );
    tracker.markRunning(freshId);

    try {
      await provider.uploadFile(parentId, finalName, sandboxPath);
      tracker.markSuccess(freshId);

      try { fs.unlinkSync(sandboxPath); } catch (_) { /* gone */ }

      await this.loadFolder(this.currentFolderId);
      promptAction.showToast({ message: `Uploaded "${finalName}"` });
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `reselect upload failed: ${readable}`);
      tracker.markFailed(freshId, readable);
      promptAction.showToast({ message: `Upload failed: ${readable}` });
    }
  }

  // ===========================================================================
  // Item actions sheet
  // ===========================================================================

  onShowItemActions(item: CloudItem): void { this.selectedItem = item; }
  closeActionsSheet(): void { this.selectedItem = null; }

  isOffline(itemId: string): boolean { return this.offlineIds.indexOf(itemId) >= 0; }
  isDownloading(itemId: string): boolean { return this.downloadingIds.indexOf(itemId) >= 0; }

  private markDownloading(itemId: string, on: boolean): void {
    const idx: number = this.downloadingIds.indexOf(itemId);
    if (on && idx < 0) this.downloadingIds = [...this.downloadingIds, itemId];
    else if (!on && idx >= 0) {
      const next: string[] = this.downloadingIds.slice();
      next.splice(idx, 1);
      this.downloadingIds = next;
    }
  }

  canDownloadSelected(): boolean {
    if (this.selectedItem === null) return false;
    if (this.isDownloading(this.selectedItem.id)) return false;
    if (!FOLDER_DOWNLOAD_ENABLED
      && this.selectedItem.type === CloudItemType.FOLDER) {
      return false;
    }
    return true;
  }

  // ===========================================================================
  // Offline files
  // ===========================================================================

  private async loadOfflineIds(): Promise<void> {
    const records: OfflineFileRecord[] = await OfflineStore.getAll();
    const validRecords: OfflineFileRecord[] = [];
    const ids: string[] = [];

    for (let i = 0; i < records.length; i++) {
      const r: OfflineFileRecord = records[i];
      try {
        fs.accessSync(r.localPath);
        validRecords.push(r);
        ids.push(r.cloudId);
      } catch (_) {
        Logger.warn(TAG, `Pruning missing offline file: ${r.name}`);
      }
    }

    if (validRecords.length !== records.length) {
      await OfflineStore.replaceAll(validRecords);
    }
    this.offlineIds = ids;
  }

  async onToggleOffline(isOn: boolean): Promise<void> {
    if (this.selectedItem === null || this.cloudProvider === null) return;

    const item: CloudItem = this.selectedItem;

    if (item.type === CloudItemType.FOLDER) {
      promptAction.showToast({ message: 'Folders cannot be made available offline' });
      return;
    }

    if (isOn) {
      await this.saveForOffline(item);
    } else {
      await this.removeFromOffline(item);
    }
  }

  private async saveForOffline(item: CloudItem): Promise<void> {
    if (this.cloudProvider === null || this.context === null) return;

    const ctx: common.UIAbilityContext = this.context;
    const provider: ICloudProvider = this.cloudProvider;
    const accountId: string = this.activeAccountId;

    const tracker: OperationTracker = OperationTracker.get();
    const opId: string = tracker.register(
      OperationType.DOWNLOAD, item.name, item.id, OperationItemKind.FILE, 0, 0
    );
    tracker.markRunning(opId);
    this.markDownloading(item.id, true);

    try {
      const offlineDir: string = ctx.filesDir;
      const safeId: string = item.id.replace(/[^a-zA-Z0-9_-]/g, '_');
      const safeName: string = item.name.replace(/[^a-zA-Z0-9._-]/g, '_');
      const prefix: string = safeId.length > 32 ? safeId.substring(0, 32) : safeId;
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
        accountId: accountId,
        provider: provider.providerType,
        name: item.name,
        localPath: localPath,
        mimeType: item.mimeType !== undefined ? item.mimeType : '',
        size: item.size !== undefined ? item.size : bytes.byteLength,
        downloadedAt: Date.now()
      };
      await OfflineStore.add(record);

      if (this.offlineIds.indexOf(item.id) < 0) {
        this.offlineIds = [...this.offlineIds, item.id];
      }

      tracker.markSuccess(opId);
      promptAction.showToast({ message: `"${item.name}" available offline` });
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `saveForOffline failed: ${readable}`);
      tracker.markFailed(opId, readable);
      promptAction.showToast({ message: `Offline download failed: ${readable}` });
    } finally {
      this.markDownloading(item.id, false);
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

    const idx: number = this.offlineIds.indexOf(item.id);
    if (idx >= 0) {
      const next: string[] = this.offlineIds.slice();
      next.splice(idx, 1);
      this.offlineIds = next;
    }
    promptAction.showToast({ message: `"${item.name}" removed from offline` });
  }

  async openOfflineFile(item: CloudItem): Promise<void> {
    if (this.context === null) return;
    const ctx: common.UIAbilityContext = this.context;

    const record: OfflineFileRecord | null =
      await OfflineStore.getById(item.id);
    if (record === null) {
      promptAction.showToast({ message: 'File is not available offline' });
      return;
    }

    try {
      fs.accessSync(record.localPath);
    } catch (_) {
      await OfflineStore.remove(item.id);
      const idx: number = this.offlineIds.indexOf(item.id);
      if (idx >= 0) {
        const next: string[] = this.offlineIds.slice();
        next.splice(idx, 1);
        this.offlineIds = next;
      }
      promptAction.showToast({ message: 'Offline file is no longer available' });
      return;
    }

    const mime: string = record.mimeType.length > 0
      ? record.mimeType
      : 'application/octet-stream';

    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: `file://${record.localPath}`,
        type: mime,
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
      };
      await ctx.startAbility(want);
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `startAbility failed: ${readable}`);
      promptAction.showToast({ message: `Cannot open file: ${readable}` });
    }
  }

  // ===========================================================================
  // Rename
  // ===========================================================================

  onRenameItem(): void {
    if (this.selectedItem === null) return;
    this.renameText = this.selectedItem.name;
    this.showRenameDialog = true;
  }

  cancelRename(): void { this.showRenameDialog = false; }

  async performRename(): Promise<void> {
    if (this.selectedItem === null || this.cloudProvider === null) return;
    const newName: string = this.renameText.trim();
    if (newName.length === 0) {
      promptAction.showToast({ message: 'Name cannot be empty' });
      return;
    }
    if (newName === this.selectedItem.name) {
      this.showRenameDialog = false;
      return;
    }

    const targetId: string = this.selectedItem.id;
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
      const readable: string = formatError(e as Error);
      promptAction.showToast({ message: `Rename failed: ${readable}` });
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
    const count: number = items.length;
    const hasFolder: boolean = items.some((it: CloudItem): boolean =>
    it.type === CloudItemType.FOLDER);

    const title: string = count === 1 ? 'Delete' : `Delete ${count} items`;
    const subject: string = count === 1 ? `"${items[0].name}"` : `${count} items`;
    const extra: string = hasFolder
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
    const provider: ICloudProvider = this.cloudProvider;
    const tracker: OperationTracker = OperationTracker.get();

    const opIds: string[] = [];
    for (let i = 0; i < items.length; i++) {
      const it: CloudItem = items[i];
      const kind: OperationItemKind = it.type === CloudItemType.FOLDER
        ? OperationItemKind.FOLDER
        : OperationItemKind.FILE;
      const deletePayload: RetryPayload = { itemId: it.id };
      opIds.push(tracker.register(
        OperationType.DELETE, it.name, it.id, kind, i + 1, items.length,
        deletePayload
      ));
    }

    let success: number = 0;
    let failed: number = 0;

    for (let i = 0; i < items.length; i++) {
      tracker.markRunning(opIds[i]);

      try {
        await provider.deleteItem(items[i].id);
        tracker.markSuccess(opIds[i]);
        success++;
        const idx: number = this.offlineIds.indexOf(items[i].id);
        if (idx >= 0) {
          const next: string[] = this.offlineIds.slice();
          next.splice(idx, 1);
          this.offlineIds = next;
        }
      } catch (e) {
        const readable: string = formatError(e as Error);
        Logger.error(TAG, `delete ${items[i].name} failed: ${readable}`);
        tracker.markFailed(opIds[i], readable);
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
      const all: CloudItem[] = await this.cloudProvider.listChildren(folderId);
      const hidden: string[] = [];
      for (let i = 0; i < this.pickerItems.length; i++) {
        hidden.push(this.pickerItems[i].id);
      }

      const folders: CloudItem[] = [];
      for (let i = 0; i < all.length; i++) {
        const it: CloudItem = all[i];
        if (it.type !== CloudItemType.FOLDER) continue;
        if (hidden.indexOf(it.id) >= 0) continue;
        if (HIDDEN_PICKER_FOLDER_NAMES.indexOf(it.name) >= 0) continue;
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
    const target: Crumb = this.movePickerCrumbs[index];
    this.movePickerCrumbs = this.movePickerCrumbs.slice(0, index + 1);
    await this.loadMovePickerFolder(target.id);
  }

  async performPickerConfirm(): Promise<void> {
    if (this.pickerItems.length === 0 || this.cloudProvider === null) return;
    const items: CloudItem[] = this.pickerItems.slice();
    const targetId: string = this.movePickerFolderId;
    const mode: string = this.pickerMode;

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
    const provider: ICloudProvider = this.cloudProvider;
    const tracker: OperationTracker = OperationTracker.get();

    const conflicts: CloudItem[] = await this.findConflicts(items, targetId);
    let resolveMode: string = 'none';
    if (conflicts.length > 0) {
      resolveMode = await this.askBatchConflictChoice(conflicts);
      if (resolveMode === 'skip' && conflicts.length === items.length) {
        promptAction.showToast({ message: 'Move cancelled' });
        return;
      }
    }

    const opIds: string[] = [];
    for (let i = 0; i < items.length; i++) {
      const it: CloudItem = items[i];
      const kind: OperationItemKind = it.type === CloudItemType.FOLDER
        ? OperationItemKind.FOLDER
        : OperationItemKind.FILE;
      const movePayload: RetryPayload = { targetFolderId: targetId };
      opIds.push(tracker.register(
        OperationType.MOVE, it.name, it.id, kind, i + 1, items.length,
        movePayload
      ));
    }

    let success: number = 0;
    let failed: number = 0;

    for (let i = 0; i < items.length; i++) {
      const it: CloudItem = items[i];
      tracker.markRunning(opIds[i]);
      const hasConflict: boolean = conflicts.some(
        (c: CloudItem): boolean => c.id === it.id
      );

      try {
        if (!hasConflict) {
          await provider.moveItem(it.id, targetId);
        } else if (resolveMode === 'skip') {
          tracker.markCancelled(opIds[i]);
          continue;
        } else if (resolveMode === 'keep-both') {
          const newName: string =
            await this.findAvailableCloudName(it.name, targetId);
          await provider.moveItem(it.id, targetId, newName);
        } else if (resolveMode === 'replace') {
          const sibling: CloudItem | null =
            await this.findSiblingByName(targetId, it.name);
          if (sibling !== null) await provider.deleteItem(sibling.id);
          await provider.moveItem(it.id, targetId);
        }
        tracker.markSuccess(opIds[i]);
        success++;
      } catch (e) {
        const readable: string = formatError(e as Error);
        Logger.error(TAG, `move ${it.name} failed: ${readable}`);
        tracker.markFailed(opIds[i], readable);
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
    const provider: ICloudProvider = this.cloudProvider;
    const tracker: OperationTracker = OperationTracker.get();

    const conflicts: CloudItem[] = await this.findConflicts(items, targetId);
    let resolveMode: string = 'none';
    if (conflicts.length > 0) {
      resolveMode = await this.askBatchConflictChoice(conflicts);
      if (resolveMode === 'skip' && conflicts.length === items.length) {
        promptAction.showToast({ message: 'Copy cancelled' });
        return;
      }
    }

    const opIds: string[] = [];
    for (let i = 0; i < items.length; i++) {
      const it: CloudItem = items[i];
      const kind: OperationItemKind = it.type === CloudItemType.FOLDER
        ? OperationItemKind.FOLDER
        : OperationItemKind.FILE;
      const copyPayload: RetryPayload = { targetFolderId: targetId };
      opIds.push(tracker.register(
        OperationType.COPY, it.name, it.id, kind, i + 1, items.length,
        copyPayload
      ));
    }

    let success: number = 0;
    let failed: number = 0;

    for (let i = 0; i < items.length; i++) {
      const it: CloudItem = items[i];
      tracker.markRunning(opIds[i]);
      const hasConflict: boolean = conflicts.some(
        (c: CloudItem): boolean => c.id === it.id
      );

      try {
        let finalName: string | undefined = undefined;

        if (!hasConflict) {
          // no conflict
        } else if (resolveMode === 'skip') {
          tracker.markCancelled(opIds[i]);
          continue;
        } else if (resolveMode === 'keep-both') {
          finalName = await this.findAvailableCloudName(it.name, targetId);
        } else if (resolveMode === 'replace') {
          const sibling: CloudItem | null =
            await this.findSiblingByName(targetId, it.name);
          if (sibling !== null) await provider.deleteItem(sibling.id);
        }

        const monitorUrl: string | null =
          await provider.copyItem(it.id, targetId, finalName);

        if (monitorUrl !== null && monitorUrl.length > 0) {
          await this.pollCopyMonitor(monitorUrl, opIds[i]);
        } else {
          tracker.markSuccess(opIds[i]);
        }
        success++;
      } catch (e) {
        const readable: string = formatError(e as Error);
        Logger.error(TAG, `copy ${it.name} failed: ${readable}`);
        tracker.markFailed(opIds[i], readable);
        failed++;
      }
    }

    if (targetId === this.currentFolderId) {
      setTimeout(() => { this.loadFolder(this.currentFolderId); }, 900);
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
    const tracker: OperationTracker = OperationTracker.get();
    const maxAttempts: number = 600;
    const intervalMs: number = 1000;

    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      await this.sleep(intervalMs);

      try {
        const opts = new HttpRequestOptions();
        opts.method = http.RequestMethod.GET;

        const response = await HttpClient.requestWithHeaders(monitorUrl, opts);

        if (response.statusCode === 200) {
          tracker.markSuccess(opId);
          return;
        }

        if (response.statusCode === 202) {
          const pct: number = Math.min(95, Math.floor(((attempt + 1) / 30) * 100));
          tracker.updateProgress(opId, pct);
          continue;
        }

        if (response.statusCode >= 400) {
          throw new Error(
            `Copy monitor returned HTTP ${response.statusCode}: ${response.body}`
          );
        }
      } catch (e) {
        const readable: string = formatError(e as Error);
        Logger.warn(TAG, `copy monitor poll ${attempt + 1} failed: ${readable}`);
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
    const siblings: CloudItem[] = await this.cloudProvider.listChildren(targetId);
    const out: CloudItem[] = [];

    for (let i = 0; i < items.length; i++) {
      const sourceName: string = items[i].name.toLowerCase();
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
      const count: number = conflicts.length;
      const preview: string = count === 1
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
        .catch(() => { resolve('skip'); });
    });
  }

  private async findAvailableCloudName(
    originalName: string,
    targetFolderId: string
  ): Promise<string> {
    if (this.cloudProvider === null) return originalName;
    const siblings: CloudItem[] = await this.cloudProvider.listChildren(targetFolderId);
    const existing: string[] = [];
    for (let i = 0; i < siblings.length; i++) {
      existing.push(siblings[i].name.toLowerCase());
    }
    return FileBrowserViewModel.findAvailableName(originalName, existing);
  }

  private async findSiblingByName(
    targetFolderId: string,
    name: string
  ): Promise<CloudItem | null> {
    if (this.cloudProvider === null) return null;
    const siblings: CloudItem[] = await this.cloudProvider.listChildren(targetFolderId);
    const target: string = name.toLowerCase();
    for (let i = 0; i < siblings.length; i++) {
      if (siblings[i].name.toLowerCase() === target) return siblings[i];
    }
    return null;
  }

  // ===========================================================================
  // Create folder
  // ===========================================================================

  openCreateFolderPrompt(): void {
    this.createFolderTargetId = this.movePickerFolderId;
    this.newFolderName = '';
    this.showCreateFolderDialog = true;
  }

  openNewFolderPrompt(): void {
    this.closeUploadMenu();
    this.createFolderTargetId = this.currentFolderId;
    this.newFolderName = '';
    this.showCreateFolderDialog = true;
  }

  cancelCreateFolder(): void {
    this.showCreateFolderDialog = false;
    this.newFolderName = '';
  }

  async performCreateFolder(): Promise<void> {
    if (this.cloudProvider === null) return;
    const name: string = this.newFolderName.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: 'Folder name cannot be empty' });
      return;
    }

    this.isCreatingFolder = true;
    try {
      await this.cloudProvider.createFolder(this.createFolderTargetId, name);
      this.showCreateFolderDialog = false;
      this.newFolderName = '';

      if (this.createFolderTargetId === this.currentFolderId) {
        await this.loadFolder(this.currentFolderId);
      } else {
        await this.loadMovePickerFolder(this.createFolderTargetId);
      }
      promptAction.showToast({ message: `Folder "${name}" created` });
    } catch (e) {
      const readable: string = formatError(e as Error);
      promptAction.showToast({ message: `Create failed: ${readable}` });
    } finally {
      this.isCreatingFolder = false;
    }
  }

  // ===========================================================================
  // Download — single file
  // ===========================================================================

  async onDownloadItem(): Promise<void> {
    if (this.selectedItem === null || this.cloudProvider === null) return;

    const item: CloudItem = this.selectedItem;

    if (item.type === CloudItemType.FOLDER) {
      this.closeActionsSheet();
      if (!FOLDER_DOWNLOAD_ENABLED) {
        promptAction.showToast({ message: 'Folders cannot be downloaded' });
        return;
      }
      await this.downloadFolderAsZip(item);
      return;
    }

    this.closeActionsSheet();
    await this.downloadSingleFileWithPicker(item);
  }

  private async downloadSingleFileWithPicker(item: CloudItem): Promise<void> {
    if (this.cloudProvider === null || this.context === null) return;

    const saveUri: string | null = await this.pickSaveLocation(item.name);
    if (saveUri === null) {
      Logger.info(TAG, 'Single-file download cancelled at picker.');
      return;
    }

    const tracker: OperationTracker = OperationTracker.get();
    const dlPayload: RetryPayload = { targetUri: saveUri };
    const opId: string = tracker.register(
      OperationType.DOWNLOAD, item.name, item.id, OperationItemKind.FILE, 0, 0,
      dlPayload
    );
    tracker.markRunning(opId);
    this.markDownloading(item.id, true);

    try {
      const info: DownloadInfo = await this.cloudProvider.getDownloadInfo(item.id);
      await this.downloadViaHttp(info, saveUri, item.name, item.id, opId);
      promptAction.showToast({ message: `Downloaded: ${item.name}` });
    } catch (e) {
      const readable: string = formatError(e as Error);
      promptAction.showToast({ message: `Download failed: ${readable}` });
    }
  }

  // ===========================================================================
  // Download — batch
  // ===========================================================================

  async onBatchDownload(): Promise<void> {
    if (!this.hasSelection() || this.cloudProvider === null) return;

    const selected: CloudItem[] = this.getSelectedItems();
    const files: CloudItem[] = [];
    let folderCount: number = 0;
    for (let i = 0; i < selected.length; i++) {
      if (selected[i].type === CloudItemType.FOLDER) folderCount++;
      else files.push(selected[i]);
    }

    if (folderCount > 0) {
      if (!FOLDER_DOWNLOAD_ENABLED) {
        promptAction.showToast({
          message: folderCount === 1
            ? 'Folders cannot be downloaded'
            : 'Folders cannot be downloaded — deselect them and try again'
        });
        return;
      }
      this.exitSelectionMode();
      await this.downloadSelectionAsZip(files, this.getSelectedFolders(selected));
      return;
    }

    if (files.length === 0) {
      promptAction.showToast({ message: 'Select at least one file to download' });
      return;
    }

    if (files.length === 1) {
      this.exitSelectionMode();
      await this.downloadSingleFileWithPicker(files[0]);
      return;
    }

    this.exitSelectionMode();
    await this.downloadFilesToFolder(files);
  }

  private async downloadFilesToFolder(files: CloudItem[]): Promise<void> {
    if (this.cloudProvider === null) return;
    const provider: ICloudProvider = this.cloudProvider;

    const destUri: string | null = await this.pickDestinationFolder();
    if (destUri === null) return;

    const tracker: OperationTracker = OperationTracker.get();

    const opIds: string[] = [];
    for (let i = 0; i < files.length; i++) {
      const item: CloudItem = files[i];
      const targetUri: string =
        FileBrowserViewModel.appendToUri(destUri, item.name);
      const dlPayload: RetryPayload = { targetUri: targetUri };
      opIds.push(tracker.register(
        OperationType.DOWNLOAD,
        item.name,
        item.id,
        OperationItemKind.FILE,
        i + 1,
        files.length,
        dlPayload
      ));
    }

    let success: number = 0;
    let failed: number = 0;

    for (let i = 0; i < files.length; i++) {
      const item: CloudItem = files[i];
      tracker.markRunning(opIds[i]);
      this.markDownloading(item.id, true);

      try {
        const info: DownloadInfo = await provider.getDownloadInfo(item.id);
        const targetUri: string =
          FileBrowserViewModel.appendToUri(destUri, item.name);
        await this.downloadViaHttp(info, targetUri, item.name, item.id, opIds[i]);
        success++;
      } catch (e) {
        const readable: string = formatError(e as Error);
        Logger.error(TAG, `Download failed for ${item.name}: ${readable}`);
        failed++;
      }
    }

    if (failed === 0) {
      promptAction.showToast({ message: `Downloaded ${success} files` });
    } else {
      promptAction.showToast({ message: `Downloaded ${success}, failed ${failed}` });
    }
  }

  private async pickDestinationFolder(): Promise<string | null> {
    if (this.context === null) return null;
    const ctx: common.UIAbilityContext = this.context;

    try {
      const p = new picker.DocumentViewPicker(ctx);
      const options = new picker.DocumentSaveOptions();
      options.pickerMode = picker.DocumentPickerMode.DOWNLOAD;

      const result: string[] = await p.save(options);
      if (result === null || result === undefined || result.length === 0) {
        return null;
      }
      return result[0];
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.info(TAG, `pickDestinationFolder cancelled: ${readable}`);
      return null;
    }
  }

  private async pickSaveLocation(fileName: string): Promise<string | null> {
    if (this.context === null) return null;
    const ctx: common.UIAbilityContext = this.context;

    const documentPicker = new picker.DocumentViewPicker(ctx);
    const saveOptions = new picker.DocumentSaveOptions();
    saveOptions.newFileNames = [fileName];

    const result: string[] = await documentPicker.save(saveOptions);
    if (result === null || result === undefined || result.length === 0) {
      return null;
    }
    return result[0];
  }

  // ===========================================================================
  // Download — HTTP transfer
  // ===========================================================================

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

    const baseName: string = FileBrowserViewModel.basename(fileName);
    const sandboxPath: string = `${ctx.cacheDir}/${baseName}`;

    try {
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
      this.markDownloading(itemId, false);
      Logger.info(TAG, `Downloaded ${fileName} → ${targetUri}`);
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `downloadViaHttp failed for ${fileName}: ${readable}`);
      this.removeEmptyFile(targetUri);
      this.markDownloading(itemId, false);
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
      destFile = LocalFileService.openDestinationForWrite(targetUri);
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
      Logger.error(
        TAG,
        `Copy to destination failed for "${fileName}": ${readable}`
      );
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
      const path: string = FileBrowserViewModel.uriToPath(uri);
      const stat = fs.statSync(path);
      if (stat.size === 0) fs.unlinkSync(path);
    } catch (_) { /* ignore */ }
  }

  // ===========================================================================
  // Download — folder ZIP (preserved for future re-enable)
  // ===========================================================================

  private async downloadFolderAsZip(folder: CloudItem): Promise<void> {
    if (this.cloudProvider === null || this.context === null) return;
    const ctx: common.UIAbilityContext = this.context;
    const provider: ICloudProvider = this.cloudProvider;

    const tasks: DownloadTask[] = [];
    const folderPaths: string[] = [];
    const counter: TaskCounter = { total: 0 };

    await this.collectFolderTasks(folder, folder.name, tasks, folderPaths, counter);

    if (tasks.length === 0 && folderPaths.length === 0) {
      promptAction.showToast({ message: 'Folder is empty' });
      return;
    }

    const zipName: string = `${folder.name}.zip`;
    const destUri: string | null = await this.pickSaveLocation(zipName);
    if (destUri === null) return;

    const stagingDir: string = `${ctx.cacheDir}/staging_${Date.now()}`;
    LocalFileService.ensureDir(stagingDir);
    for (let i = 0; i < folderPaths.length; i++) {
      LocalFileService.ensureDir(`${stagingDir}/${folderPaths[i]}`);
    }

    const tracker: OperationTracker = OperationTracker.get();
    let success: number = 0;
    let failed: number = 0;

    for (let i = 0; i < tasks.length; i++) {
      const task: DownloadTask = tasks[i];
      const opId: string = tracker.register(
        OperationType.DOWNLOAD, task.relativePath, task.cloudId,
        OperationItemKind.FILE, i + 1, counter.total
      );
      tracker.markRunning(opId);

      try {
        const info: DownloadInfo = await provider.getDownloadInfo(task.cloudId);
        const bytes: ArrayBuffer = await this.fetchBytes(info, task.relativePath);

        const localPath: string = `${stagingDir}/${task.relativePath}`;
        const parentDir: string = localPath.substring(0, localPath.lastIndexOf('/'));
        LocalFileService.ensureDir(parentDir);

        const f = fs.openSync(
          localPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC
        );
        try { fs.writeSync(f.fd, bytes); } finally { fs.closeSync(f); }

        tracker.markSuccess(opId);
        success++;
      } catch (e) {
        const readable: string = formatError(e as Error);
        tracker.markFailed(opId, readable);
        failed++;
      }
    }

    if (success === 0) {
      promptAction.showToast({ message: 'Failed to download any files' });
      this.removeDirRecursive(stagingDir);
      return;
    }

    const zipPath: string = `${ctx.cacheDir}/${zipName}`;
    try {
      const options: zlib.Options = {
        level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION,
        memLevel: zlib.MemLevel.MEM_LEVEL_DEFAULT,
        strategy: zlib.CompressStrategy.COMPRESS_STRATEGY_DEFAULT_STRATEGY
      };
      await zlib.compressFile(stagingDir, zipPath, options);
      await this.copySandboxToDestination(zipPath, destUri, zipName);
      promptAction.showToast({ message: `Downloaded "${zipName}"` });
    } catch (e) {
      const readable: string = formatError(e as Error);
      promptAction.showToast({ message: `Failed: ${readable}` });
    } finally {
      this.removeDirRecursive(stagingDir);
      try { fs.accessSync(zipPath); fs.unlinkSync(zipPath); } catch (_) { /* ignore */ }
    }
  }

  private async downloadSelectionAsZip(
    files: CloudItem[],
    folders: CloudItem[]
  ): Promise<void> {
    if (this.cloudProvider === null || this.context === null) return;
    const ctx: common.UIAbilityContext = this.context;
    const provider: ICloudProvider = this.cloudProvider;

    const tasks: DownloadTask[] = [];
    const folderPaths: string[] = [];
    const counter: TaskCounter = { total: 0 };

    for (let i = 0; i < files.length; i++) {
      tasks.push({
        cloudId: files[i].id,
        relativePath: files[i].name,
        kind: OperationItemKind.FILE
      });
      counter.total++;
    }
    for (let i = 0; i < folders.length; i++) {
      await this.collectFolderTasks(
        folders[i], folders[i].name, tasks, folderPaths, counter
      );
    }

    if (tasks.length === 0) {
      promptAction.showToast({ message: 'Nothing to download' });
      return;
    }

    const zipName: string = `CLDrive_${Date.now()}.zip`;
    const destUri: string | null = await this.pickSaveLocation(zipName);
    if (destUri === null) return;

    const stagingDir: string = `${ctx.cacheDir}/staging_${Date.now()}`;
    LocalFileService.ensureDir(stagingDir);
    for (let i = 0; i < folderPaths.length; i++) {
      LocalFileService.ensureDir(`${stagingDir}/${folderPaths[i]}`);
    }

    const tracker: OperationTracker = OperationTracker.get();
    let success: number = 0;
    let failed: number = 0;

    for (let i = 0; i < tasks.length; i++) {
      const task: DownloadTask = tasks[i];
      const opId: string = tracker.register(
        OperationType.DOWNLOAD, task.relativePath, task.cloudId,
        OperationItemKind.FILE, i + 1, counter.total
      );
      tracker.markRunning(opId);

      try {
        const info: DownloadInfo = await provider.getDownloadInfo(task.cloudId);
        const bytes: ArrayBuffer = await this.fetchBytes(info, task.relativePath);

        const localPath: string = `${stagingDir}/${task.relativePath}`;
        const parentDir: string = localPath.substring(0, localPath.lastIndexOf('/'));
        LocalFileService.ensureDir(parentDir);

        const f = fs.openSync(
          localPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC
        );
        try { fs.writeSync(f.fd, bytes); } finally { fs.closeSync(f); }

        tracker.markSuccess(opId);
        success++;
      } catch (e) {
        const readable: string = formatError(e as Error);
        tracker.markFailed(opId, readable);
        failed++;
      }
    }

    if (success === 0) {
      promptAction.showToast({ message: 'Failed to download any files' });
      this.removeDirRecursive(stagingDir);
      return;
    }

    const zipPath: string = `${ctx.cacheDir}/${zipName}`;
    try {
      const options: zlib.Options = {
        level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION,
        memLevel: zlib.MemLevel.MEM_LEVEL_DEFAULT,
        strategy: zlib.CompressStrategy.COMPRESS_STRATEGY_DEFAULT_STRATEGY
      };
      await zlib.compressFile(stagingDir, zipPath, options);
      await this.copySandboxToDestination(zipPath, destUri, zipName);
      promptAction.showToast({ message: `Downloaded ${success} files as ZIP` });
    } catch (e) {
      const readable: string = formatError(e as Error);
      promptAction.showToast({ message: `Failed: ${readable}` });
    } finally {
      this.removeDirRecursive(stagingDir);
      try { fs.accessSync(zipPath); fs.unlinkSync(zipPath); } catch (_) { /* ignore */ }
    }
  }

  private async collectFolderTasks(
    folder: CloudItem,
    relativePath: string,
    tasks: DownloadTask[],
    folderPaths: string[],
    counter: TaskCounter
  ): Promise<void> {
    if (this.cloudProvider === null) return;

    folderPaths.push(relativePath);

    let children: CloudItem[] = [];
    try {
      children = await this.cloudProvider.listChildren(folder.id);
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `listChildren(${relativePath}) failed: ${readable}`);
      return;
    }

    for (let i = 0; i < children.length; i++) {
      const child: CloudItem = children[i];
      const childPath: string = `${relativePath}/${child.name}`;

      if (child.type === CloudItemType.FOLDER) {
        await this.collectFolderTasks(
          child, childPath, tasks, folderPaths, counter
        );
      } else {
        tasks.push({
          cloudId: child.id,
          relativePath: childPath,
          kind: OperationItemKind.FILE
        });
        counter.total++;
      }
    }
  }

  private async fetchBytes(
    info: DownloadInfo,
    label: string
  ): Promise<ArrayBuffer> {
    const request = http.createHttp();
    try {
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
  // Filesystem helpers
  // ===========================================================================

  private async copyPickerUriToSandbox(
    uri: string,
    fileName: string
  ): Promise<string> {
    if (this.context === null) throw new Error('Context not set');
    const ctx: common.UIAbilityContext = this.context;

    const safeName: string = fileName.replace(/[^a-zA-Z0-9._-]/g, '_');
    const uniqueId: string = `${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    const uploadsDir: string = `${ctx.filesDir}/uploads`;
    const sandboxPath: string = `${uploadsDir}/${uniqueId}_${safeName}`;

    Logger.info(TAG, `copyPickerUriToSandbox: src=${uri}`);
    Logger.info(TAG, `copyPickerUriToSandbox: dst=${sandboxPath}`);

    LocalFileService.ensureDir(uploadsDir);

    let srcFile: fs.File;
    try {
      srcFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      Logger.info(TAG, `Opened source picker URI: ${uri}`);
    } catch (e) {
      const readable: string = formatError(e as Error);
      Logger.error(TAG, `Failed to open picker URI "${uri}": ${readable}`);
      throw new Error(readable);
    }

    let destFile: fs.File | null = null;
    try {
      try {
        destFile = fs.openSync(
          sandboxPath,
          fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC
        );
        Logger.info(TAG, `Created sandbox destination: ${sandboxPath}`);
      } catch (e) {
        const readable: string = formatError(e as Error);
        Logger.error(TAG, `Failed to create "${sandboxPath}": ${readable}`);
        throw new Error(readable);
      }

      try {
        fs.copyFileSync(srcFile.fd, destFile.fd);
        Logger.info(TAG, `Copied picker URI to sandbox: ${sandboxPath}`);
      } catch (e) {
        const readable: string = formatError(e as Error);
        Logger.error(TAG, `copyFileSync failed: ${readable}`);
        throw new Error(readable);
      }
    } finally {
      try { fs.closeSync(srcFile); } catch (_) { /* ignore */ }
      if (destFile !== null) {
        try { fs.closeSync(destFile); } catch (_) { /* ignore */ }
      }
    }

    return sandboxPath;
  }

  private isSandboxPath(uri: string | undefined | null): boolean {
    if (uri === undefined || uri === null || uri.length === 0) return false;
    if (this.context === null) return false;

    let path: string = uri;
    if (path.startsWith('file://')) {
      try {
        path = new fileUri.FileUri(path).path;
      } catch (_) {
        path = path.substring('file://'.length);
      }
    }

    const filesDir: string = this.context.filesDir;
    const cacheDir: string = this.context.cacheDir;
    return path.startsWith(filesDir) || path.startsWith(cacheDir);
  }

  private removeDirRecursive(dirPath: string): void {
    try {
      fs.accessSync(dirPath);
    } catch (_) {
      return;
    }

    let names: string[] = [];
    try {
      names = fs.listFileSync(dirPath);
    } catch (_) {
      return;
    }

    for (let i = 0; i < names.length; i++) {
      const child: string = `${dirPath}/${names[i]}`;
      let isDir: boolean = false;
      try {
        isDir = fs.statSync(child).isDirectory();
      } catch (_) {
        continue;
      }
      if (isDir) {
        this.removeDirRecursive(child);
      } else {
        try { fs.unlinkSync(child); } catch (_) { /* ignore */ }
      }
    }

    try { fs.rmdirSync(dirPath); } catch (_) { /* ignore */ }
  }

  // ===========================================================================
  // Details page
  // ===========================================================================

  onShowDetails(): void {
    if (this.selectedItem === null) return;
    const itemId: string = this.selectedItem.id;
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

  static fileNameFromUri(uri: string | undefined | null): string {
    if (uri === undefined || uri === null || uri.length === 0) return '';
    let path: string = uri;
    if (path.startsWith('file://')) {
      path = path.substring('file://'.length);
    }
    while (path.length > 0 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    const slash: number = path.lastIndexOf('/');
    let name: string = slash >= 0 ? path.substring(slash + 1) : path;

    try {
      name = decodeURIComponent(name);
    } catch (_) { /* keep as-is */ }
    return name;
  }

  static basename(pathOrUri: string | undefined | null): string {
    if (pathOrUri === undefined || pathOrUri === null || pathOrUri.length === 0) {
      return 'unnamed';
    }
    let p: string = pathOrUri;
    while (p.length > 0 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    const slash: number = p.lastIndexOf('/');
    return slash >= 0 ? p.substring(slash + 1) : p;
  }

  static appendToUri(dirUri: string, fileName: string): string {
    if (dirUri.endsWith('/')) return `${dirUri}${fileName}`;
    return `${dirUri}/${fileName}`;
  }

  static findAvailableName(
    originalName: string | undefined | null,
    takenLowercase: string[]
  ): string {
    const safeName: string = (originalName !== undefined
      && originalName !== null
      && originalName.length > 0)
      ? originalName
      : `untitled_${Date.now()}`;

    if (takenLowercase.indexOf(safeName.toLowerCase()) < 0) {
      return safeName;
    }

    const parts: NameParts = FileBrowserViewModel.splitName(safeName);
    for (let i = 1; i < 10000; i++) {
      const candidate: string = `${parts.base} (${i})${parts.ext}`;
      if (takenLowercase.indexOf(candidate.toLowerCase()) < 0) {
        return candidate;
      }
    }
    return `${parts.base} (${Date.now()})${parts.ext}`;
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
      const name: string = names[i];
      const full: string = `${currentPath}/${name}`;
      const childRel: string = relative.length > 0 ? `${relative}/${name}` : name;

      let isDir: boolean = false;
      try {
        isDir = fs.statSync(full).isDirectory();
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

  static splitName(fileName: string | undefined | null): NameParts {
    if (fileName === undefined || fileName === null || fileName.length === 0) {
      return { base: '', ext: '' };
    }
    const dot: number = fileName.lastIndexOf('.');
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
    const months: string[] = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return `${months[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
  }

  static initialOf(account: AccountInfo): string {
    const name: string = account.displayName;
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
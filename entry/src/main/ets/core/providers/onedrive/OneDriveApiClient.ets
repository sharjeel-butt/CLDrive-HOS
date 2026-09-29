import { RequestBuilder } from '../../network/RequestBuilder';
import { HttpClient, HttpResponse, HttpRequestOptions } from '../../network/HttpClient';
import { OneDriveConfig } from '../../../config/OneDriveConfig';
import {
  GraphDriveItem,
  GraphUser,
  getGraphDownloadUrl
} from './OneDriveMapper';
import { http } from '@kit.NetworkKit';
import { Logger } from '../../../utils/Logger';

// ---------------------------------------------------------------------------
// Response envelopes
// ---------------------------------------------------------------------------
interface GraphListResponse {
  value: GraphDriveItem[];
}

// ---------------------------------------------------------------------------
// Request body shapes
// ---------------------------------------------------------------------------
interface ParentReference {
  id: string;
}

interface CreateFolderBody {
  name: string;
  folder: Record<string, string>;
  '@microsoft.graph.conflictBehavior': string;
}

interface RenameBody {
  name: string;
}

interface MoveBody {
  parentReference: ParentReference;
  name?: string;
}

interface CopyBody {
  parentReference: ParentReference;
  name?: string;
  '@microsoft.graph.conflictBehavior'?: string;
}

interface UploadSessionItem {
  '@microsoft.graph.conflictBehavior': string;
  name: string;
}

interface CreateUploadSessionBody {
  item: UploadSessionItem;
}

// ---------------------------------------------------------------------------
// EXPORTED response type — consumed by OneDriveProvider
// ---------------------------------------------------------------------------
export interface UploadSessionResponse {
  uploadUrl: string;
  expirationDateTime: string;
}

export class OneDriveApiClient {
  private readonly base: string;
  private static readonly TAG: string = 'OneDriveApiClient';

  constructor() {
    this.base = OneDriveConfig.GRAPH_BASE;
  }

  // ===========================================================================
  // Identity
  // ===========================================================================

  async getMe(accessToken: string): Promise<GraphUser> {
    return RequestBuilder.get(`${this.base}/me`)
      .bearer(accessToken)
      .executeJson<GraphUser>();
  }

  // ===========================================================================
  // Listing
  // ===========================================================================

  async listRootChildren(accessToken: string): Promise<GraphDriveItem[]> {
    const res = await RequestBuilder
      .get(`${this.base}/me/drive/root/children`)
      .bearer(accessToken)
      .executeJson<GraphListResponse>();
    return res.value ?? [];
  }

  async listChildren(
    accessToken: string,
    itemId: string
  ): Promise<GraphDriveItem[]> {
    const res = await RequestBuilder
      .get(`${this.base}/me/drive/items/${encodeURIComponent(itemId)}/children`)
      .bearer(accessToken)
      .executeJson<GraphListResponse>();
    return res.value ?? [];
  }

  async getItem(accessToken: string, itemId: string): Promise<GraphDriveItem> {
    return RequestBuilder
      .get(`${this.base}/me/drive/items/${encodeURIComponent(itemId)}`)
      .bearer(accessToken)
      .executeJson<GraphDriveItem>();
  }

  async search(accessToken: string, query: string): Promise<GraphDriveItem[]> {
    const url = `${this.base}/me/drive/root/search(q='${encodeURIComponent(query)}')`;
    const res = await RequestBuilder.get(url)
      .bearer(accessToken)
      .executeJson<GraphListResponse>();
    return res.value ?? [];
  }

  // ===========================================================================
  // Mutations
  // ===========================================================================

  async createFolder(
    accessToken: string,
    parentId: string,
    name: string
  ): Promise<GraphDriveItem> {
    const url = parentId === 'root'
      ? `${this.base}/me/drive/root/children`
      : `${this.base}/me/drive/items/${encodeURIComponent(parentId)}/children`;

    const emptyFolder: Record<string, string> = {};
    const body: CreateFolderBody = {
      name: name,
      folder: emptyFolder,
      '@microsoft.graph.conflictBehavior': 'rename'
    };

    return RequestBuilder.post(url)
      .bearer(accessToken)
      .jsonBody(body)
      .executeJson<GraphDriveItem>();
  }

  async renameItem(
    accessToken: string,
    itemId: string,
    newName: string
  ): Promise<GraphDriveItem> {
    const body: RenameBody = { name: newName };

    return RequestBuilder
      .patch(`${this.base}/me/drive/items/${encodeURIComponent(itemId)}`)
      .bearer(accessToken)
      .jsonBody(body)
      .executeJson<GraphDriveItem>();
  }

  async moveItem(
    accessToken: string,
    itemId: string,
    newParentId: string,
    newName?: string
  ): Promise<GraphDriveItem> {
    const parentRef: ParentReference = { id: newParentId };

    let body: MoveBody;
    if (newName !== undefined && newName.length > 0) {
      body = { parentReference: parentRef, name: newName };
    } else {
      body = { parentReference: parentRef };
    }

    return RequestBuilder
      .patch(`${this.base}/me/drive/items/${encodeURIComponent(itemId)}`)
      .bearer(accessToken)
      .jsonBody(body)
      .executeJson<GraphDriveItem>();
  }

  async copyItem(
    accessToken: string,
    itemId: string,
    newParentId: string,
    newName?: string
  ): Promise<string | null> {
    const parentRef: ParentReference = { id: newParentId };

    let body: CopyBody;
    if (newName !== undefined && newName.length > 0) {
      body = {
        parentReference: parentRef,
        name: newName,
        '@microsoft.graph.conflictBehavior': 'rename'
      };
    } else {
      body = {
        parentReference: parentRef,
        '@microsoft.graph.conflictBehavior': 'fail'
      };
    }

    const url = `${this.base}/me/drive/items/${encodeURIComponent(itemId)}/copy`;

    const opts = new HttpRequestOptions();
    opts.method = http.RequestMethod.POST;
    opts.headers.set('Authorization', `Bearer ${accessToken}`);
    opts.jsonBody = body;

    const response: HttpResponse = await HttpClient.requestWithHeaders(url, opts);

    if (response.statusCode === 202) {
      const location: string | undefined = response.headers['location'];
      if (location !== undefined && location.length > 0) {
        Logger.info(
          OneDriveApiClient.TAG,
          `Async copy monitor URL: ${location}`
        );
        return location;
      }
      Logger.warn(
        OneDriveApiClient.TAG,
        'Graph returned 202 but no Location header — treating as inline.'
      );
      return null;
    }

    return null;
  }

  async deleteItem(accessToken: string, itemId: string): Promise<void> {
    await RequestBuilder
      .delete(`${this.base}/me/drive/items/${encodeURIComponent(itemId)}`)
      .bearer(accessToken)
      .execute();
  }

  /**
   * Simple upload for files < 4 MB.
   *
   * Microsoft Graph's `:/path:/` addressing scheme breaks on certain
   * characters in filenames — notably `[ ] ( ) # %`. When the name
   * contains any of them, we upload under a UUID-based temporary name
   * and immediately PATCH the item to rename it to the original.
   */
  async uploadSmall(
    accessToken: string,
    parentId: string,
    fileName: string,
    content: ArrayBuffer
  ): Promise<GraphDriveItem> {
    // Detect problematic characters.
    const needsRename: boolean = OneDriveApiClient.hasProblematicChars(fileName);
    const uploadName: string = needsRename
      ? `tmp_${Date.now()}_${OneDriveApiClient.safeExtension(fileName)}`
      : fileName;

    const url = `${this.base}/me/drive/items/${encodeURIComponent(parentId)}`
      + `:/${encodeURIComponent(uploadName)}:/content`;

    Logger.info(
      OneDriveApiClient.TAG,
      `uploadSmall: url=${url} (finalName="${fileName}" uploadName="${uploadName}")`
    );

    const response = await RequestBuilder.put(url)
      .bearer(accessToken)
      .contentType('application/octet-stream')
      .rawBody(content)
      .executeJson<GraphDriveItem>();

    // If we used a temporary name, rename to the original now.
    if (needsRename) {
      Logger.info(
        OneDriveApiClient.TAG,
        `uploadSmall: renaming "${uploadName}" → "${fileName}"`
      );
      try {
        const renamed = await this.renameItem(accessToken, response.id, fileName);
        return renamed;
      } catch (e) {
        const err: Error = e as Error;
        Logger.error(
          OneDriveApiClient.TAG,
          `rename after upload failed: ${err.message}`
        );
        // Return the item with the temp name — the caller at least has
        // a working file. The user can rename manually.
        return response;
      }
    }

    return response;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /**
   * Return true when the filename contains characters that break
   * Graph's :/path:/ addressing scheme.
   */
  private static hasProblematicChars(name: string): boolean {
    return /[\[\]()#%]/.test(name);
  }

  /**
   * Return just the extension (including the dot) for a filename, so
   * the temporary upload can preserve the file type.
   */
  private static safeExtension(name: string): string {
    const dot: number = name.lastIndexOf('.');
    if (dot <= 0 || dot === name.length - 1) return '';
    return name.substring(dot);
  }

  async createUploadSession(
    accessToken: string,
    parentId: string,
    fileName: string
  ): Promise<UploadSessionResponse> {
    const url = `${this.base}/me/drive/items/${encodeURIComponent(parentId)}:/${encodeURIComponent(fileName)}:/createUploadSession`;

    const item: UploadSessionItem = {
      '@microsoft.graph.conflictBehavior': 'rename',
      name: fileName
    };
    const body: CreateUploadSessionBody = { item: item };

    return RequestBuilder.post(url)
      .bearer(accessToken)
      .jsonBody(body)
      .executeJson<UploadSessionResponse>();
  }

  async uploadChunk(
    uploadUrl: string,
    content: ArrayBuffer,
    rangeStart: number,
    rangeEnd: number,
    totalSize: number
  ): Promise<GraphDriveItem | null> {
    const raw = await RequestBuilder.put(uploadUrl)
      .contentType('application/octet-stream')
      .header('Content-Range', `bytes ${rangeStart}-${rangeEnd}/${totalSize}`)
      .rawBody(content)
      .execute();

    if (raw && raw.length > 0 && raw.trim().startsWith('{')) {
      return JSON.parse(raw) as GraphDriveItem;
    }
    return null;
  }

  // ===========================================================================
  // Download
  // ===========================================================================

  async getDownloadUrl(accessToken: string, itemId: string): Promise<string> {
    const item: GraphDriveItem = await this.getItem(accessToken, itemId);
    const url: string | undefined = getGraphDownloadUrl(item);

    if (url === undefined || url.length === 0) {
      throw new Error(`No downloadUrl for item ${itemId}`);
    }
    return url;
  }

  async downloadContent(
    accessToken: string,
    itemId: string
  ): Promise<ArrayBuffer> {
    const url = `${this.base}/me/drive/items/${encodeURIComponent(itemId)}/content`;
    const request = http.createHttp();

    try {
      const headerObj: Record<string, string> = {};
      Reflect.set(headerObj, 'Authorization', `Bearer ${accessToken}`);

      const requestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: headerObj,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: OneDriveConfig.TRANSFER_TIMEOUT_MS,
        connectTimeout: OneDriveConfig.REQUEST_TIMEOUT_MS
      };

      const response = await request.request(url, requestOptions);
      return response.result as ArrayBuffer;
    } finally {
      request.destroy();
    }
  }
}
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

interface UploadSessionResponse {
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

  /**
   * Copy an item.
   *
   * Microsoft Graph's copy endpoint is asynchronous:
   *   - Small files and empty folders: 200/201 with the new DriveItem → null.
   *   - Folders with contents and very large files: 202 Accepted with a
   *     `Location` header pointing at a monitor URL → that URL is returned.
   *
   * Conflict behavior:
   *   - newName provided → rename on collision (caller pre-resolved).
   *   - newName omitted  → fail on collision so the caller can prompt.
   */
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

    // Build a typed HttpRequestOptions instance (no anonymous literal).
    const opts = new HttpRequestOptions();
    opts.method = http.RequestMethod.POST;
    opts.headers.set('Authorization', `Bearer ${accessToken}`);
    opts.jsonBody = body;

    const response: HttpResponse = await HttpClient.requestWithHeaders(url, opts);

    // 202 Accepted → async copy; return the monitor URL from Location.
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

    // 200 / 201 → synchronous completion.
    return null;
  }

  async deleteItem(accessToken: string, itemId: string): Promise<void> {
    await RequestBuilder
      .delete(`${this.base}/me/drive/items/${encodeURIComponent(itemId)}`)
      .bearer(accessToken)
      .execute();
  }

  // ===========================================================================
  // Upload
  // ===========================================================================

  async uploadSmall(
    accessToken: string,
    parentId: string,
    fileName: string,
    content: ArrayBuffer
  ): Promise<GraphDriveItem> {
    const url = `${this.base}/me/drive/items/${encodeURIComponent(parentId)}:/${encodeURIComponent(fileName)}:/content`;

    return RequestBuilder.put(url)
      .bearer(accessToken)
      .contentType('application/octet-stream')
      .rawBody(content)
      .executeJson<GraphDriveItem>();
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
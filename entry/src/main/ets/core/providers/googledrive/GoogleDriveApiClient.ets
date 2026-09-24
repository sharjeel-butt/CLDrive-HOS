import { RequestBuilder } from '../../network/RequestBuilder';
import { HttpClient, HttpResponse, HttpRequestOptions } from '../../network/HttpClient';
import { GoogleDriveConfig } from '../../../config/GoogleDriveConfig';
import {
  GoogleAbout,
  GoogleFile,
  GoogleFileListResponse,
  MIME_FOLDER
} from './GoogleDriveMapper';
import { http } from '@kit.NetworkKit';
import { Logger } from '../../../utils/Logger';

// ---------------------------------------------------------------------------
// Request body shapes — one interface per endpoint
// ---------------------------------------------------------------------------

interface CreateFolderBody {
  name: string;
  mimeType: string;
  parents: string[];
}

interface RenameBody {
  name: string;
}

interface MoveBody {
  name?: string;
}

interface CopyBody {
  parents: string[];
  name?: string;
}

interface UploadInitBody {
  name: string;
  parents: string[];
}

interface EmptyBody {
  // Intentionally empty — used for PATCH requests that only carry
  // query-string parameters and need a valid (empty) JSON body.
}

export class GoogleDriveApiClient {
  private readonly base: string;
  private readonly uploadBase: string;
  private static readonly TAG: string = 'GoogleDriveApiClient';

  constructor() {
    this.base = GoogleDriveConfig.DRIVE_API;
    this.uploadBase = GoogleDriveConfig.UPLOAD_API;
  }

  // ===========================================================================
  // User info
  // ===========================================================================

  async getAbout(accessToken: string): Promise<GoogleAbout> {
    const url = `${this.base}/about?fields=user(displayName,emailAddress,photoLink)`;
    return RequestBuilder.get(url)
      .bearer(accessToken)
      .executeJson<GoogleAbout>();
  }

  // ===========================================================================
  // Listing
  // ===========================================================================

  private static readonly FILE_FIELDS: string =
    'id,name,mimeType,size,createdTime,modifiedTime,parents,' +
      'fileExtension,fullFileExtension,' +
      'webViewLink,webContentLink,thumbnailLink,iconLink,' +
      'trashed,capabilities(canDownload,canEdit,canRename,canDelete,canCopy)';

  async listChildren(
    accessToken: string,
    parentId: string
  ): Promise<GoogleFile[]> {
    const parent: string = parentId.length > 0 ? parentId : 'root';
    const q = `'${parent}' in parents and trashed = false`;
    const url = `${this.base}/files?q=${encodeURIComponent(q)}` +
      `&fields=files(${GoogleDriveApiClient.FILE_FIELDS}),nextPageToken` +
      `&pageSize=1000&orderBy=folder,name`;

    const res = await RequestBuilder.get(url)
      .bearer(accessToken)
      .executeJson<GoogleFileListResponse>();
    return res.files ?? [];
  }

  async getFile(accessToken: string, fileId: string): Promise<GoogleFile> {
    const url = `${this.base}/files/${encodeURIComponent(fileId)}` +
      `?fields=${GoogleDriveApiClient.FILE_FIELDS}`;
    return RequestBuilder.get(url)
      .bearer(accessToken)
      .executeJson<GoogleFile>();
  }

  async search(accessToken: string, query: string): Promise<GoogleFile[]> {
    const escaped = query.replace(/'/g, "\\'");
    const q = `name contains '${escaped}' and trashed = false`;
    const url = `${this.base}/files?q=${encodeURIComponent(q)}` +
      `&fields=files(${GoogleDriveApiClient.FILE_FIELDS})&pageSize=100`;

    const res = await RequestBuilder.get(url)
      .bearer(accessToken)
      .executeJson<GoogleFileListResponse>();
    return res.files ?? [];
  }

  // ===========================================================================
  // Mutations
  // ===========================================================================

  async createFolder(
    accessToken: string,
    parentId: string,
    name: string
  ): Promise<GoogleFile> {
    const parent: string = parentId.length > 0 ? parentId : 'root';

    const body: CreateFolderBody = {
      name: name,
      mimeType: MIME_FOLDER,
      parents: [parent]
    };

    const url = `${this.base}/files?fields=${GoogleDriveApiClient.FILE_FIELDS}`;
    return RequestBuilder.post(url)
      .bearer(accessToken)
      .jsonBody(body)
      .executeJson<GoogleFile>();
  }

  async renameFile(
    accessToken: string,
    fileId: string,
    newName: string
  ): Promise<GoogleFile> {
    const body: RenameBody = { name: newName };
    const url = `${this.base}/files/${encodeURIComponent(fileId)}` +
      `?fields=${GoogleDriveApiClient.FILE_FIELDS}`;
    return RequestBuilder.patch(url)
      .bearer(accessToken)
      .jsonBody(body)
      .executeJson<GoogleFile>();
  }

  async moveFile(
    accessToken: string,
    fileId: string,
    oldParentId: string,
    newParentId: string,
    newName?: string
  ): Promise<GoogleFile> {
    const params = new Map<string, string>();
    params.set('addParents', newParentId);
    if (oldParentId.length > 0) {
      params.set('removeParents', oldParentId);
    }
    params.set('fields', GoogleDriveApiClient.FILE_FIELDS);

    const query: string = GoogleDriveApiClient.encodeForm(params);
    const url = `${this.base}/files/${encodeURIComponent(fileId)}?${query}`;

    if (newName !== undefined && newName.length > 0) {
      const body: MoveBody = { name: newName };
      return RequestBuilder.patch(url)
        .bearer(accessToken)
        .jsonBody(body)
        .executeJson<GoogleFile>();
    }

    // No rename — send an empty body so the PATCH remains well-formed.
    const empty: EmptyBody = {};
    return RequestBuilder.patch(url)
      .bearer(accessToken)
      .jsonBody(empty)
      .executeJson<GoogleFile>();
  }

  /**
   * Copy a file or folder.
   * Files copy synchronously; folders return a placeholder file whose ID
   * stabilizes once the server-side copy finishes.
   */
  async copyFile(
    accessToken: string,
    fileId: string,
    newParentId: string,
    newName?: string
  ): Promise<GoogleFile> {
    let body: CopyBody;
    if (newName !== undefined && newName.length > 0) {
      body = { parents: [newParentId], name: newName };
    } else {
      body = { parents: [newParentId] };
    }

    const url = `${this.base}/files/${encodeURIComponent(fileId)}/copy` +
      `?fields=${GoogleDriveApiClient.FILE_FIELDS}`;
    return RequestBuilder.post(url)
      .bearer(accessToken)
      .jsonBody(body)
      .executeJson<GoogleFile>();
  }

  async deleteFile(accessToken: string, fileId: string): Promise<void> {
    const url = `${this.base}/files/${encodeURIComponent(fileId)}`;
    await RequestBuilder.delete(url)
      .bearer(accessToken)
      .execute();
  }

  // ===========================================================================
  // Upload — resumable session
  // ===========================================================================

  async initiateResumableUpload(
    accessToken: string,
    parentId: string,
    fileName: string,
    mimeType: string,
    totalSize: number
  ): Promise<string> {
    const parent: string = parentId.length > 0 ? parentId : 'root';
    const url = `${this.uploadBase}/files?uploadType=resumable`;

    const body: UploadInitBody = {
      name: fileName,
      parents: [parent]
    };

    const opts = new HttpRequestOptions();
    opts.method = http.RequestMethod.POST;
    opts.headers.set('Authorization', `Bearer ${accessToken}`);
    opts.headers.set('Content-Type', 'application/json; charset=UTF-8');
    opts.headers.set('X-Upload-Content-Type', mimeType);
    opts.headers.set('X-Upload-Content-Length', `${totalSize}`);
    opts.jsonBody = body;

    const response: HttpResponse = await HttpClient.requestWithHeaders(url, opts);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(
        `Failed to initiate upload (HTTP ${response.statusCode}): ${response.body}`
      );
    }

    const location: string | undefined = response.headers['location'];
    if (location === undefined || location.length === 0) {
      throw new Error('No Location header from upload session initiation.');
    }
    Logger.info(GoogleDriveApiClient.TAG, `Upload session: ${location}`);
    return location;
  }

  async uploadChunk(
    sessionUrl: string,
    data: ArrayBuffer,
    start: number,
    end: number,
    totalSize: number
  ): Promise<GoogleFile | null> {
    const chunkLength: number = end - start + 1;
    const isLast: boolean = end + 1 === totalSize;
    const rangeHeader: string = isLast
      ? `bytes ${start}-${end}/${totalSize}`
      : `bytes ${start}-${end}/*`;

    const opts = new HttpRequestOptions();
    opts.method = http.RequestMethod.PUT;
    opts.headers.set('Content-Length', `${chunkLength}`);
    opts.headers.set('Content-Range', rangeHeader);
    opts.body = data;

    const response: HttpResponse =
      await HttpClient.requestWithHeaders(sessionUrl, opts);

    if (response.statusCode === 200 || response.statusCode === 201) {
      return JSON.parse(response.body) as GoogleFile;
    }

    if (response.statusCode === 308) {
      return null;
    }

    throw new Error(
      `Upload chunk failed (HTTP ${response.statusCode}): ${response.body}`
    );
  }

  // ===========================================================================
  // Download
  // ===========================================================================

  async getDownloadUrl(accessToken: string, fileId: string): Promise<string> {
    return `${this.base}/files/${encodeURIComponent(fileId)}` +
      `?alt=media&access_token=${encodeURIComponent(accessToken)}`;
  }

  async downloadContent(
    accessToken: string,
    fileId: string
  ): Promise<ArrayBuffer> {
    const url = `${this.base}/files/${encodeURIComponent(fileId)}?alt=media`;
    const request = http.createHttp();
    try {
      const headerObj: Record<string, string> = {};
      Reflect.set(headerObj, 'Authorization', `Bearer ${accessToken}`);

      const requestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: headerObj,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: GoogleDriveConfig.TRANSFER_TIMEOUT_MS,
        connectTimeout: GoogleDriveConfig.REQUEST_TIMEOUT_MS
      };

      const response = await request.request(url, requestOptions);
      return response.result as ArrayBuffer;
    } finally {
      request.destroy();
    }
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  private static encodeForm(params: Map<string, string>): string {
    const parts: string[] = [];
    params.forEach((value: string, key: string): void => {
      parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
    });
    return parts.join('&');
  }
}
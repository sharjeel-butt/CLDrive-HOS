import { RequestBuilder } from '../../network/RequestBuilder';
import { HttpClient, HttpResponse, HttpRequestOptions } from '../../network/HttpClient';
import { DropboxConfig } from '../../../config/DropboxConfig';
import { DownloadInfo } from '../../models/DownloadInfo';
import {
  DropboxMetadata,
  DropboxListFolderResponse,
  DropboxListFolderContinueResponse,
  DropboxSearchResponse,
  DropboxSearchMatch,
  DropboxCurrentAccount
} from './DropboxMapper';
import { http } from '@kit.NetworkKit';
import { Logger } from '../../../utils/Logger';

// ---------------------------------------------------------------------------
// Request body shapes
// ---------------------------------------------------------------------------

interface ListFolderBody {
  path: string;
  recursive: boolean;
  include_deleted: boolean;
  include_mounted_folders: boolean;
  limit: number;
}

interface ListFolderContinueBody {
  cursor: string;
}

interface GetMetadataBody {
  path: string;
  include_deleted: boolean;
}

interface CreateFolderBody {
  path: string;
  autorename: boolean;
}

interface MoveBody {
  from_path: string;
  to_path: string;
  autorename: boolean;
}

interface CopyBody {
  from_path: string;
  to_path: string;
  autorename: boolean;
}

interface DeleteBody {
  path: string;
}

interface SearchOptions {
  path: string;
  max_results: number;
  filename_only: boolean;
}

interface SearchBody {
  query: string;
  options: SearchOptions;
}

interface EmptyBody {
  // Intentionally empty — Dropbox metadata endpoints accept "{}".
}

interface UploadSessionStartBody {
  close: boolean;
}

interface UploadSessionCursor {
  session_id: string;
  offset: number;
}

interface UploadSessionAppendBody {
  cursor: UploadSessionCursor;
  close: boolean;
}

interface UploadCommit {
  path: string;
  mode: string;
  autorename: boolean;
  mute: boolean;
  strict_conflict: boolean;
}

interface UploadSessionFinishBody {
  cursor: UploadSessionCursor;
  commit: UploadCommit;
}

interface UploadSessionResponse {
  session_id: string;
}

interface DownloadArg {
  path: string;
}

interface UploadArg {
  path: string;
  mode: string;
  autorename: boolean;
  mute: boolean;
  strict_conflict: boolean;
}

// ---------------------------------------------------------------------------
// Response wrappers for create/move/copy endpoints
// ---------------------------------------------------------------------------

interface CreateFolderResponse {
  metadata: DropboxMetadata;
}

interface MoveResponse {
  metadata: DropboxMetadata;
}

interface CopyResponse {
  metadata: DropboxMetadata;
}

// ---------------------------------------------------------------------------
// API client
// ---------------------------------------------------------------------------

export class DropboxApiClient {
  private readonly base: string;
  private readonly contentBase: string;
  private static readonly TAG: string = 'DropboxApiClient';

  constructor() {
    this.base = DropboxConfig.API_BASE;
    this.contentBase = DropboxConfig.CONTENT_BASE;
  }

  // ===========================================================================
  // Identity
  // ===========================================================================

  async getCurrentAccount(accessToken: string): Promise<DropboxCurrentAccount> {
    const emptyBody: EmptyBody = {};
    return RequestBuilder.post(`${this.base}/users/get_current_account`)
      .bearer(accessToken)
      .jsonBody(emptyBody)
      .executeJson<DropboxCurrentAccount>();
  }

  // ===========================================================================
  // Listing
  // ===========================================================================

  async listFolder(
    accessToken: string,
    path: string
  ): Promise<DropboxMetadata[]> {
    const body: ListFolderBody = {
      path: path,
      recursive: false,
      include_deleted: false,
      include_mounted_folders: true,
      limit: 2000
    };

    const first = await RequestBuilder
      .post(`${this.base}/files/list_folder`)
      .bearer(accessToken)
      .jsonBody(body)
      .executeJson<DropboxListFolderResponse>();

    const out: DropboxMetadata[] = first.entries !== undefined
      ? first.entries.slice()
      : [];

    let cursor: string = first.cursor;
    let hasMore: boolean = first.has_more;

    while (hasMore) {
      const contBody: ListFolderContinueBody = { cursor: cursor };
      const next = await RequestBuilder
        .post(`${this.base}/files/list_folder/continue`)
        .bearer(accessToken)
        .jsonBody(contBody)
        .executeJson<DropboxListFolderContinueResponse>();

      if (next.entries !== undefined && next.entries.length > 0) {
        for (let i = 0; i < next.entries.length; i++) {
          out.push(next.entries[i]);
        }
      }
      cursor = next.cursor;
      hasMore = next.has_more;
    }

    return out;
  }

  async getMetadata(
    accessToken: string,
    path: string
  ): Promise<DropboxMetadata> {
    const body: GetMetadataBody = {
      path: path,
      include_deleted: false
    };
    return RequestBuilder.post(`${this.base}/files/get_metadata`)
      .bearer(accessToken)
      .jsonBody(body)
      .executeJson<DropboxMetadata>();
  }

  async search(
    accessToken: string,
    query: string
  ): Promise<DropboxMetadata[]> {
    const options: SearchOptions = {
      path: '',
      max_results: 200,
      filename_only: true
    };
    const body: SearchBody = {
      query: query,
      options: options
    };

    const res = await RequestBuilder
      .post(`${this.base}/files/search_v2`)
      .bearer(accessToken)
      .jsonBody(body)
      .executeJson<DropboxSearchResponse>();

    const out: DropboxMetadata[] = [];
    if (res.matches !== undefined) {
      for (let i = 0; i < res.matches.length; i++) {
        const match: DropboxSearchMatch = res.matches[i];
        if (match.metadata !== undefined
          && match.metadata.metadata !== undefined) {
          out.push(match.metadata.metadata);
        }
      }
    }
    return out;
  }

  // ===========================================================================
  // Mutations
  // ===========================================================================

  async createFolder(
    accessToken: string,
    parentPath: string,
    name: string
  ): Promise<DropboxMetadata> {
    const fullPath: string = DropboxApiClient.joinPath(parentPath, name);
    const body: CreateFolderBody = {
      path: fullPath,
      autorename: false
    };
    const res = await RequestBuilder
      .post(`${this.base}/files/create_folder_v2`)
      .bearer(accessToken)
      .jsonBody(body)
      .executeJson<CreateFolderResponse>();
    return res.metadata;
  }

  async moveItem(
    accessToken: string,
    fromPath: string,
    toPath: string
  ): Promise<DropboxMetadata> {
    const body: MoveBody = {
      from_path: fromPath,
      to_path: toPath,
      autorename: false
    };
    const res = await RequestBuilder
      .post(`${this.base}/files/move_v2`)
      .bearer(accessToken)
      .jsonBody(body)
      .executeJson<MoveResponse>();
    return res.metadata;
  }

  async copyItem(
    accessToken: string,
    fromPath: string,
    toPath: string
  ): Promise<DropboxMetadata> {
    const body: CopyBody = {
      from_path: fromPath,
      to_path: toPath,
      autorename: false
    };
    const res = await RequestBuilder
      .post(`${this.base}/files/copy_v2`)
      .bearer(accessToken)
      .jsonBody(body)
      .executeJson<CopyResponse>();
    return res.metadata;
  }

  async deleteItem(accessToken: string, path: string): Promise<void> {
    const body: DeleteBody = { path: path };
    await RequestBuilder
      .post(`${this.base}/files/delete_v2`)
      .bearer(accessToken)
      .jsonBody(body)
      .execute();
  }

  // ===========================================================================
  // Upload — small files (<= 150 MB)
  // ===========================================================================

  async uploadSmall(
    accessToken: string,
    path: string,
    content: ArrayBuffer
  ): Promise<DropboxMetadata> {
    const arg: UploadArg = {
      path: path,
      mode: 'add',
      autorename: true,
      mute: false,
      strict_conflict: false
    };

    const opts = new HttpRequestOptions();
    opts.method = http.RequestMethod.POST;
    opts.headers.set('Authorization', `Bearer ${accessToken}`);
    opts.headers.set('Content-Type', 'application/octet-stream');
    opts.headers.set('Dropbox-API-Arg', JSON.stringify(arg));
    opts.body = content;

    const response: HttpResponse = await HttpClient.requestWithHeaders(
      `${this.contentBase}/files/upload`, opts
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(
        `Upload failed (HTTP ${response.statusCode}): ${response.body}`
      );
    }

    return JSON.parse(response.body) as DropboxMetadata;
  }

  // ===========================================================================
  // Upload — resumable session (files > 150 MB)
  // ===========================================================================

  async uploadSessionStart(
    accessToken: string,
    firstChunk: ArrayBuffer
  ): Promise<string> {
    const body: UploadSessionStartBody = { close: false };

    const opts = new HttpRequestOptions();
    opts.method = http.RequestMethod.POST;
    opts.headers.set('Authorization', `Bearer ${accessToken}`);
    opts.headers.set('Content-Type', 'application/octet-stream');
    opts.headers.set('Dropbox-API-Arg', JSON.stringify(body));
    opts.body = firstChunk;

    const response: HttpResponse = await HttpClient.requestWithHeaders(
      `${this.contentBase}/files/upload_session/start`, opts
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(
        `Session start failed (HTTP ${response.statusCode}): ${response.body}`
      );
    }

    const parsed = JSON.parse(response.body) as UploadSessionResponse;
    return parsed.session_id;
  }

  async uploadSessionAppend(
    accessToken: string,
    sessionId: string,
    offset: number,
    chunk: ArrayBuffer
  ): Promise<void> {
    const cursor: UploadSessionCursor = {
      session_id: sessionId,
      offset: offset
    };
    const body: UploadSessionAppendBody = {
      cursor: cursor,
      close: false
    };

    const opts = new HttpRequestOptions();
    opts.method = http.RequestMethod.POST;
    opts.headers.set('Authorization', `Bearer ${accessToken}`);
    opts.headers.set('Content-Type', 'application/octet-stream');
    opts.headers.set('Dropbox-API-Arg', JSON.stringify(body));
    opts.body = chunk;

    const response: HttpResponse = await HttpClient.requestWithHeaders(
      `${this.contentBase}/files/upload_session/append_v2`, opts
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(
        `Session append failed (HTTP ${response.statusCode}): ${response.body}`
      );
    }
  }

  async uploadSessionFinish(
    accessToken: string,
    sessionId: string,
    offset: number,
    path: string
  ): Promise<DropboxMetadata> {
    const cursor: UploadSessionCursor = {
      session_id: sessionId,
      offset: offset
    };
    const commit: UploadCommit = {
      path: path,
      mode: 'add',
      autorename: true,
      mute: false,
      strict_conflict: false
    };
    const body: UploadSessionFinishBody = {
      cursor: cursor,
      commit: commit
    };

    const opts = new HttpRequestOptions();
    opts.method = http.RequestMethod.POST;
    opts.headers.set('Authorization', `Bearer ${accessToken}`);
    opts.headers.set('Content-Type', 'application/octet-stream');
    opts.headers.set('Dropbox-API-Arg', JSON.stringify(body));

    const response: HttpResponse = await HttpClient.requestWithHeaders(
      `${this.contentBase}/files/upload_session/finish`, opts
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(
        `Session finish failed (HTTP ${response.statusCode}): ${response.body}`
      );
    }

    return JSON.parse(response.body) as DropboxMetadata;
  }

  // ===========================================================================
  // Download
  // ===========================================================================

  async downloadContent(
    accessToken: string,
    path: string
  ): Promise<ArrayBuffer> {
    const arg: DownloadArg = { path: path };
    const request = http.createHttp();

    try {
      const headerObj: Record<string, string> = {};
      Reflect.set(headerObj, 'Authorization', `Bearer ${accessToken}`);
      Reflect.set(headerObj, 'Content-Type', 'application/octet-stream');
      Reflect.set(headerObj, 'Dropbox-API-Arg', JSON.stringify(arg));

      const requestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: headerObj,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: DropboxConfig.TRANSFER_TIMEOUT_MS,
        connectTimeout: DropboxConfig.REQUEST_TIMEOUT_MS
      };

      const response = await request.request(
        `${this.contentBase}/files/download`, requestOptions
      );
      return response.result as ArrayBuffer;
    } finally {
      request.destroy();
    }
  }

  /**
   * Return the URL and required headers for the download pipeline to
   * fetch a file's bytes. Dropbox requires both a Bearer token and a
   * Dropbox-API-Arg header, so the URL alone is not sufficient.
   */
  async getDownloadInfo(
    accessToken: string,
    path: string
  ): Promise<DownloadInfo> {
    const arg: DownloadArg = { path: path };

    const headers = new Map<string, string>();
    headers.set('Authorization', `Bearer ${accessToken}`);
    headers.set('Content-Type', 'application/octet-stream');
    headers.set('Dropbox-API-Arg', JSON.stringify(arg));

    const info: DownloadInfo = {
      url: `${this.contentBase}/files/download`,
      headers: headers
    };
    return info;
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  static joinPath(parent: string, name: string): string {
    if (parent.length === 0) return `/${name}`;
    if (parent === '/') return `/${name}`;
    return `${parent}/${name}`;
  }

  private static encodeForm(params: Map<string, string>): string {
    const parts: string[] = [];
    params.forEach((value: string, key: string): void => {
      parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
    });
    return parts.join('&');
  }
}
import { http } from '@kit.NetworkKit';
import { HttpError } from './HttpError';
import { Logger } from '../../utils/Logger';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * Caller-facing options for a request. All fields have defaults, so callers
 * can do `new HttpRequestOptions()` and set only what they need.
 * Headers use Map to avoid ArkTS object-literal and index-access issues.
 */
export class HttpRequestOptions {
  method: http.RequestMethod = http.RequestMethod.GET;
  headers: Map<string, string> = new Map<string, string>();
  body: string | ArrayBuffer | null = null;
  jsonBody: object | null = null;
  responseType: http.HttpDataType = http.HttpDataType.STRING;
  readTimeout: number = 30_000;
  connectTimeout: number = 30_000;
}

export interface HttpResponse {
  statusCode: number;
  headers: Record<string, string>;
  body: string;
}

export class HttpClient {
  private static readonly TAG = 'HttpClient';

  static async request(url: string, options?: HttpRequestOptions): Promise<string> {
    const opts: HttpRequestOptions = options ?? new HttpRequestOptions();
    const request = http.createHttp();

    try {
      // Convert Map<string,string> into a plain Record for the HTTP module.
      // Reflect.set avoids arkts-no-props-by-index on the Record.
      const headerObj: Record<string, string> = {};
      opts.headers.forEach((value: string, key: string): void => {
        Reflect.set(headerObj, key, value);
      });

      // Choose the body: raw body wins, otherwise JSON body.
      let extraData: string | ArrayBuffer | undefined = undefined;
      if (opts.body !== null) {
        extraData = opts.body;
      } else if (opts.jsonBody !== null) {
        extraData = JSON.stringify(opts.jsonBody);
        const existing = Reflect.get(headerObj, 'Content-Type');
        if (existing === undefined || existing === null) {
          Reflect.set(headerObj, 'Content-Type', 'application/json');
        }
      }

      const requestOptions: http.HttpRequestOptions = {
        method: opts.method,
        header: headerObj,
        extraData: extraData,
        expectDataType: opts.responseType,
        readTimeout: opts.readTimeout,
        connectTimeout: opts.connectTimeout
      };

      const response = await request.request(url, requestOptions);

      const body: string = typeof response.result === 'string'
        ? response.result
        : JSON.stringify(response.result);

      if (response.responseCode < 200 || response.responseCode >= 300) {
        Logger.error(HttpClient.TAG, `HTTP ${response.responseCode} on ${url}`);
        throw new HttpError(response.responseCode, body, url);
      }
      return body;
    } catch (e) {
      if (e instanceof HttpError) {
        throw e;
      }
      const err: Error = e as Error;
      const be = e as BusinessError;
      const detail: string = be.message !== undefined && be.message !== null
        ? be.message
        : 'Unknown network failure';
      Logger.error(
        HttpClient.TAG,
        `Network error on ${url}: ${detail} (code ${be.code ?? 'none'})`
      );
      // Pass the original error text as the body so formatError can
      // map it. The status code 0 signals "no HTTP response received".
      throw new HttpError(0, detail, url);
    } finally {
      request.destroy();
    }
  }

  static async requestJson<T>(url: string, options?: HttpRequestOptions): Promise<T> {
    const raw: string = await HttpClient.request(url, options);
    return JSON.parse(raw) as T;
  }

  /**
   * Same as request() but also returns the raw response headers.
   * Used by the Graph copy monitor, which needs the Location header.
   */
  static async requestWithHeaders(
    url: string,
    options?: HttpRequestOptions
  ): Promise<HttpResponse> {
    const opts: HttpRequestOptions = options ?? new HttpRequestOptions();
    const request = http.createHttp();
    try {
      const headerObj: Record<string, string> = {};
      opts.headers.forEach((value: string, key: string): void => {
        Reflect.set(headerObj, key, value);
      });

      let extraData: string | ArrayBuffer | undefined = undefined;
      if (opts.body !== null) {
        extraData = opts.body;
      } else if (opts.jsonBody !== null) {
        extraData =
          JSON.stringify(opts.jsonBody);
      }

      const requestOptions: http.HttpRequestOptions = {
        method: opts.method,
        header: headerObj,
        extraData: extraData,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: opts.readTimeout,
        connectTimeout: opts.connectTimeout
      };

      const response = await request.request(url, requestOptions);

      // Normalize headers: HTTP module returns an object keyed by header name.
      const rawHeaders = response.header as Record<string, string | Object>;
      const normalized: Record<string, string> = {};
      if (rawHeaders !== undefined && rawHeaders !== null) {
        const keys = Object.keys(rawHeaders);
        for (let i = 0; i < keys.length; i++) {
          const k = keys[i];
          const v = rawHeaders[k];
          normalized[k.toLowerCase()] = typeof v === 'string' ? v : JSON.stringify(v);
        }
      }

      const body: string = typeof response.result === 'string'
        ? response.result
        : JSON.stringify(response.result);

      return {
        statusCode: response.responseCode,
        headers: normalized,
        body
      };
    } finally {
      request.destroy();
    }
  }
}
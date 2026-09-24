import { http } from '@kit.NetworkKit';
import { HttpClient, HttpRequestOptions } from './HttpClient';

export class RequestBuilder {
  private url: string = '';
  private options: HttpRequestOptions = new HttpRequestOptions();

  static get(url: string): RequestBuilder {
    const b = new RequestBuilder();
    b.url = url;
    b.options.method = http.RequestMethod.GET;
    return b;
  }

  static post(url: string): RequestBuilder {
    const b = new RequestBuilder();
    b.url = url;
    b.options.method = http.RequestMethod.POST;
    return b;
  }

  static put(url: string): RequestBuilder {
    const b = new RequestBuilder();
    b.url = url;
    b.options.method = http.RequestMethod.PUT;
    return b;
  }

  static patch(url: string): RequestBuilder {
    const b = new RequestBuilder();
    b.url = url;
    b.options.method = http.RequestMethod.PATCH;
    return b;
  }

  static delete(url: string): RequestBuilder {
    const b = new RequestBuilder();
    b.url = url;
    b.options.method = http.RequestMethod.DELETE;
    return b;
  }

  header(key: string, value: string): RequestBuilder {
    this.options.headers.set(key, value);
    return this;
  }

  bearer(token: string): RequestBuilder {
    return this.header('Authorization', `Bearer ${token}`);
  }

  jsonBody(body: object): RequestBuilder {
    this.options.jsonBody = body;
    return this;
  }

  rawBody(body: string | ArrayBuffer): RequestBuilder {
    this.options.body = body;
    return this;
  }

  contentType(value: string): RequestBuilder {
    return this.header('Content-Type', value);
  }

  responseType(type: http.HttpDataType): RequestBuilder {
    this.options.responseType = type;
    return this;
  }

  timeout(ms: number): RequestBuilder {
    this.options.readTimeout = ms;
    this.options.connectTimeout = ms;
    return this;
  }

  async execute(): Promise<string> {
    return HttpClient.request(this.url, this.options);
  }

  async executeJson<T>(): Promise<T> {
    const raw: string = await this.execute();
    return JSON.parse(raw) as T;
  }
}
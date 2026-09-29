export class HttpError extends Error {
  code: number = 0;
  body: string = '';
  url: string = '';

  constructor(code: number, body: string, url: string) {
    // The `message` field carries a summary that's readable even if
    // formatError() isn't called. formatError() overrides this with
    // a mapped/cleaner variant when it can.
    super(HttpError.buildSummary(code, body, url));
    this.name = 'HttpError';
    this.code = code;
    this.body = body;
    this.url = url;
  }

  get isUnauthorized(): boolean {
    return this.code === 401;
  }

  get isNotFound(): boolean {
    return this.code === 404;
  }

  get isRateLimited(): boolean {
    return this.code === 429;
  }

  get isNetworkError(): boolean {
    return this.code === 0;
  }

  private static buildSummary(code: number, body: string, url: string): string {
    if (code === 0) {
      return `Network error contacting ${url}`;
    }
    return `HTTP ${code} from ${url}`;
  }
}
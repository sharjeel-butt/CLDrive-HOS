export class HttpError extends Error {
  code: number = 0;
  body: string = '';
  url: string = '';

  constructor(code: number, body: string, url: string) {
    super(`HTTP ${code} on ${url}: ${body}`);
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
}
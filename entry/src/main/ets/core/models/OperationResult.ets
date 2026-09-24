export class OperationResult<T> {
  success: boolean = false;
  data?: T = undefined;
  errorCode?: string = undefined;
  errorMessage?: string = undefined;

  private constructor() {
    // Instances are created via the static factories below.
  }

  static ok<T>(data: T): OperationResult<T> {
    const r = new OperationResult<T>();
    r.success = true;
    r.data = data;
    return r;
  }

  static fail<T>(code: string, message: string): OperationResult<T> {
    const r = new OperationResult<T>();
    r.success = false;
    r.errorCode = code;
    r.errorMessage = message;
    return r;
  }
}
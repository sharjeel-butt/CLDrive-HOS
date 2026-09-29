import { BusinessError } from '@kit.BasicServicesKit';
import { HttpError } from '../core/network/HttpError';

/**
 * Centralized error-to-message conversion. Every place that shows an
 * error to the user — activity rows, toasts, dialogs — should call
 * formatError() so the text is consistent and readable.
 */

// ---------------------------------------------------------------------------
// HarmonyOS file-system error codes
// ---------------------------------------------------------------------------
const FS_ERROR_MAP: Map<number, string> = new Map([
  [13900001, 'Operation not permitted'],
  [13900002, 'File not found'],
  [13900003, 'Process not found'],
  [13900004, 'Operation interrupted'],
  [13900005, 'I/O error'],
  [13900011, 'Out of memory'],
  [13900012, 'Permission denied'],
  [13900013, 'Invalid memory address'],
  [13900014, 'Device or resource busy'],
  [13900015, 'File already exists'],
  [13900016, 'Cross-device operation not supported'],
  [13900017, 'Device not found'],
  [13900018, 'Not a directory'],
  [13900019, 'Is a directory'],
  [13900020, 'Invalid argument'],
  [13900021, 'File table overflow'],
  [13900022, 'Too many open files'],
  [13900023, 'File is busy'],
  [13900024, 'File is too large'],
  [13900025, 'No space left on device'],
  [13900026, 'Invalid seek'],
  [13900027, 'Read-only file system'],
  [13900028, 'Too many links'],
  [13900029, 'Broken pipe'],
  [13900030, 'Math error'],
  [13900031, 'Math result not representable'],
  [13900032, 'Deadlock detected'],
  [13900033, 'Filename is too long'],
  [13900035, 'Operation not implemented'],
  [13900036, 'Directory not empty'],
  [13900037, 'Too many symbolic links'],
  [13900038, 'No data available'],
  [13900039, 'Timer expired'],
  [13900042, 'Unknown error'],
  [13900043, 'File name too long'],
  [14300002, 'Invalid URI']
]);

// ---------------------------------------------------------------------------
// Network-layer error codes (@ohos.net.http uses 2300xxx)
// ---------------------------------------------------------------------------
const NETWORK_ERROR_MAP: Map<number, string> = new Map([
  [2300001, 'Unsupported protocol'],
  [2300003, 'URL is malformed'],
  [2300005, 'Proxy resolution failed'],
  [2300006, 'Hostname could not be resolved'],
  [2300007, 'Could not connect to server'],
  [2300008, 'Bad HTTP response from server'],
  [2300028, 'Request timed out'],
  [2300052, 'Empty reply from server'],
  [2300060, 'Server SSL certificate is not trusted'],
  [2300061, 'SSL certificate could not be verified'],
  [2300999, 'Unknown network error']
]);

// ---------------------------------------------------------------------------
// HTTP status codes
// ---------------------------------------------------------------------------
const HTTP_STATUS_MAP: Map<number, string> = new Map([
  [400, 'Bad request — the server rejected the request'],
  [401, 'Authentication expired — please sign in again'],
  [403, 'Permission denied by the cloud provider'],
  [404, 'File or folder not found on the server'],
  [405, 'Operation not allowed on this item'],
  [408, 'Server timed out while waiting for the request'],
  [409, 'Conflicting change on the server — try again'],
  [410, 'The file has been permanently removed'],
  [413, 'File is too large for the server to accept'],
  [415, 'File type is not supported by the server'],
  [422, 'The server rejected the request as invalid'],
  [429, 'Too many requests — please wait a moment and try again'],
  [500, 'Server error — try again in a moment'],
  [502, 'Server is temporarily unreachable'],
  [503, 'Service is temporarily unavailable'],
  [504, 'Server gateway timed out']
]);

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Convert any error into a message suitable for display to a user.
 * Never returns empty, never returns raw JSON, never returns a bare
 * numeric code without a description.
 */
export function formatError(e: Error | BusinessError | undefined | null): string {
  if (e === undefined || e === null) return 'Unknown error';

  // 1. Our own HttpError — carries HTTP status and server message.
  if (e instanceof HttpError) {
    return formatHttpError(e);
  }

  // 2. HarmonyOS BusinessError — carries a numeric code.
  const be = e as BusinessError;
  if (be.code !== undefined && be.code !== null && be.code > 0) {
    const code: number = be.code;

    const fsMsg: string | undefined = FS_ERROR_MAP.get(code);
    if (fsMsg !== undefined) return fsMsg;

    const netMsg: string | undefined = NETWORK_ERROR_MAP.get(code);
    if (netMsg !== undefined) return netMsg;

    // Unknown code — include the numeric so support can search for it,
    // but prefix with context so it's not a bare number.
    const raw: string = be.message !== undefined && be.message !== null
      ? be.message
      : 'Unknown';
    return `${raw} (code ${code})`;
  }

  // 3. Plain Error.
  const msg: string = e.message !== undefined && e.message !== null
    ? e.message
    : String(e);

  // Sometimes providers embed a JSON blob in the message — extract it.
  const extracted: string | null = extractProviderMessage(msg);
  if (extracted !== null) return extracted;

  return cleanMessage(msg);
}

/**
 * Format a HttpError into readable text. Uses the HTTP status map when
 * possible; falls back to the server-provided message otherwise.
 */
function formatHttpError(err: HttpError): string {
  // Network-layer failure — status 0 means "no response at all".
  if (err.code === 0) {
    const detail: string = err.body.length > 0
      ? err.body
      : 'Check your internet connection and try again';
    return `Network error: ${cleanMessage(detail)}`;
  }

  // Provider-specific JSON in the body? Try to extract a real message.
  const providerMsg: string | null = extractProviderMessage(err.body);
  if (providerMsg !== null) {
    return `Server rejected: ${providerMsg}`;
  }

  const statusMsg: string | undefined = HTTP_STATUS_MAP.get(err.code);
  if (statusMsg !== undefined) {
    return statusMsg;
  }

  if (err.code >= 500) {
    return `Server error (HTTP ${err.code}) — try again in a moment`;
  }
  if (err.code >= 400) {
    return `Request rejected (HTTP ${err.code})`;
  }

  return `Unexpected response (HTTP ${err.code})`;
}

/**
 * Look for a structured error message inside a body that might be
 * Microsoft Graph JSON ({"error": {"message": "..."}}), Google Drive
 * JSON ({"error": {"message": "..."}}), or a plain string.
 *
 * Returns null if no recognisable message is found.
 */
function extractProviderMessage(body: string): string | null {
  if (body === undefined || body === null || body.length === 0) return null;

  const trimmed: string = body.trim();
  if (!trimmed.startsWith('{')) return null;

  try {
    const parsed = JSON.parse(trimmed) as Record<string, Object>;
    const errObj = parsed['error'];

    if (errObj !== undefined && errObj !== null) {
      if (typeof errObj === 'string') {
        return cleanMessage(errObj);
      }
      const errRecord = errObj as Record<string, Object>;
      const msg = errRecord['message'];
      if (typeof msg === 'string' && msg.length > 0) {
        return cleanMessage(msg);
      }
      const errDesc = errRecord['error_description'];
      if (typeof errDesc === 'string' && errDesc.length > 0) {
        return cleanMessage(errDesc);
      }
    }

    const directMsg = parsed['message'];
    if (typeof directMsg === 'string' && directMsg.length > 0) {
      return cleanMessage(directMsg);
    }
    const directDesc = parsed['error_description'];
    if (typeof directDesc === 'string' && directDesc.length > 0) {
      return cleanMessage(directDesc);
    }
  } catch (_) {
    // Not JSON — fall through.
  }
  return null;
}

/**
 * Trim noise from a raw message: leading/trailing whitespace, URL
 * fragments that aren't helpful, and envelope words like "Error:".
 */
function cleanMessage(msg: string): string {
  if (msg === undefined || msg === null) return 'Unknown error';

  let cleaned: string = msg.trim();

  // Drop the "HTTP NNN on <url>: " prefix if one is present.
  const httpPrefix: number = cleaned.indexOf('): ');
  if (cleaned.indexOf('HTTP') === 0 && httpPrefix > 0 && httpPrefix < 200) {
    cleaned = cleaned.substring(httpPrefix + 3).trim();
  }

  // Strip enclosing quotes if present.
  if (cleaned.startsWith('"') && cleaned.endsWith('"') && cleaned.length > 1) {
    cleaned = cleaned.substring(1, cleaned.length - 1);
  }

  // Cap overly long messages.
  if (cleaned.length > 220) {
    cleaned = cleaned.substring(0, 217) + '...';
  }

  return cleaned.length > 0 ? cleaned : 'Unknown error';
}
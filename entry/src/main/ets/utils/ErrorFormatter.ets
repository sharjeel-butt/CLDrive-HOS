import { BusinessError } from '@kit.BasicServicesKit';
import { HttpError } from '../core/network/HttpError';
import { t, tNamed } from '../core/i18n/I18n';

// ---------------------------------------------------------------------------
// HarmonyOS file-system error codes → i18n keys
// ---------------------------------------------------------------------------

const FS_CODE_TO_KEY: Map<number, string> = new Map([
  [13900001, 'err.fs.perm'],
  [13900002, 'err.fs.notFound'],
  [13900003, 'err.unknown'],
  [13900004, 'err.unknown'],
  [13900005, 'err.fs.io'],
  [13900011, 'err.unknown'],
  [13900012, 'err.fs.denied'],
  [13900013, 'err.unknown'],
  [13900014, 'err.unknown'],
  [13900015, 'err.fs.exists'],
  [13900016, 'err.unknown'],
  [13900017, 'err.unknown'],
  [13900018, 'err.fs.notDir'],
  [13900019, 'err.fs.isDir'],
  [13900020, 'err.unknown'],
  [13900021, 'err.unknown'],
  [13900022, 'err.fs.tooManyFiles'],
  [13900023, 'err.unknown'],
  [13900024, 'err.unknown'],
  [13900025, 'err.fs.noSpace'],
  [13900026, 'err.unknown'],
  [13900027, 'err.fs.denied'],
  [13900028, 'err.unknown'],
  [13900029, 'err.unknown'],
  [13900030, 'err.unknown'],
  [13900031, 'err.unknown'],
  [13900032, 'err.unknown'],
  [13900033, 'err.fs.nameTooLong'],
  [13900035, 'err.unknown'],
  [13900036, 'err.fs.dirNotEmpty'],
  [13900037, 'err.unknown'],
  [13900038, 'err.unknown'],
  [13900039, 'err.unknown'],
  [13900042, 'err.unknown'],
  [13900043, 'err.fs.nameTooLong'],
  [14300002, 'err.unknown']
]);

// ---------------------------------------------------------------------------
// Network-layer error codes (@ohos.net.http uses 2300xxx)
// ---------------------------------------------------------------------------

const NET_CODE_TO_KEY: Map<number, string> = new Map([
  [2300001, 'err.net.proto'],
  [2300003, 'err.net.url'],
  [2300005, 'err.net.host'],
  [2300006, 'err.net.host'],
  [2300007, 'err.net.connect'],
  [2300008, 'err.net.badResponse'],
  [2300028, 'err.net.timeout'],
  [2300052, 'err.net.emptyReply'],
  [2300060, 'err.net.ssl'],
  [2300061, 'err.net.ssl'],
  [2300999, 'err.net.connect']
]);

// ---------------------------------------------------------------------------
// HTTP status codes
// ---------------------------------------------------------------------------

const HTTP_STATUS_TO_KEY: Map<number, string> = new Map([
  [400, 'err.http.400'],
  [401, 'err.http.401'],
  [403, 'err.http.403'],
  [404, 'err.http.404'],
  [405, 'err.http.405'],
  [408, 'err.http.408'],
  [409, 'err.http.409'],
  [410, 'err.http.410'],
  [413, 'err.http.413'],
  [415, 'err.http.415'],
  [422, 'err.http.422'],
  [429, 'err.http.429'],
  [500, 'err.http.500'],
  [502, 'err.http.502'],
  [503, 'err.http.503'],
  [504, 'err.http.504']
]);

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Convert any error into a message suitable for display to a user.
 * Never returns empty, never returns raw JSON, never returns a bare
 * numeric code without a description. The result is localized using
 * the currently active language.
 */
export function formatError(
  e: Error | BusinessError | undefined | null
): string {
  if (e === undefined || e === null) return t('err.unknown');

  // 1. Our own HttpError — carries HTTP status and server message.
  if (e instanceof HttpError) {
    return formatHttpError(e);
  }

  // 2. HarmonyOS BusinessError — carries a numeric code.
  const be = e as BusinessError;
  if (be.code !== undefined && be.code !== null && be.code > 0) {
    const code: number = be.code;

    const fsKey: string | undefined = FS_CODE_TO_KEY.get(code);
    if (fsKey !== undefined) return t(fsKey);

    const netKey: string | undefined = NET_CODE_TO_KEY.get(code);
    if (netKey !== undefined) return t(netKey);

    // Unknown code — include the numeric so support can search for it.
    const raw: string = be.message !== undefined && be.message !== null
      ? be.message
      : t('err.unknown');
    return `${raw} (${t('err.code')} ${code})`;
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

function formatHttpError(err: HttpError): string {
  if (err.code === 0) {
    const detail: string = err.body.length > 0
      ? err.body
      : t('err.checkConnection');
    return `${t('err.network')}: ${cleanMessage(detail)}`;
  }

  const providerMsg: string | null = extractProviderMessage(err.body);
  if (providerMsg !== null) {
    return `${t('err.serverRejected')} ${providerMsg}`;
  }

  const statusKey: string | undefined = HTTP_STATUS_TO_KEY.get(err.code);
  if (statusKey !== undefined) {
    return t(statusKey);
  }

  if (err.code >= 500) {
    return `${t('err.serverError')} (HTTP ${err.code}) — ${t('err.tryAgain')}`;
  }
  if (err.code >= 400) {
    return `${t('err.requestRejected')} (HTTP ${err.code})`;
  }

  return `${t('err.unexpected')} (HTTP ${err.code})`;
}

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

function cleanMessage(msg: string): string {
  if (msg === undefined || msg === null) return t('err.unknown');

  let cleaned: string = msg.trim();

  const httpPrefix: number = cleaned.indexOf('): ');
  if (cleaned.indexOf('HTTP') === 0 && httpPrefix > 0 && httpPrefix < 200) {
    cleaned = cleaned.substring(httpPrefix + 3).trim();
  }

  if (cleaned.startsWith('"') && cleaned.endsWith('"') && cleaned.length > 1) {
    cleaned = cleaned.substring(1, cleaned.length - 1);
  }

  if (cleaned.length > 220) {
    cleaned = cleaned.substring(0, 217) + '...';
  }

  return cleaned.length > 0 ? cleaned : t('err.unknown');
}
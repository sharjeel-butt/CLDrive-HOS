import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { AuthTokens } from '../models/AuthTokens';
import { Logger } from '../../utils/Logger';

function strToBytes(str: string): Uint8Array {
  return new util.TextEncoder().encodeInto(str);
}

function bytesToStr(bytes: Uint8Array): string {
  return new util.TextDecoder().decodeToString(bytes);
}

/**
 * Secure token storage backed by Asset Store.
 *
 * Keys are account IDs (e.g. "onedrive_abc123") rather than provider
 * names, so multiple accounts for the same provider can coexist.
 *
 * Each SECRET value is split into 900-byte chunks to stay under Asset
 * Store's 1024-byte per-value limit.
 */
export class TokenStorage {
  private static readonly TAG = 'TokenStorage';
  private static readonly CHUNK_SIZE = 900;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  static async save(accountId: string, tokens: AuthTokens): Promise<void> {
    await TokenStorage.storeChunked(accountId, 'access', tokens.accessToken);
    await TokenStorage.storeChunked(accountId, 'refresh', tokens.refreshToken);
  }

  static async getAccess(accountId: string): Promise<string | null> {
    return TokenStorage.loadChunked(accountId, 'access');
  }

  static async getRefresh(accountId: string): Promise<string | null> {
    return TokenStorage.loadChunked(accountId, 'refresh');
  }

  static async clear(accountId: string): Promise<void> {
    await TokenStorage.removeChunked(accountId, 'access');
    await TokenStorage.removeChunked(accountId, 'refresh');
  }

  // ---------------------------------------------------------------------------
  // Aliases
  // ---------------------------------------------------------------------------

  private static countAlias(accountId: string, kind: string): string {
    return `${accountId}_${kind}_chunk_count`;
  }

  private static chunkAlias(accountId: string, kind: string, index: number): string {
    return `${accountId}_${kind}_chunk_${index}`;
  }

  // ---------------------------------------------------------------------------
  // Chunked storage
  // ---------------------------------------------------------------------------

  private static async storeChunked(
    accountId: string,
    kind: string,
    value: string
  ): Promise<void> {
    await TokenStorage.removeChunked(accountId, kind);

    const bytes: Uint8Array = strToBytes(value);
    const chunkCount: number = Math.ceil(bytes.length / TokenStorage.CHUNK_SIZE) || 1;

    await TokenStorage.putRaw(
      TokenStorage.countAlias(accountId, kind),
      strToBytes(String(chunkCount))
    );

    for (let i = 0; i < chunkCount; i++) {
      const start = i * TokenStorage.CHUNK_SIZE;
      const end = Math.min(start + TokenStorage.CHUNK_SIZE, bytes.length);
      const slice = bytes.slice(start, end);
      await TokenStorage.putRaw(
        TokenStorage.chunkAlias(accountId, kind, i),
        slice
      );
    }

    Logger.info(
      TokenStorage.TAG,
      `Stored ${kind} for ${accountId} as ${chunkCount} chunk(s)`
    );
  }

  private static async loadChunked(
    accountId: string,
    kind: string
  ): Promise<string | null> {
    const countStr = await TokenStorage.getRaw(
      TokenStorage.countAlias(accountId, kind)
    );
    if (countStr === null || countStr.length === 0) {
      return null;
    }

    const count = parseInt(countStr, 10);
    if (isNaN(count) || count <= 0) {
      return null;
    }

    const parts: Uint8Array[] = [];
    let total = 0;
    for (let i = 0; i < count; i++) {
      const chunk = await TokenStorage.getRawBytes(
        TokenStorage.chunkAlias(accountId, kind, i)
      );
      if (chunk === null) {
        Logger.error(TokenStorage.TAG, `Missing ${kind} chunk ${i}/${count} for ${accountId}`);
        return null;
      }
      parts.push(chunk);
      total += chunk.length;
    }

    const merged = new Uint8Array(total);
    let offset = 0;
    for (let i = 0; i < parts.length; i++) {
      merged.set(parts[i], offset);
      offset += parts[i].length;
    }
    return bytesToStr(merged);
  }

  private static async removeChunked(
    accountId: string,
    kind: string
  ): Promise<void> {
    const countStr = await TokenStorage.getRaw(
      TokenStorage.countAlias(accountId, kind)
    );
    if (countStr !== null && countStr.length > 0) {
      const count = parseInt(countStr, 10);
      if (!isNaN(count) && count > 0) {
        for (let i = 0; i < count; i++) {
          await TokenStorage.removeRaw(
            TokenStorage.chunkAlias(accountId, kind, i)
          );
        }
      }
    }
    await TokenStorage.removeRaw(TokenStorage.countAlias(accountId, kind));
  }

  // ---------------------------------------------------------------------------
  // Raw helpers
  // ---------------------------------------------------------------------------

  private static async putRaw(alias: string, secret: Uint8Array): Promise<void> {
    const attr: asset.AssetMap = new Map();
    attr.set(asset.Tag.ALIAS, strToBytes(alias));
    attr.set(asset.Tag.SECRET, secret);
    attr.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    attr.set(asset.Tag.IS_PERSISTENT, false);

    try {
      await asset.add(attr);
    } catch (e) {
      const err: Error = e as Error;
      const bizErr = e as BusinessError;
      Logger.error(
        TokenStorage.TAG,
        `asset.add ${alias} failed: ${bizErr.code} ${bizErr.message}`
      );
      throw err;
    }
  }

  private static async getRaw(alias: string): Promise<string | null> {
    const bytes = await TokenStorage.getRawBytes(alias);
    return bytes === null ? null : bytesToStr(bytes);
  }

  private static async getRawBytes(alias: string): Promise<Uint8Array | null> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, strToBytes(alias));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);

    try {
      const res = await asset.query(query);
      if (res.length === 0) {
        return null;
      }
      const secret = res[0].get(asset.Tag.SECRET) as Uint8Array;
      return secret ?? null;
    } catch (e) {
      const bizErr = e as BusinessError;
      if (bizErr.code === 24000002) {
        return null;
      }
      Logger.error(
        TokenStorage.TAG,
        `asset.query ${alias} failed: ${bizErr.code} ${bizErr.message}`
      );
      return null;
    }
  }

  private static async removeRaw(alias: string): Promise<void> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, strToBytes(alias));
    try {
      await asset.remove(query);
    } catch (_) {

    }
  }
}
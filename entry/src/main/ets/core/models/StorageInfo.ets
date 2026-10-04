/**
 * Quota information for a cloud drive account.
 * `total <= 0` means the provider reports unlimited or unknown.
 */
export interface StorageInfo {
  used: number;
  total: number;
  isUnlimited: boolean;
}

export function createStorageInfo(used: number, total: number): StorageInfo {
  return {
    used: used,
    total: total,
    isUnlimited: total <= 0
  };
}
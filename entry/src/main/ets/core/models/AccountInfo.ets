import { CloudProviderType } from './CloudProviderType';

export interface AccountInfo {
  accountId: string;
  provider: CloudProviderType;
  displayName: string;
  email?: string;
  avatarUrl?: string;
  addedAt: number;
}

export function makeAccountId(
  provider: CloudProviderType,
  uniquePart: string
): string {
  // Sanitize: keep only alphanumerics, dashes, underscores.
  let safe = '';
  for (let i = 0; i < uniquePart.length; i++) {
    const c = uniquePart.charAt(i);
    if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') || c === '-' || c === '_') {
      safe += c;
    } else if (c === '@' || c === '.') {
      safe += '_';
    }
  }
  return `${provider}_${safe}`;
}

export function providerFromAccountId(accountId: string): CloudProviderType {
  if (accountId.startsWith('onedrive_')) {
    return CloudProviderType.ONEDRIVE;
  }
  if (accountId.startsWith('googledrive_')) {
    return CloudProviderType.GOOGLE_DRIVE;
  }
  return CloudProviderType.ONEDRIVE;
}
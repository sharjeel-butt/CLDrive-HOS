export enum CloudProviderType {
  ONEDRIVE = 'onedrive',
  GOOGLE_DRIVE = 'googledrive',
  DROPBOX = 'dropbox',

  // ---- Announced but not yet implemented. ----
  // These have no AuthProvider, ApiClient, or Provider
  // implementations. They exist so the onboarding provider list and
  // ProviderIcon can render them as "coming soon" entries. Attempting
  // to instantiate one via CloudProviderFactory throws.
  WEBDAV = 'webdav',
  S3 = 's3',
  BOX = 'box'
}

/**
 * True when the provider has a working implementation.
 * The onboarding picker uses this to decide between "tap to sign in"
 * and "coming soon".
 */
export function isProviderSupported(type: CloudProviderType): boolean {
  return type === CloudProviderType.ONEDRIVE
    || type === CloudProviderType.GOOGLE_DRIVE
    || type === CloudProviderType.DROPBOX;
}
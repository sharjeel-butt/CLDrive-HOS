import { ICloudProvider } from '../interfaces/ICloudProvider';
import { IAuthProvider } from '../interfaces/IAuthProvider';
import { CloudProviderType } from '../models/CloudProviderType';
import { OneDriveProvider } from './onedrive/OneDriveProvider';
import { OneDriveAuthProvider } from './onedrive/OneDriveAuthProvider';
import { GoogleDriveProvider } from './googledrive/GoogleDriveProvider';
import { GoogleDriveAuthProvider } from './googledrive/GoogleDriveAuthProvider';
import { DropboxProvider } from './dropbox/DropboxProvider';
import { DropboxAuthProvider } from './dropbox/DropboxAuthProvider';

export class CloudProviderFactory {
  private static providerCache: Map<string, ICloudProvider> = new Map();
  private static authCache: Map<CloudProviderType, IAuthProvider> = new Map();

  static getProvider(
    accountId: string,
    type: CloudProviderType
  ): ICloudProvider {
    const key: string = `${accountId}::${type}`;
    const cached: ICloudProvider | undefined =
      CloudProviderFactory.providerCache.get(key);
    if (cached !== undefined) return cached;

    let provider: ICloudProvider;
    switch (type) {
      case CloudProviderType.ONEDRIVE:
        provider = new OneDriveProvider(accountId);
        break;
      case CloudProviderType.GOOGLE_DRIVE:
        provider = new GoogleDriveProvider(accountId);
        break;
      case CloudProviderType.DROPBOX:
        provider = new DropboxProvider(accountId);
        break;
      default:
        throw new Error(`Unsupported provider: ${type}`);
    }

    CloudProviderFactory.providerCache.set(key, provider);
    return provider;
  }

  static getAuthProvider(type: CloudProviderType): IAuthProvider {
    const cached: IAuthProvider | undefined =
      CloudProviderFactory.authCache.get(type);
    if (cached !== undefined) return cached;

    let auth: IAuthProvider;
    switch (type) {
      case CloudProviderType.ONEDRIVE:
        auth = new OneDriveAuthProvider();
        break;
      case CloudProviderType.GOOGLE_DRIVE:
        auth = new GoogleDriveAuthProvider();
        break;
      case CloudProviderType.DROPBOX:
        auth = new DropboxAuthProvider();
        break;
      default:
        throw new Error(`Unsupported auth provider: ${type}`);
    }

    CloudProviderFactory.authCache.set(type, auth);
    return auth;
  }

  static evict(accountId: string): void {
    const toDelete: string[] = [];
    CloudProviderFactory.providerCache.forEach(
      (_v: ICloudProvider, k: string): void => {
        if (k.startsWith(`${accountId}::`)) toDelete.push(k);
      }
    );
    for (let i = 0; i < toDelete.length; i++) {
      CloudProviderFactory.providerCache.delete(toDelete[i]);
    }
  }
}
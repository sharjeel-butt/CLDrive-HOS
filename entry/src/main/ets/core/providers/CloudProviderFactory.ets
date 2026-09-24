import { ICloudProvider } from '../interfaces/ICloudProvider';
import { IAuthProvider } from '../interfaces/IAuthProvider';
import { CloudProviderType } from '../models/CloudProviderType';
import { OneDriveProvider } from './onedrive/OneDriveProvider';
import { OneDriveAuthProvider } from './onedrive/OneDriveAuthProvider';
import { GoogleDriveProvider } from './googledrive/GoogleDriveProvider';
import { GoogleDriveAuthProvider } from './googledrive/GoogleDriveAuthProvider';

export class CloudProviderFactory {
  private static providerCache: Map<string, ICloudProvider> = new Map();
  private static authCache: Map<CloudProviderType, IAuthProvider> = new Map();

  static getProvider(
    accountId: string,
    type: CloudProviderType
  ): ICloudProvider {
    const key = `${accountId}::${type}`;
    if (CloudProviderFactory.providerCache.has(key)) {
      return CloudProviderFactory.providerCache.get(key)!;
    }

    let provider: ICloudProvider;
    switch (type) {
      case CloudProviderType.ONEDRIVE:
        provider = new OneDriveProvider(accountId);
        break;
      case CloudProviderType.GOOGLE_DRIVE:
        provider = new GoogleDriveProvider(accountId);
        break;
      default:
        throw new Error(`Unsupported provider: ${type}`);
    }

    CloudProviderFactory.providerCache.set(key, provider);
    return provider;
  }

  static getAuthProvider(type: CloudProviderType): IAuthProvider {
    if (CloudProviderFactory.authCache.has(type)) {
      return CloudProviderFactory.authCache.get(type)!;
    }

    let auth: IAuthProvider;
    switch (type) {
      case CloudProviderType.ONEDRIVE:
        auth = new OneDriveAuthProvider();
        break;
      case CloudProviderType.GOOGLE_DRIVE:
        auth = new GoogleDriveAuthProvider();
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
import { bundleManager } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from './Logger';

const TAG: string = 'AppInfo';

/**
 * Application version metadata, sourced from AppScope/app.json5.
 *
 * Fields map directly to app.json5:
 *   versionName  → versionName
 *   versionCode  → versionCode
 *   bundleName   → bundleName
 *   appName      → label (the string resource referenced by `label`)
 */
export interface AppVersionInfo {
  /** Marketing version, e.g. "1.0.0". Comes from app.json5.versionName. */
  versionName: string;

  /** Monotonic integer build number. Comes from app.json5.versionCode. */
  versionCode: number;

  /** Package identifier, e.g. "com.cldrive.hos.app". */
  bundleName: string;

  /** Human-readable app name. Resolved from the `label` string resource. */
  appName: string;
}

/**
 * Read the current application's version metadata.
 *
 * Synchronous — the data is cached by the OS after the first call, so
 * it's safe to call from any UI builder or ViewModel.
 */
export function getAppVersionInfo(): AppVersionInfo {
  try {
    const info: bundleManager.BundleInfo =
      bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );

    // ---- versionName and versionCode ----
    const versionName: string =
      info.versionName !== undefined && info.versionName !== null
        ? info.versionName
        : '—';

    const versionCode: number =
      info.versionCode !== undefined && info.versionCode !== null
        ? info.versionCode
        : 0;

    const bundleName: string =
      info.name !== undefined && info.name !== null
        ? info.name
        : '—';

    // ---- appName (from the application's label resource) ----
    let appName: string = '—';
    const appInfo: bundleManager.ApplicationInfo | undefined = info.appInfo;
    if (appInfo !== undefined && appInfo !== null) {
      // `label` is the string resource ID set in app.json5. Some builds
      // also expose `labelId` for the resource reference.
      if (appInfo.label !== undefined && appInfo.label !== null
        && appInfo.label.length > 0) {
        appName = appInfo.label;
      } else if (appInfo.labelId !== undefined && appInfo.labelId > 0) {
        // Fallback: read the resource by ID if available.
        try {
          appName = getContext().resourceManager.getStringSync(appInfo.labelId);
        } catch (_) {
          appName = bundleName;
        }
      } else {
        appName = bundleName;
      }
    }

    Logger.info(
      TAG,
      `App version: ${versionName} (code ${versionCode}) — ${bundleName}`
    );

    return {
      versionName,
      versionCode,
      bundleName,
      appName
    };
  } catch (e) {
    const err: Error = e as Error;
    const be = e as BusinessError;
    Logger.error(
      TAG,
      `getBundleInfoForSelfSync failed: ${err.message} ` +
        `(code ${be.code ?? 'none'})`
    );

    // Fallback — return placeholders so the UI never crashes.
    return {
      versionName: '—',
      versionCode: 0,
      bundleName: '—',
      appName: '—'
    };
  }
}

/**
 * Convenience: format the version code as a user-friendly build label.
 * versionCode 1000000 → "1.0.0 (1000000)"
 */
export function formatVersionLabel(): string {
  const info = getAppVersionInfo();
  if (info.versionCode === 0) return info.versionName;
  return `${info.versionName} (${info.versionCode})`;
}

/**
 * Return the build number derived from versionCode. HarmonyOS apps
 * commonly encode versionCode as MMmmpp (major/minor/patch), so
 * 1000000 → build 1, 1000001 → build 2, etc. This function returns
 * just the raw numeric code formatted as a string for display.
 */
export function getBuildNumber(): string {
  const info = getAppVersionInfo();
  return info.versionCode.toString();
}
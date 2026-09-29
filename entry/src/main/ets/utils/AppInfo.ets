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

    // ---- appName (resolved from the label string resource) ----
    //
    // On API 26, `appInfo.label` returns the raw reference from
    // app.json5 (e.g. "$string:app_name") instead of the resolved
    // string. `appInfo.labelId` is the numeric resource ID we can
    // actually pass to resourceManager.getStringSync(). Prefer it,
    // and only accept `label` if it looks like a resolved string
    // rather than a resource reference.
    let appName: string = '—';
    const appInfo: bundleManager.ApplicationInfo | undefined = info.appInfo;
    if (appInfo !== undefined && appInfo !== null) {
      // Preferred path: resolve by numeric resource ID.
      if (appInfo.labelId !== undefined && appInfo.labelId > 0) {
        try {
          appName = getContext().resourceManager.getStringSync(appInfo.labelId);
        } catch (e) {
          const err: Error = e as Error;
          Logger.warn(
            TAG,
            `getStringSync(labelId=${appInfo.labelId}) failed: ${err.message}`
          );
        }
      }

      // Fallback: accept `label` only if it is not a raw reference.
      // Raw references look like "$string:app_name" or "@string/app_name".
      if ((appName === '—' || appName.length === 0)
        && appInfo.label !== undefined
        && appInfo.label !== null
        && appInfo.label.length > 0
        && !appInfo.label.startsWith('$string:')
        && !appInfo.label.startsWith('@string/')) {
        appName = appInfo.label;
      }

      // Last resort: use the bundle name so the UI never shows a
      // resource reference.
      if (appName === '—' || appName.length === 0) {
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
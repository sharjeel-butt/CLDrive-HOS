import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Logger } from '../../utils/Logger';

const TAG: string = 'PrivacyPrefs';

/**
 * Stores whether the user has accepted the privacy policy.
 * Lives in the same cl_drive_settings Preferences store as
 * ThemeManager and UiPrefs, so all app settings are co-located.
 */
export class PrivacyPrefs {
  private static readonly STORE_NAME = 'cl_drive_settings';
  private static readonly KEY_ACCEPTED = 'privacy_policy_accepted';
  private static readonly KEY_ACCEPTED_AT = 'privacy_policy_accepted_at';

  /**
   * Bump this when the policy changes materially. A stored
   * acceptance older than this version is treated as stale and the
   * user is asked to review the policy again.
   */
  static readonly POLICY_VERSION: number = 1;

  private static prefs: preferences.Preferences | null = null;

  static async init(context: common.Context): Promise<void> {
    if (PrivacyPrefs.prefs !== null) return;
    PrivacyPrefs.prefs = await preferences.getPreferences(
      context, PrivacyPrefs.STORE_NAME
    );
    Logger.info(TAG, 'PrivacyPrefs initialised.');
  }

  /**
   * Returns true if the user has accepted the current policy version.
   */
  static async isAccepted(): Promise<boolean> {
    const p = PrivacyPrefs.ensure();
    const accepted = await p.get(PrivacyPrefs.KEY_ACCEPTED, false);
    if (typeof accepted !== 'boolean' || !accepted) return false;

    const version = await p.get('privacy_policy_version', 0);
    const stored: number = typeof version === 'number' ? version : 0;
    return stored >= PrivacyPrefs.POLICY_VERSION;
  }

  static async accept(): Promise<void> {
    const p = PrivacyPrefs.ensure();
    await p.put(PrivacyPrefs.KEY_ACCEPTED, true);
    await p.put(PrivacyPrefs.KEY_ACCEPTED_AT, Date.now());
    await p.put('privacy_policy_version', PrivacyPrefs.POLICY_VERSION);
    await p.flush();
    Logger.info(TAG, `Privacy policy v${PrivacyPrefs.POLICY_VERSION} accepted.`);
  }

  static async reset(): Promise<void> {
    const p = PrivacyPrefs.ensure();
    await p.put(PrivacyPrefs.KEY_ACCEPTED, false);
    await p.put(PrivacyPrefs.KEY_ACCEPTED_AT, 0);
    await p.put('privacy_policy_version', 0);
    await p.flush();
    Logger.info(TAG, 'Privacy acceptance reset.');
  }

  private static ensure(): preferences.Preferences {
    if (PrivacyPrefs.prefs === null) {
      throw new Error('PrivacyPrefs.init(context) must be called before use.');
    }
    return PrivacyPrefs.prefs;
  }
}
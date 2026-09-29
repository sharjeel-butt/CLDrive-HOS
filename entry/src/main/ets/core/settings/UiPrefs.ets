import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Logger } from '../../utils/Logger';

const TAG: string = 'UiPrefs';

/**
 * Persistent store for UI behaviour preferences that aren't theme
 * related. Lives in the same Preferences file as ThemeManager
 * ('cl_drive_settings') so all UI settings are co-located.
 */
export class UiPrefs {
  private static readonly STORE_NAME = 'cl_drive_settings';
  private static readonly KEY_COLLAPSE_SIDEBAR = 'sidebar_collapse_by_default';

  private static prefs: preferences.Preferences | null = null;

  static async init(context: common.Context): Promise<void> {
    if (UiPrefs.prefs !== null) return;
    UiPrefs.prefs = await preferences.getPreferences(context, UiPrefs.STORE_NAME);
    Logger.info(TAG, 'UiPrefs initialised.');
  }

  /**
   * True = sidebar provider groups start collapsed each launch.
   * Default: true.
   */
  static async getCollapseSidebarGroups(): Promise<boolean> {
    const p = UiPrefs.ensure();
    const raw = await p.get(UiPrefs.KEY_COLLAPSE_SIDEBAR, true);
    return typeof raw === 'boolean' ? raw : true;
  }

  static async setCollapseSidebarGroups(value: boolean): Promise<void> {
    const p = UiPrefs.ensure();
    await p.put(UiPrefs.KEY_COLLAPSE_SIDEBAR, value);
    await p.flush();
    Logger.info(TAG, `Collapse sidebar by default: ${value}`);
  }

  private static ensure(): preferences.Preferences {
    if (UiPrefs.prefs === null) {
      throw new Error('UiPrefs.init(context) must be called before use.');
    }
    return UiPrefs.prefs;
  }
}
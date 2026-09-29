import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';
import { LangCode } from './Language';
import { setRuntimeLanguage } from './I18n';
import { Logger } from '../../utils/Logger';

const TAG: string = 'LanguageManager';

const KEY_VERSION: string = 'languageVersion';

export class LanguageManager {
  private static readonly STORE_NAME = 'cl_drive_settings';
  private static readonly KEY_LANG = 'app_language';
  private static readonly KEY_CHOSEN = 'app_language_chosen';

  private static prefs: preferences.Preferences | null = null;
  private static current: LangCode = 'en';

  static async init(context: common.Context): Promise<void> {
    // Ensure the shared version key exists before any page reads it.
    const v0: number | undefined = AppStorage.get<number>(KEY_VERSION);
    if (v0 === undefined) {
      AppStorage.setOrCreate<number>(KEY_VERSION, 0);
    }

    if (LanguageManager.prefs !== null) return;
    LanguageManager.prefs = await preferences.getPreferences(
      context, LanguageManager.STORE_NAME
    );

    const saved = await LanguageManager.prefs.get(
      LanguageManager.KEY_LANG, 'en'
    );
    const code: string = typeof saved === 'string' ? saved : 'en';
    LanguageManager.current = code as LangCode;

    setRuntimeLanguage(LanguageManager.current);
    await LanguageManager.applyToSystem(LanguageManager.current);
    Logger.info(TAG, `Language set to ${LanguageManager.current}`);
  }

  static get(): LangCode {
    return LanguageManager.current;
  }

  static async hasChosen(): Promise<boolean> {
    if (LanguageManager.prefs === null) return false;
    const chosen = await LanguageManager.prefs.get(
      LanguageManager.KEY_CHOSEN, false
    );
    return typeof chosen === 'boolean' ? chosen : false;
  }

  static async set(code: LangCode): Promise<void> {
    LanguageManager.current = code;
    setRuntimeLanguage(code);
    await LanguageManager.applyToSystem(code);

    if (LanguageManager.prefs !== null) {
      await LanguageManager.prefs.put(LanguageManager.KEY_LANG, code);
      await LanguageManager.prefs.put(LanguageManager.KEY_CHOSEN, true);
      await LanguageManager.prefs.flush();
    }

    // Bump the shared version so every subscribed page rebuilds.
    const current: number = AppStorage.get<number>(KEY_VERSION) ?? 0;
    AppStorage.setOrCreate<number>(KEY_VERSION, current + 1);

    Logger.info(TAG, `Language changed to ${code}`);
  }

  private static async applyToSystem(code: LangCode): Promise<void> {
    try {
      await i18n.System.setAppPreferredLanguage(code);
      Logger.info(TAG, `Applied language ${code} to system.`);
    } catch (e) {
      const err: Error = e as Error;
      Logger.warn(TAG, `setAppPreferredLanguage failed: ${err.message}`);
    }
  }
}
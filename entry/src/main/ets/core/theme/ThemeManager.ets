import { preferences } from '@kit.ArkData';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { ThemeMode } from './ThemeMode';
import { ThemeColors, LIGHT_THEME, DARK_THEME } from './ThemeColors';
import { Logger } from '../../utils/Logger';

const TAG: string = 'ThemeManager';

type Listener = () => void;

/**
 * Global theme state.
 *
 * Responsibilities:
 *   - Persist the user's choice (Light / Dark / System)
 *   - Apply it to the app via applicationContext.setColorMode
 *   - Expose the correct ThemeColors object to the UI
 *   - Notify subscribers whenever the effective theme changes
 */
export class ThemeManager {
  private static instance: ThemeManager = new ThemeManager();

  private preference: ThemeMode = ThemeMode.SYSTEM;
  private systemIsDark: boolean = false;
  private currentColors: ThemeColors = LIGHT_THEME;

  private listeners: Listener[] = [];
  private prefs: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;

  private static readonly STORE_NAME = 'cl_drive_settings';
  private static readonly KEY_THEME = 'theme_mode';

  static get(): ThemeManager {
    return ThemeManager.instance;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /**
   * Called from EntryAbility.onWindowStageCreate once the context is available.
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;

    // Read system color mode from the initial configuration.
    // `colorMode` is optional in the SDK type, so treat undefined as light.
    const sysColorMode: ConfigurationConstant.ColorMode | undefined =
      context.config.colorMode;
    this.systemIsDark =
      sysColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;

    // Load the persisted preference.
    try {
      this.prefs = await preferences.getPreferences(context, ThemeManager.STORE_NAME);
      const raw = await this.prefs.get(ThemeManager.KEY_THEME, ThemeMode.SYSTEM as string);
      const saved: string = typeof raw === 'string' ? raw : ThemeMode.SYSTEM;
      this.preference = ThemeManager.parseMode(saved);
    } catch (e) {
      const err: Error = e as Error;
      Logger.warn(TAG, `Failed to load preference: ${err.message}`);
      this.preference = ThemeMode.SYSTEM;
    }

    await this.applyToSystem();
    this.refreshColors();
    Logger.info(TAG, `ThemeManager initialised (mode=${this.preference}, systemDark=${this.systemIsDark})`);
  }

  private static parseMode(s: string): ThemeMode {
    if (s === ThemeMode.LIGHT) return ThemeMode.LIGHT;
    if (s === ThemeMode.DARK) return ThemeMode.DARK;
    return ThemeMode.SYSTEM;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  getPreference(): ThemeMode {
    return this.preference;
  }

  colors(): ThemeColors {
    return this.currentColors;
  }

  isDark(): boolean {
    return this.currentColors.isDark;
  }

  async setPreference(mode: ThemeMode): Promise<void> {
    this.preference = mode;

    if (this.prefs !== null) {
      try {
        await this.prefs.put(ThemeManager.KEY_THEME, mode as string);
        await this.prefs.flush();
      } catch (e) {
        const err: Error = e as Error;
        Logger.warn(TAG, `Failed to save preference: ${err.message}`);
      }
    }

    await this.applyToSystem();
    this.refreshColors();
    this.notify();
    Logger.info(TAG, `Theme set to ${mode}`);
  }

  /**
   * Called from EntryAbility.onConfigurationUpdate when the system theme flips.
   * Accepts `undefined` because `Configuration.colorMode` is optional in the
   * ArkTS type definitions.
   */
  onSystemColorModeChanged(
    newMode: ConfigurationConstant.ColorMode | undefined
  ): void {
    if (newMode === undefined) return;

    const wasDark: boolean = this.systemIsDark;
    this.systemIsDark =
      newMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;

    if (wasDark !== this.systemIsDark) {
      this.refreshColors();
      this.notify();
      Logger.info(TAG, `System dark mode: ${this.systemIsDark}`);
    }
  }

  // ---------------------------------------------------------------------------
  // Subscription
  // ---------------------------------------------------------------------------

  subscribe(listener: Listener): void {
    this.listeners.push(listener);
  }

  unsubscribe(listener: Listener): void {
    const idx = this.listeners.indexOf(listener);
    if (idx >= 0) {
      const next = this.listeners.slice();
      next.splice(idx, 1);
      this.listeners = next;
    }
  }

  private notify(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i]();
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  private async applyToSystem(): Promise<void> {
    if (this.context === null) return;
    try {
      let mode: ConfigurationConstant.ColorMode;
      if (this.preference === ThemeMode.LIGHT) {
        mode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      } else if (this.preference === ThemeMode.DARK) {
        mode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      } else {
        mode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      }
      this.context.getApplicationContext().setColorMode(mode);
    } catch (e) {
      const err: Error = e as Error;
      Logger.warn(TAG, `setColorMode failed: ${err.message}`);
    }
  }

  private refreshColors(): void {
    let effectiveDark: boolean;
    if (this.preference === ThemeMode.LIGHT) {
      effectiveDark = false;
    } else if (this.preference === ThemeMode.DARK) {
      effectiveDark = true;
    } else {
      effectiveDark = this.systemIsDark;
    }
    // Only allocate a new object when the mode actually changes, so the
    // @State reference comparison in ArkUI reliably detects the change.
    if (this.currentColors.isDark !== effectiveDark) {
      this.currentColors = effectiveDark ? DARK_THEME : LIGHT_THEME;
    }
  }
}
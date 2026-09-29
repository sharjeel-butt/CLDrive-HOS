import { AbilityConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AuthManager } from '../core/auth/AuthManager';
import { AccountStore } from '../core/auth/AccountStore';
import { ThemeManager } from '../core/theme/ThemeManager';
import { UiPrefs } from '../core/settings/UiPrefs';
import { Routes } from '../utils/RouteConstants';
import { Logger } from '../utils/Logger';
import { OfflineStore } from '../core/services/OfflineStore';
import { OperationStore } from '../core/services/OperationStore';
import { OperationTracker } from '../core/services/OperationTracker';

const TAG: string = 'EntryAbility';

export default class EntryAbility extends UIAbility {

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Logger.info(TAG, 'onCreate');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    Logger.info(TAG, 'onWindowStageCreate');

    // Initialise persistent stores.
    await AccountStore.init(this.context);

    // Initialise theme (loads persisted choice + applies to system).
    await ThemeManager.get().init(this.context);

    await UiPrefs.init(this.context);

    await OfflineStore.init(this.context);
    await OperationStore.init(this.context);
    await OperationTracker.get().loadPersisted();

    // Decide entry page.
    let target: string = Routes.ONBOARDING;
    try {
      const hasAccounts: boolean = await AuthManager.hasAccounts();
      target = hasAccounts ? Routes.FILE_BROWSER : Routes.ONBOARDING;
    } catch (e) {
      const err: Error = e as Error;
      Logger.error(TAG, `Auth check failed: ${err.message}`);
    }

    Logger.info(TAG, `Loading entry page: ${target}`);

    windowStage.loadContent(target)
      .then(() => {
        Logger.info(TAG, `Loaded ${target}`);
      })
      .catch((e: Error) => {
        Logger.error(TAG, `loadContent failed: ${e.message}`);
      });
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    Logger.info(TAG, `onConfigurationUpdate colorMode=${newConfig.colorMode}`);
    ThemeManager.get().onSystemColorModeChanged(newConfig.colorMode);
  }

  onDestroy(): void {
    Logger.info(TAG, 'onDestroy');
  }

  onForeground(): void {
    Logger.info(TAG, 'onForeground');
  }

  onBackground(): void {
    Logger.info(TAG, 'onBackground');
  }
}
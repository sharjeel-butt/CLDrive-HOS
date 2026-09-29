import { uiMaterial } from '@kit.ArkUI';
import { Logger } from '../../utils/Logger';

const TAG: string = 'MaterialHelper';

/**
 * HarmonyOS 7 immersive material factory.
 *
 * Adapts material style to device capability. Call once at startup
 * or lazily — the level is stable for the device lifetime.
 */
export class MaterialHelper {
  private static cachedLevel: uiMaterial.MaterialLevel | null = null;
  private static supported: boolean | null = null;

  /**
   * Returns true if the device supports immersive materials.
   * Cached after first call.
   */
  static isSupported(): boolean {
    if (MaterialHelper.supported === null) {
      try {
        MaterialHelper.supported = uiMaterial.isImmersiveMaterialSupported();
      } catch (e) {
        const err: Error = e as Error;
        Logger.warn(TAG, `isImmersiveMaterialSupported failed: ${err.message}`);
        MaterialHelper.supported = false;
      }
      Logger.info(TAG, `Immersive material supported: ${MaterialHelper.supported}`);
    }
    return MaterialHelper.supported;
  }

  /**
   * Returns the device's global material level.
   * EXQUISITE = high-end, GENTLE = mid-range, SMOOTH = low-end.
   */
  static getLevel(): uiMaterial.MaterialLevel {
    if (MaterialHelper.cachedLevel === null) {
      try {
        MaterialHelper.cachedLevel = uiMaterial.getGlobalMaterialLevel();
      } catch (e) {
        const err: Error = e as Error;
        Logger.warn(TAG, `getGlobalMaterialLevel failed: ${err.message}`);
        MaterialHelper.cachedLevel = uiMaterial.MaterialLevel.SMOOTH;
      }
      Logger.info(TAG, `Global material level: ${MaterialHelper.cachedLevel}`);
    }
    return MaterialHelper.cachedLevel;
  }

  /**
   * Material for floating navigation surfaces (bottom bar, sidebar).
   * Uses a thinner style so content behind remains legible.
   */
  static navigationMaterial(): uiMaterial.ImmersiveMaterial {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      lightEffect: { color: undefined },
      colorInvert: true
    });
  }

  /**
   * Material for modal surfaces (dialogs, action sheets, panels).
   * Thicker and more prominent — these float above everything.
   */
  static modalMaterial(): uiMaterial.ImmersiveMaterial {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      interactive: true,
      lightEffect: { color: undefined },
      colorInvert: true,
      applyShadow: true
    });
  }

  /**
   * Material for subtle background layers (sidebar backdrop).
   * Thinner than navigation to avoid competing with foreground elements.
   */
  static surfaceMaterial(): uiMaterial.ImmersiveMaterial {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
      interactive: false,
      colorInvert: true
    });
  }

  /**
   * Returns a safe fallback material on unsupported devices.
   * Returns undefined so callers can skip .systemMaterial() entirely.
   */
  static safeMaterial(type: 'nav' | 'modal' | 'surface'): uiMaterial.ImmersiveMaterial | undefined {
    if (!MaterialHelper.isSupported()) {
      return undefined;
    }
    if (type === 'nav') return MaterialHelper.navigationMaterial();
    if (type === 'modal') return MaterialHelper.modalMaterial();
    return MaterialHelper.surfaceMaterial();
  }
}
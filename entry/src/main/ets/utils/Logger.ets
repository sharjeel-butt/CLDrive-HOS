import { hilog } from '@kit.PerformanceAnalysisKit';

export class Logger {
  private static readonly DOMAIN = 0x0001;

  static info(tag: string, msg: string): void {
    hilog.info(Logger.DOMAIN, tag, '%{public}s', msg);
  }

  static warn(tag: string, msg: string): void {
    hilog.warn(Logger.DOMAIN, tag, '%{public}s', msg);
  }

  static error(tag: string, msg: string): void {
    hilog.error(Logger.DOMAIN, tag, '%{public}s', msg);
  }
}
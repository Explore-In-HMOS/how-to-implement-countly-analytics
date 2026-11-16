import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { Countly, CountlyConfig, LogLevel as CountlyLogLevel } from 'countly-sdk-hos';
import { Constants } from '../common/Constants';
import { LogEntry, Logger, LogLevel } from '../common/Logger';

export enum SdkState {
  NOT_STARTED = 'NOT_STARTED',
  INITIALIZING = 'INITIALIZING',
  READY = 'READY',
  FAILED = 'FAILED'
}

/**
 * Keeps the SDK state and the SDK log lines for the page. The SDK starts in
 * AbilityStage, before the page exists, so the page reads this store.
 */
export class CountlyMonitor {
  static state: SdkState = SdkState.NOT_STARTED;
  static serverUrl: string = '';
  static offlineByConfig: boolean = false;
  private static entries: LogEntry[] = [];
  private static listener?: () => void;

  static log(message: string, level: LogLevel = LogLevel.INFO): void {
    CountlyMonitor.entries = [Logger.log(message, level), ...CountlyMonitor.entries].slice(0, Constants.LOG_LIMIT);
    CountlyMonitor.listener?.();
  }

  static logs(): LogEntry[] {
    return CountlyMonitor.entries;
  }

  static setListener(listener: (() => void) | undefined): void {
    CountlyMonitor.listener = listener;
  }

  static setState(state: SdkState): void {
    CountlyMonitor.state = state;
    CountlyMonitor.listener?.();
  }
}

/** The SDK log listener: SDK lines go to the on-screen log (and to hilog through Logger). */
function onSdkLog(message: string, level: CountlyLogLevel): void {
  let mapped = LogLevel.INFO;
  if (level === CountlyLogLevel.ERROR) {
    mapped = LogLevel.ERROR;
  } else if (level === CountlyLogLevel.WARNING) {
    mapped = LogLevel.WARN;
  }
  CountlyMonitor.log(message, mapped);
}

interface CountlyFileConfig {
  serverUrl?: string;
  appKey?: string;
}

/**
 * Starts the shared Countly instance. Call it from AbilityStage.onCreate:
 * it runs before any UIAbility, so the SDK sees the first foreground change
 * and records the first session and view of a cold start.
 */
export function startCountly(context: common.Context): void {
  let serverUrl = '';
  let appKey = '';
  try {
    const bytes = context.resourceManager.getRawFileContentSync(Constants.CONFIG_FILE);
    const json = JSON.parse(util.TextDecoder.create('utf-8').decodeToString(bytes)) as CountlyFileConfig;
    serverUrl = typeof json.serverUrl === 'string' ? json.serverUrl as string.trim() : '';
    appKey = typeof json.appKey === 'string' ? json.appKey.trim() : '';
  } catch (err) {
    CountlyMonitor.log(`countly.json could not be read: ${JSON.stringify(err)}`, LogLevel.ERROR);
  }

  const offline = serverUrl.length === 0 || appKey.length === 0;
  CountlyMonitor.offlineByConfig = offline;
  CountlyMonitor.serverUrl = offline ? '' : serverUrl;

  const config = new CountlyConfig(context, offline ? Constants.PLACEHOLDER_SERVER : serverUrl,
    offline ? Constants.PLACEHOLDER_APP_KEY : appKey);
  config.setAppVersion('1.0.0');
  config.logging
    .enableLogging()
    .setMinLevel(CountlyLogLevel.DEBUG)
    .setListener(onSdkLog);
  // Automatic session tracking is on by default; update the duration every 60 s.
  config.sessions.setUpdateIntervalSec(Constants.SESSION_UPDATE_S);
  // Automatic view tracking: the SDK records a view for each ability that comes to the foreground.
  config.views.enableAutomaticViewTracking();
  config.events.setQueueSizeToSend(Constants.EVENT_QUEUE_THRESHOLD);
  if (offline) {
    // No server: keep every request in the persistent queue.
    config.network.enableOfflineMode();
  }

  CountlyMonitor.setState(SdkState.INITIALIZING);
  CountlyMonitor.log(`AbilityStage: Countly.initShared(${offline ? 'offline mode' : serverUrl})`);
  // onCreate is synchronous: start the async init and do not wait for it.
  Countly.initShared(config)
    .then(() => {
      CountlyMonitor.setState(SdkState.READY);
      CountlyMonitor.log('Countly SDK ready');
    })
    .catch((err: Error) => {
      CountlyMonitor.setState(SdkState.FAILED);
      CountlyMonitor.log(`Countly init failed: ${err.message}`, LogLevel.ERROR);
    });
}

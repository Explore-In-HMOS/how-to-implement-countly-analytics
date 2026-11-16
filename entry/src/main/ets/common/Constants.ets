export class Constants {
  static readonly CONFIG_FILE: string = 'countly.json';
  // Used only in offline mode (no server in countly.json): the SDK never contacts it.
  static readonly PLACEHOLDER_SERVER: string = '';
  static readonly PLACEHOLDER_APP_KEY: string = 'DEMO_APP_KEY';

  // The SDK sends the event queue when it has this many events.
  static readonly EVENT_QUEUE_THRESHOLD: number = 10;
  // Session update interval while the app is in the foreground.
  static readonly SESSION_UPDATE_S: number = 60;

  static readonly STATUS_REFRESH_MS: number = 1000;
  static readonly LOG_LIMIT: number = 30;
  static readonly LOG_DOMAIN: number = 0x0001;
  static readonly LOG_TAG: string = 'CountlyWatch';
}

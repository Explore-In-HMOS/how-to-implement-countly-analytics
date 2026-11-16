import { connection } from '@kit.NetworkKit';
import { Countly, CountlyInstance, SegmentationMap } from 'countly-sdk-hos';
import { Constants } from '../common/Constants';
import { LogEntry, LogLevel } from '../common/Logger';
import { CountlyMonitor, SdkState } from '../countly/CountlySetup';

@Entry
@Component
struct Index {
  @State sdkState: SdkState = CountlyMonitor.state;
  @State online: boolean = false;
  @State offlineMode: boolean = CountlyMonitor.offlineByConfig;
  @State queuedRequests: number = 0;
  @State pendingEvents: boolean = false;
  @State logs: LogEntry[] = [];

  private tickerId: number = -1;

  aboutToAppear(): void {
    CountlyMonitor.setListener(() => this.refresh());
    this.refresh();
  }

  aboutToDisappear(): void {
    CountlyMonitor.setListener(undefined);
  }

  onPageShow(): void {
    this.tickerId = setInterval(() => this.refresh(), Constants.STATUS_REFRESH_MS);
  }

  onPageHide(): void {
    if (this.tickerId !== -1) {
      clearInterval(this.tickerId);
      this.tickerId = -1;
    }
  }

  /** The shared instance, or undefined while the async init has not finished. */
  private countly(): CountlyInstance | undefined {
    return CountlyMonitor.state === SdkState.READY ? Countly.sharedInstance() : undefined;
  }

  private run(action: string, task: (instance: CountlyInstance) => Promise<void>): void {
    const instance = this.countly();
    if (instance === undefined) {
      CountlyMonitor.log(`${action}: the SDK is not ready (${CountlyMonitor.state})`, LogLevel.WARN);
      return;
    }
    task(instance)
      .then(() => this.refresh())
      .catch((err: Error) => CountlyMonitor.log(`${action} failed: ${err.message}`, LogLevel.ERROR));
  }

  private recordTap(): void {
    this.run('Tap Event', (instance: CountlyInstance) => instance.events.recordEvent('tap_event'));
  }

  private recordSum(): void {
    this.run('Sum Event', (instance: CountlyInstance) => instance.events.recordEvent('purchase', null, 1, 9.99));
  }

  private recordSegmented(): void {
    const segmentation: SegmentationMap = { 'color': 'red' };
    this.run('Segmented Event', (instance: CountlyInstance) =>
      instance.events.recordEvent('theme_change', segmentation));
  }

  private flushNow(): void {
    this.run('Flush Now', async (instance: CountlyInstance) => {
      // Move the event queue into the request queue, then send the request queue.
      await instance.flushEvents();
      await instance.requests.flushQueues();
    });
  }

  private setOfflineMode(isOn: boolean): void {
    this.run('Offline mode', async (instance: CountlyInstance) => {
      if (isOn) {
        instance.requests.enableOfflineMode();
      } else {
        await instance.requests.disableOfflineMode();
      }
      this.offlineMode = isOn;
      CountlyMonitor.log(`Offline mode ${isOn ? 'ON: requests stay in the queue' : 'OFF: the queue is sent'}`);
    });
  }

  private refresh(): void {
    this.sdkState = CountlyMonitor.state;
    this.logs = CountlyMonitor.logs();
    try {
      this.online = connection.hasDefaultNetSync();
    } catch (err) {
      this.online = false;
    }
    const instance = this.countly();
    if (instance !== undefined) {
      this.queuedRequests = instance.requestQueue.size();
      this.pendingEvents = instance.hasPendingEvents();
    }
  }

  private stateColor(): ResourceColor {
    switch (this.sdkState) {
      case SdkState.READY:
        return $r('app.color.success');
      case SdkState.FAILED:
        return $r('app.color.error');
      default:
        return $r('app.color.warning');
    }
  }

  private logColor(level: LogLevel): ResourceColor {
    switch (level) {
      case LogLevel.ERROR:
        return $r('app.color.error');
      case LogLevel.WARN:
        return $r('app.color.warning');
      default:
        return '#AEAEB2';
    }
  }

  @Builder
  actionButton(label: Resource, color: ResourceColor, onTap: () => void) {
    Button(label)
      .width('70%')
      .height(38)
      .fontSize(14)
      .backgroundColor(color)
      .enabled(this.sdkState === SdkState.READY)
      .onClick(onTap)
  }

  build() {
    Scroll() {
      Column({ space: 6 }) {
        Row({ space: 6 }) {
          Text('Countly')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
          Circle()
            .width(10)
            .height(10)
            .fill(this.stateColor())
          Text(this.sdkState)
            .fontSize(11)
            .fontColor(this.stateColor())
        }
        Text(this.offlineMode ? 'Offline mode' : CountlyMonitor.serverUrl)
          .width('76%')
          .fontSize(11)
          .fontColor(this.offlineMode ? $r('app.color.warning') : $r('app.color.neutral'))
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`Network: ${this.online ? 'online' : 'offline'}`)
          .fontSize(12)
          .fontColor(this.online ? $r('app.color.success') : $r('app.color.warning'))
        Text(`Request queue: ${this.queuedRequests}`)
          .fontSize(14)
          .fontColor(Color.White)
        Text(this.pendingEvents ? 'Events waiting in the event queue' : 'Event queue empty')
          .fontSize(12)
          .fontColor('#C7C7CC')

        this.actionButton($r('app.string.btn_tap'), $r('app.color.accent'), () => this.recordTap())
        this.actionButton($r('app.string.btn_sum'), $r('app.color.accent'), () => this.recordSum())
        this.actionButton($r('app.string.btn_segmented'), $r('app.color.accent'), () => this.recordSegmented())
        this.actionButton($r('app.string.btn_flush'), $r('app.color.card'), () => this.flushNow())

        if (CountlyMonitor.offlineByConfig) {
          Text($r('app.string.no_server'))
            .width('76%')
            .fontSize(11)
            .fontColor($r('app.color.warning'))
            .textAlign(TextAlign.Center)
        } else {
          Row() {
            Text($r('app.string.offline_mode'))
              .fontSize(14)
              .fontColor(Color.White)
              .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.offlineMode })
              .selectedColor($r('app.color.warning'))
              .enabled(this.sdkState === SdkState.READY)
              .onChange((isOn: boolean) => this.setOfflineMode(isOn))
          }
          .width('78%')
          .height(40)
        }

        Text($r('app.string.event_log'))
          .fontSize(13)
          .fontColor($r('app.color.neutral'))
          .margin({ top: 6 })
        ForEach(this.logs, (entry: LogEntry) => {
          Text(`${entry.time}  ${entry.message}`)
            .width('76%')
            .fontSize(10)
            .fontColor(this.logColor(entry.level))
        }, (entry: LogEntry) => entry.id.toString())
      }
      .width('100%')
      .padding({ top: 40, bottom: 56 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(Color.Black)
  }
}

import { AbilityStage } from '@kit.AbilityKit';
import { startCountly } from '../countly/CountlySetup';

/**
 * AbilityStage.onCreate runs one time per module process, before any
 * UIAbility is created. module.json5 points to this file with "srcEntry".
 */
export default class MyAbilityStage extends AbilityStage {
  onCreate(): void {
    startCountly(this.context);
  }
}

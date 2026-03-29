import UIAbility from '@ohos.app.ability.UIAbility'
import hilog from '@ohos.hilog'
import window from '@ohos.window'
import type { BusinessError } from '@ohos.base'

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate')
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate')

    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '')
        return
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.')
    })
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy')
  }

  onForeground(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground')
  }

  onBackground(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground')
  }
}

import { OCRUtils, OCRResult, ShoeLabelInfo } from '../utils/OCRUtils'
import { PhotoViewPicker, PhotoSelectOptions, PhotoViewMIMETypes } from '@kit.FilePickerKit'
import { fileIo } from '@kit.CoreFileKit'
import prompt from '@ohos.prompt'
import { Context } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { util } from '@kit.ArkTS'

interface LabelData {
  id: number
  imageUri: string
  brand: string
  model: string
  size: string
  rawText: string
  status: number
}

interface PhotoSelectResult {
  photoUris: string[]
  isOriginalPhoto: boolean
}

const STATUS_PENDING: number = 0
const STATUS_RECOGNIZING: number = 1
const STATUS_SUCCESS: number = 2
const STATUS_FAILED: number = 3

@Entry
@Component
struct Index {
  @State labelList: LabelData[] = []
  @State isRecognizing: boolean = false
  @State progressValue: number = 0
  @State selectedCount: number = 0
  private scroller: Scroller = new Scroller()
  private context: Context = getContext(this) as Context

  async selectImages(): Promise<void> {
    try {
      const options: PhotoSelectOptions = {
        maxSelectNumber: 50,
        MIMEType: PhotoViewMIMETypes.IMAGE_TYPE
      }
      const picker: PhotoViewPicker = new PhotoViewPicker()
      const result: PhotoSelectResult = await picker.select(options)

      if (result.photoUris.length > 0) {
        const newLabels: LabelData[] = result.photoUris.map((uri: string, index: number): LabelData => ({
          id: this.labelList.length + index,
          imageUri: uri,
          brand: '',
          model: '',
          size: '',
          rawText: '',
          status: STATUS_PENDING
        }))

        this.labelList = this.labelList.concat(newLabels)
        this.selectedCount = this.labelList.length

        prompt.showToast({
          message: `已选择 ${result.photoUris.length} 张图片`,
          duration: 2000
        })
      }
    } catch (err) {
      const error: BusinessError = err as BusinessError
      console.error('选择图片失败:', JSON.stringify(error))
      prompt.showToast({
        message: '选择图片失败',
        duration: 2000
      })
    }
  }

  async startRecognize(): Promise<void> {
    if (this.labelList.length === 0) {
      prompt.showToast({
        message: '请先选择图片',
        duration: 2000
      })
      return
    }

    this.isRecognizing = true
    const pendingList: LabelData[] = this.labelList.filter((item: LabelData): boolean => item.status === STATUS_PENDING)

    for (let i: number = 0; i < pendingList.length; i++) {
      const item: LabelData = pendingList[i]
      this.progressValue = Math.round(((i + 1) / pendingList.length) * 100)
      this.updateItemStatus(item.id, STATUS_RECOGNIZING)

      try {
        const ocrResults: OCRResult[] = await OCRUtils.recognizeText(item.imageUri)
        const info: Partial<ShoeLabelInfo> = OCRUtils.extractLabelInfo(ocrResults)

        this.updateItemInfo(item.id, {
          brand: info.brand ?? '',
          model: info.model ?? '',
          size: info.size ?? '',
          rawText: info.rawText ?? '',
          status: STATUS_SUCCESS
        })
      } catch (err) {
        const error: BusinessError = err as BusinessError
        console.error('识别失败:', JSON.stringify(error))
        this.updateItemStatus(item.id, STATUS_FAILED)
      }
    }

    this.isRecognizing = false
    this.progressValue = 0

    prompt.showToast({
      message: '识别完成',
      duration: 2000
    })
  }

  updateItemStatus(id: number, status: number): void {
    const index: number = this.labelList.findIndex((item: LabelData): boolean => item.id === id)
    if (index !== -1) {
      const item: LabelData = this.labelList[index]
      item.status = status
      this.labelList.splice(index, 1, item)
    }
  }

  updateItemInfo(id: number, info: Partial<LabelData>): void {
    const index: number = this.labelList.findIndex((item: LabelData): boolean => item.id === id)
    if (index !== -1) {
      const item: LabelData = this.labelList[index]
      if (info.brand !== undefined) item.brand = info.brand
      if (info.model !== undefined) item.model = info.model
      if (info.size !== undefined) item.size = info.size
      if (info.rawText !== undefined) item.rawText = info.rawText
      if (info.status !== undefined) item.status = info.status
      this.labelList.splice(index, 1, item)
    }
  }

  deleteItem(id: number): void {
    const index: number = this.labelList.findIndex((item: LabelData): boolean => item.id === id)
    if (index !== -1) {
      this.labelList.splice(index, 1)
    }
    this.selectedCount = this.labelList.length
  }

  clearAll(): void {
    if (this.labelList.length === 0) return

    this.labelList = []
    this.selectedCount = 0
    prompt.showToast({
      message: '已清空',
      duration: 2000
    })
  }

  async exportCSV(): Promise<void> {
    const successList: LabelData[] = this.labelList.filter((item: LabelData): boolean => item.status === STATUS_SUCCESS)
    if (successList.length === 0) {
      prompt.showToast({
        message: '没有可导出的数据',
        duration: 2000
      })
      return
    }

    try {
      const csvContent: string = OCRUtils.generateCSV(successList)
      const fileName: string = `攀岩鞋标签_${OCRUtils.getTimestamp()}.csv`

      const filesDir: string = this.context.filesDir
      const filePath: string = `${filesDir}/${fileName}`

      const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
      const encoder: util.TextEncoder = new util.TextEncoder()
      const buf: Uint8Array = encoder.encodeInto(csvContent)
      fileIo.writeSync(file.fd, buf.buffer)
      fileIo.closeSync(file)

      prompt.showToast({
        message: `CSV已保存: ${fileName}`,
        duration: 3000
      })

    } catch (err) {
      const error: BusinessError = err as BusinessError
      console.error('导出失败:', JSON.stringify(error))
      prompt.showToast({
        message: '导出失败',
        duration: 2000
      })
    }
  }

  getStatusText(status: number): string {
    switch (status) {
      case STATUS_PENDING: return '待识别'
      case STATUS_RECOGNIZING: return '识别中...'
      case STATUS_SUCCESS: return '识别成功'
      case STATUS_FAILED: return '识别失败'
      default: return ''
    }
  }

  getStatusColor(status: number): ResourceColor {
    switch (status) {
      case STATUS_PENDING: return '#999999'
      case STATUS_RECOGNIZING: return '#2196F3'
      case STATUS_SUCCESS: return '#4CAF50'
      case STATUS_FAILED: return '#F44336'
      default: return '#999999'
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('攀岩鞋标签识别')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        if (this.selectedCount > 0) {
          Text(`(${this.selectedCount})`)
            .fontSize(16)
            .fontColor($r('app.color.primary_color'))
            .margin({ left: 8 })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(16)
      .backgroundColor($r('app.color.card_background'))

      // 按钮区域
      Row({ space: 12 }) {
        Button('选择图片')
          .fontSize(14)
          .fontColor(Color.White)
          .type(ButtonType.Capsule)
          .backgroundColor($r('app.color.primary_color'))
          .enabled(!this.isRecognizing)
          .onClick(() => {
            this.selectImages().catch((err: Error) => {
              console.error('选择图片出错:', err.message)
            })
          })

        Button('开始识别')
          .fontSize(14)
          .fontColor(Color.White)
          .type(ButtonType.Capsule)
          .backgroundColor('#4CAF50')
          .enabled(!this.isRecognizing && this.labelList.length > 0)
          .onClick(() => {
            this.startRecognize().catch((err: Error) => {
              console.error('识别出错:', err.message)
            })
          })

        Button('导出CSV')
          .fontSize(14)
          .fontColor(Color.White)
          .type(ButtonType.Capsule)
          .backgroundColor('#FF9800')
          .enabled(!this.isRecognizing)
          .onClick(() => {
            this.exportCSV().catch((err: Error) => {
              console.error('导出出错:', err.message)
            })
          })

        Button('清空')
          .fontSize(14)
          .fontColor(Color.White)
          .type(ButtonType.Capsule)
          .backgroundColor('#F44336')
          .enabled(!this.isRecognizing)
          .onClick(() => this.clearAll())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(12)
      .backgroundColor($r('app.color.card_background'))

      // 进度条
      if (this.isRecognizing) {
        Row() {
          Progress({ value: this.progressValue, total: 100, type: ProgressType.Linear })
            .width('80%')
            .color($r('app.color.primary_color'))
          Text(`${this.progressValue}%`)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 8 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding(8)
        .backgroundColor($r('app.color.card_background'))
      }

      // 列表区域
      if (this.labelList.length === 0) {
        Column() {
          Text('📷')
            .fontSize(80)
            .opacity(0.5)
          Text('暂无数据，请先选择图片')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 16 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ scroller: this.scroller }) {
          ForEach(this.labelList, (item: LabelData) => {
            ListItem() {
              this.LabelCard(item)
            }
          }, (item: LabelData) => item.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .padding(12)
        .backgroundColor($r('app.color.background_color'))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_color'))
  }

  @Builder
  LabelCard(item: LabelData) {
    Column() {
      Row() {
        Image(item.imageUri)
          .width(80)
          .height(80)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .margin({ right: 12 })

        Column({ space: 6 }) {
          Row() {
            Text(item.brand || '待识别')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(item.brand ? $r('app.color.text_primary') : '#999999')
              .layoutWeight(1)

            Text(this.getStatusText(item.status))
              .fontSize(12)
              .fontColor(this.getStatusColor(item.status))
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .backgroundColor(this.getStatusColor(item.status) + '20')
              .borderRadius(4)
          }
          .width('100%')

          Row() {
            Text('款式:')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width(40)
            Text(item.model || '--')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
          }
          .width('100%')

          Row() {
            Text('尺码:')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width(40)
            Text(item.size || '--')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button('×')
          .fontSize(20)
          .fontColor('#999999')
          .type(ButtonType.Circle)
          .backgroundColor(Color.Transparent)
          .width(32)
          .height(32)
          .onClick(() => this.deleteItem(item.id))
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ bottom: 8 })
    .shadow({
      radius: 4,
      color: '#00000010',
      offsetX: 0,
      offsetY: 2
    })
  }
}

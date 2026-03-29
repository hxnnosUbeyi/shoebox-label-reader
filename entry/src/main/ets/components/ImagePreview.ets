import { ShoeLabelInfo } from '../utils/OCRUtils'

const STATUS_PENDING = 0
const STATUS_RECOGNIZING = 1
const STATUS_SUCCESS = 2
const STATUS_FAILED = 3

/**
 * 图片预览组件
 * 用于显示鞋盒标签图片和识别结果
 */
@Component
export struct ImagePreview {
  @Prop labelInfo: ShoeLabelInfo
  @State isExpanded: boolean = false

  private getStatusText(status: number): string {
    switch (status) {
      case STATUS_PENDING: return '待识别'
      case STATUS_RECOGNIZING: return '识别中'
      case STATUS_SUCCESS: return '已识别'
      case STATUS_FAILED: return '失败'
      default: return ''
    }
  }

  private getStatusColor(status: number): ResourceColor {
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
      Stack() {
        Image(this.labelInfo.imageUri)
          .width('100%')
          .height(this.isExpanded ? 300 : 150)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)

        Text(this.getStatusText(this.labelInfo.status))
          .fontSize(12)
          .fontColor(Color.White)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.getStatusColor(this.labelInfo.status))
          .borderRadius(4)
          .position({ x: 8, y: 8 })
      }
      .width('100%')
      .onClick(() => {
        this.isExpanded = !this.isExpanded
      })

      Column({ space: 8 }) {
        Row() {
          Text('品牌')
            .fontSize(12)
            .fontColor('#666666')
            .width(50)
          Text(this.labelInfo.brand || '识别中...')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.labelInfo.brand ? '#333333' : '#999999')
            .layoutWeight(1)
        }
        .width('100%')

        Row() {
          Text('款式')
            .fontSize(12)
            .fontColor('#666666')
            .width(50)
          Text(this.labelInfo.model || '识别中...')
            .fontSize(14)
            .fontColor(this.labelInfo.model ? '#333333' : '#999999')
            .layoutWeight(1)
        }
        .width('100%')

        Row() {
          Text('尺码')
            .fontSize(12)
            .fontColor('#666666')
            .width(50)
          Text(this.labelInfo.size || '识别中...')
            .fontSize(14)
            .fontColor(this.labelInfo.size ? '#333333' : '#999999')
            .layoutWeight(1)
        }
        .width('100%')

        if (this.isExpanded && this.labelInfo.rawText.length > 0) {
          Column() {
            Text('识别原文')
              .fontSize(12)
              .fontColor('#666666')
              .width('100%')
              .margin({ bottom: 4 })
            Text(this.labelInfo.rawText)
              .fontSize(12)
              .fontColor('#999999')
              .width('100%')
          }
          .width('100%')
          .padding(8)
          .backgroundColor('#F5F5F5')
          .borderRadius(4)
          .margin({ top: 8 })
        }
      }
      .width('100%')
      .padding(12)
      .backgroundColor(Color.White)
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({
      radius: 4,
      color: '#00000010',
      offsetX: 0,
      offsetY: 2
    })
  }
}

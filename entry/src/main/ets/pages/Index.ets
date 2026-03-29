import { OCRUtils, OCRResult, ShoeLabelInfo, setAppContext, setGridSize, getGridSize } from '../utils/OCRUtils'
import picker from '@ohos.file.picker'
import fs from '@ohos.file.fs'
import prompt from '@ohos.prompt'
import common from '@ohos.app.ability.common'
import { BusinessError } from '@ohos.base'
import { wantAgent } from '@kit.AbilityKit'

/**
 * 标签数据
 */
interface LabelData {
  id: number
  imageUri: string
  brand: string
  model: string
  width: string  // 鞋型：NARROW/WIDE
  size: string
  rawText: string
  status: number
}

/**
 * CSV统计信息
 */
interface CSVStats {
  successCount: number
  imageCount: number
}

/**
 * 网格配置
 */
interface GridConfig {
  label: string
  r: number
  c: number
}

/**
 * 主页面 - 未来主义极简风格
 * 色彩：深空黑 #0A0A0F | 冷银 #C0C0D0 | 冰蓝 #64B5F6
 */
@Entry
@Component
struct Index {
  @State labelList: LabelData[] = []
  @State isRecognizing: boolean = false
  @State progressValue: number = 0
  @State showCSVPreview: boolean = false
  @State csvContent: string = ''
  @State csvFilePath: string = ''
  @State gridRows: number = 1
  @State gridCols: number = 1
  @State showMenu: boolean = false

  // 色彩系统
  private readonly C_BG = '#0A0A0F'
  private readonly C_SURFACE = '#12121A'
  private readonly C_TEXT = '#E8E8F0'
  private readonly C_TEXT_MUTED = '#6B6B80'
  private readonly C_ACCENT = '#64B5F6'
  private readonly C_WIDTH = '#00BCD4'  // 青色-鞋型专用
  private readonly C_SUCCESS = '#81C784'
  private readonly C_ERROR = '#E57373'

  aboutToAppear() {
    setAppContext(getContext(this) as common.UIAbilityContext)
  }

  build() {
    Stack() {
      // 背景层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.C_BG)

      // 主内容
      Column() {
        // 顶部状态栏
        this.StatusBar()

        // 核心内容区
        Stack() {
          if (this.labelList.length === 0) {
            this.EmptyState()
          } else {
            this.ContentList()
          }
        }
        .layoutWeight(1)

        // 底部控制区
        this.ControlPanel()
      }
      .width('100%')
      .height('100%')

      // 侧边菜单
      if (this.showMenu) {
        this.SideMenu()
      }

      // CSV预览
      if (this.showCSVPreview) {
        this.CSVPreviewDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  // ============================================
  // 顶部状态栏
  // ============================================
  @Builder
  StatusBar() {
    Row() {
      // 菜单按钮
      Stack() {
        Text('≡')
          .fontSize(24)
          .fontWeight(200)
          .fontColor(this.C_TEXT)
      }
      .width(48)
      .height(48)
      .backgroundColor('rgba(255,255,255,0.05)')
      .borderRadius(24)
      .onClick(() => {
        this.showMenu = true
      })

      // 中央状态
      Column() {
        if (this.isRecognizing) {
          Column({ space: 4 }) {
            Text(`${this.progressValue}%`)
              .fontSize(36)
              .fontWeight(100)
              .fontColor(this.C_ACCENT)
            // 进度条动画
            Stack({ alignContent: Alignment.Start }) {
              // 背景条
              Row()
                .width(120)
                .height(2)
                .backgroundColor('rgba(100, 181, 246, 0.2)')
              // 进度条
              Row()
                .width(this.progressValue * 1.2)
                .height(2)
                .backgroundColor(this.C_ACCENT)
                .transition(TransitionEffect.OPACITY)
            }
            .width(120)
          }
        } else {
          Text(this.getStatusText())
            .fontSize(13)
            .fontWeight(300)
            .fontColor(this.C_TEXT_MUTED)
        }
      }

      // 统计指示
      Column() {
        Text(`${this.getSuccessCount()}`)
          .fontSize(14)
          .fontWeight(400)
          .fontColor(this.C_SUCCESS)
        Text('已识别')
          .fontSize(9)
          .fontWeight(300)
          .fontColor(this.C_TEXT_MUTED)
      }
      .width(48)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
  }

  // ============================================
  // 空状态
  // ============================================
  @Builder
  EmptyState() {
    Column() {
      // 几何图标
      Column() {
        Circle()
          .width(100)
          .height(100)
          .fill('rgba(100, 181, 246, 0.05)')
          .stroke(this.C_ACCENT)
          .strokeWidth(1)
        
        Text('◆')
          .fontSize(28)
          .fontColor(this.C_ACCENT)
          .position({ x: 36, y: 36 })
      }
      .width(100)
      .height(100)
      .margin({ bottom: 32 })

      Text('选择图片开始识别')
        .fontSize(14)
        .fontWeight(300)
        .fontColor(this.C_TEXT_MUTED)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  // ============================================
  // 内容列表
  // ============================================
  @Builder
  ContentList() {
    List({ space: 1 }) {
      ForEach(this.labelList, (item: LabelData, index: number) => {
        ListItem() {
          this.DataRow(item, index)
        }
      }, (item: LabelData) => item.id.toString() + '-' + item.status)
    }
    .width('100%')
    .height('100%')
    .padding({ top: 4, bottom: 40 })
    .edgeEffect(EdgeEffect.None)
    .scrollBar(BarState.Off)
  }

  @Builder
  DataRow(item: LabelData, index: number) {
    Row() {
      // 序号
      Text(`${index + 1}`)
        .fontSize(12)
        .fontWeight(200)
        .fontColor(this.C_TEXT_MUTED)
        .width(32)

      // 内容（品牌+款式，单行）
      Row() {
        if (item.status === 1) {
          Text('识别中...')
            .fontSize(13)
            .fontColor(this.C_ACCENT)
        } else if (item.status === 2) {
          Text(item.brand || '—')
            .fontSize(13)
            .fontWeight(400)
            .fontColor(this.C_TEXT)
            .maxLines(1)
          
          if (item.model) {
            Text(` ${item.model}`)
              .fontSize(12)
              .fontWeight(300)
              .fontColor(this.C_ACCENT)
              .maxLines(1)
          }
        } else if (item.status === 3) {
          Text('识别失败')
            .fontSize(13)
            .fontColor(this.C_ERROR)
        } else {
          Text('等待识别')
            .fontSize(13)
            .fontColor(this.C_TEXT_MUTED)
        }
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)

      // 右侧：尺码 + 状态（整体左移避免与对勾重合）
      Row({ space: 6 }) {
        // 鞋型 + 尺码（分开显示，样式区分，鞋号对齐）
        if (item.status === 2 && item.size) {
          Row({ space: 6 }) {
            // 鞋型（固定宽度让鞋号对齐）
            Text(item.width || '')
              .fontSize(10)
              .fontWeight(500)
              .fontColor(this.C_WIDTH)
              .maxLines(1)
              .width(48)  // 固定宽度容纳 NARROW/WIDE
            
            // 尺码
            Text(item.size)
              .fontSize(11)
              .fontWeight(300)
              .fontColor(this.C_TEXT_MUTED)
              .maxLines(1)
          }
        }
        
        // 状态指示（缩小避免重叠）
        if (item.status === 1) {
          LoadingProgress()
            .width(12)
            .height(12)
            .color(this.C_ACCENT)
        } else if (item.status === 2) {
          Text('✓')
            .fontSize(10)
            .fontColor(this.C_SUCCESS)
        } else if (item.status === 3) {
          Text('✕')
            .fontSize(10)
            .fontColor(this.C_ERROR)
        } else {
          Text('○')
            .fontSize(9)
            .fontColor(this.C_TEXT_MUTED)
        }
      }
      .width(100)
      .justifyContent(FlexAlign.End)
      .padding({ right: 4 })
    }
    .width('100%')
    .height(40)
    .padding({ left: 12, right: 16 })
    .backgroundColor(index % 2 === 0 ? this.C_BG : this.C_SURFACE)
  }

  // ============================================
  // 底部控制面板
  // ============================================
  @Builder
  ControlPanel() {
    Column() {
      // 网格设置区域
      if (!this.isRecognizing) {
        Column() {
          Text('分割网格')
            .fontSize(11)
            .fontWeight(300)
            .fontColor(this.C_TEXT_MUTED)
            .margin({ bottom: 2 })
          
          Text('高×宽')
            .fontSize(9)
            .fontWeight(300)
            .fontColor('rgba(107, 107, 128, 0.6)')
            .margin({ bottom: 8 })
          
          Row({ space: 8 }) {
            this.GridButton('1×1', 1, 1)
            this.GridButton('1×2', 1, 2)
            this.GridButton('2×1', 2, 1)
            this.GridButton('2×2', 2, 2)
            this.GridButton('3×3', 3, 3)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 16 })
      }

      // 主按钮区域
      Row({ space: 24 }) {
        // 选择图片按钮
        Column() {
          Button() {
            Text('+')
              .fontSize(28)
              .fontWeight(200)
              .fontColor(this.C_BG)
          }
          .width(64)
          .height(64)
          .backgroundColor(this.C_ACCENT)
          .borderRadius(32)
          .enabled(!this.isRecognizing)
          .onClick(() => {
            this.selectImages()
          })
          
          Text('选择图片')
            .fontSize(11)
            .fontWeight(300)
            .fontColor(this.C_TEXT_MUTED)
            .margin({ top: 8 })
        }

        // 开始识别按钮
        Column() {
          Button() {
            Text('▶')
              .fontSize(22)
              .fontWeight(200)
              .fontColor(this.C_BG)
          }
          .width(64)
          .height(64)
          .backgroundColor(this.getPendingCount() > 0 ? this.C_SUCCESS : 'rgba(129, 199, 132, 0.3)')
          .borderRadius(32)
          .enabled(!this.isRecognizing && this.getPendingCount() > 0)
          .onClick(() => {
            this.startRecognition()
          })
          
          Text('开始识别')
            .fontSize(11)
            .fontWeight(300)
            .fontColor(this.getPendingCount() > 0 ? this.C_TEXT_MUTED : 'rgba(107, 107, 128, 0.5)')
            .margin({ top: 8 })
        }

        // 清除未识别按钮
        Column() {
          Button() {
            Text('−')
              .fontSize(26)
              .fontWeight(200)
              .fontColor(this.C_TEXT)
          }
          .width(64)
          .height(64)
          .backgroundColor(this.getPendingCount() > 0 ? 'rgba(229, 115, 115, 0.2)' : 'rgba(229, 115, 115, 0.05)')
          .borderRadius(32)
          .enabled(!this.isRecognizing && this.getPendingCount() > 0)
          .onClick(() => {
            this.clearPendingItems()
          })
          
          Text('清除未识别')
            .fontSize(11)
            .fontWeight(300)
            .fontColor(this.getPendingCount() > 0 ? this.C_TEXT_MUTED : 'rgba(107, 107, 128, 0.5)')
            .margin({ top: 8 })
        }
      }
      .margin({ bottom: 32 })
    }
    .width('100%')
    .padding({ bottom: 24 })
  }

  @Builder
  GridButton(label: string, r: number, c: number) {
    Text(label)
      .fontSize(12)
      .fontWeight(this.gridRows === r && this.gridCols === c ? 400 : 300)
      .fontColor(this.gridRows === r && this.gridCols === c ? this.C_ACCENT : this.C_TEXT_MUTED)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.gridRows === r && this.gridCols === c ? 'rgba(100, 181, 246, 0.15)' : 'rgba(100, 181, 246, 0.05)')
      .borderRadius(4)
      .onClick(() => {
        this.gridRows = r
        this.gridCols = c
        setGridSize(r, c)
      })
  }

  // ============================================
  // 侧边菜单
  // ============================================
  @Builder
  SideMenu() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(10, 10, 15, 0.9)')
        .onClick(() => {
          this.showMenu = false
        })

      Column() {
        Text('MENU')
          .fontSize(11)
          .fontWeight(400)
          .fontColor(this.C_TEXT_MUTED)
          .letterSpacing(4)
          .margin({ top: 64, bottom: 32 })

        this.MenuItem('导出 CSV', this.getSuccessCount() > 0, () => {
          this.showMenu = false
          this.exportCSV()
        })

        this.MenuItem('预览数据', this.getSuccessCount() > 0, () => {
          this.showMenu = false
          this.previewCSVContent()
        })

        this.MenuItem('分享结果', this.getSuccessCount() > 0, () => {
          this.showMenu = false
          this.shareCSV()
        })

        Divider()
          .width(32)
          .height(1)
          .color(this.C_TEXT_MUTED)
          .opacity(0.3)
          .margin({ top: 24, bottom: 24 })

        this.MenuItem('清空全部', this.labelList.length > 0, () => {
          this.showMenu = false
          this.clearAllItems()
        })
      }
      .width('70%')
      .height('100%')
      .backgroundColor(this.C_SURFACE)
      .padding({ left: 24, right: 24 })
      .alignItems(HorizontalAlign.Start)
      .position({ x: 0, y: 0 })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
  }

  @Builder
  MenuItem(text: string, enabled: boolean, onClick: () => void) {
    Row() {
      Text(text)
        .fontSize(15)
        .fontWeight(300)
        .fontColor(enabled ? this.C_TEXT : this.C_TEXT_MUTED)
    }
    .width('100%')
    .height(48)
    .enabled(enabled)
    .onClick(onClick)
  }

  // ============================================
  // CSV预览
  // ============================================
  @Builder
  CSVPreviewDialog() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(10, 10, 15, 0.95)')
        .onClick(() => {
          this.showCSVPreview = false
        })

      Column() {
        Row() {
          Text('CSV 预览')
            .fontSize(18)
            .fontWeight(300)
            .fontColor(this.C_TEXT)

          Text('✕')
            .fontSize(18)
            .fontWeight(200)
            .fontColor(this.C_TEXT_MUTED)
            .onClick(() => {
              this.showCSVPreview = false
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ bottom: 16 })

        Scroll() {
          Text(this.csvContent)
            .fontSize(11)
            .fontWeight(300)
            .fontColor(this.C_TEXT_MUTED)
            .fontFamily('monospace')
            .width('100%')
        }
        .layoutWeight(1)
        .margin({ bottom: 16 })

        Text(`${this.getCSVStats().successCount} 条记录`)
          .fontSize(12)
          .fontWeight(300)
          .fontColor(this.C_ACCENT)
      }
      .width('85%')
      .height('70%')
      .padding(24)
      .backgroundColor(this.C_SURFACE)
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
  }

  // ============================================
  // 业务逻辑
  // ============================================

  private getPendingCount(): number {
    return this.labelList.filter(item => item.status === 0 || item.status === 3).length
  }

  private getSuccessCount(): number {
    return this.labelList.filter(item => item.status === 2).length
  }

  private getStatusText(): string {
    const success = this.getSuccessCount()
    const pending = this.getPendingCount()
    if (success === 0 && pending === 0) return '准备就绪'
    if (pending > 0) return `已识别 ${success} · 待识别 ${pending}`
    return `${success} 条已识别`
  }

  private clearPendingItems() {
    const pendingCount = this.getPendingCount()
    if (pendingCount === 0) return
    this.labelList = this.labelList.filter(item => item.status === 2)
    prompt.showToast({ message: `已清除 ${pendingCount} 个未识别`, duration: 1500 })
  }

  private clearAllItems() {
    this.labelList = []
    prompt.showToast({ message: '已清空全部', duration: 1000 })
  }

  async selectImages() {
    try {
      const photoPicker = new picker.PhotoViewPicker()
      const result = await photoPicker.select({
        maxSelectNumber: 50,
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE
      })
      if (result.photoUris && result.photoUris.length > 0) {
        const newLabels: LabelData[] = result.photoUris.map((uri, index): LabelData => ({
          id: Date.now() + index,
          imageUri: uri,
          brand: '',
          model: '',
          width: '',
          size: '',
          rawText: '',
          status: 0
        }))
        this.labelList = this.labelList.concat(newLabels)
        prompt.showToast({ message: `已添加 ${result.photoUris.length} 张图片`, duration: 1500 })
      }
    } catch (error) {
      prompt.showToast({ message: '选择图片失败', duration: 1500 })
    }
  }

  async startRecognition() {
    if (this.isRecognizing) return
    const pendingItems = this.labelList.filter(item => item.status === 0 || item.status === 3)
    if (pendingItems.length === 0) {
      prompt.showToast({ message: '没有待识别的图片', duration: 1500 })
      return
    }

    this.isRecognizing = true
    this.progressValue = 0
    const total = pendingItems.length
    let completed = 0

    for (const item of pendingItems) {
      console.info(`[识别] 开始处理 item.id=${item.id}`)
      this.updateItemStatus(item.id, 1)
      try {
        const ocrResults = await OCRUtils.recognizeText(item.imageUri)
        console.info(`[识别] OCR完成，共${ocrResults.length}条结果`)
        const labelInfos = OCRUtils.extractLabelInfo(ocrResults)
        console.info(`[识别] 提取到${labelInfos.length}个标签`)
        if (labelInfos.length > 0) {
          console.info(`[识别] 标签0: brand=${labelInfos[0].brand}, model=${labelInfos[0].model}`)
          this.updateItemData(item.id, labelInfos[0], ocrResults)
          this.updateItemStatus(item.id, 2)
          console.info(`[识别] 已更新状态为2`)
          for (let i = 1; i < labelInfos.length; i++) {
            this.addExtraLabelItem(item.imageUri, labelInfos[i])
          }
        } else {
          console.info(`[识别] 未提取到标签，标记为失败`)
          this.updateItemStatus(item.id, 3)
        }
      } catch (error) {
        console.error(`[识别] 异常: ${JSON.stringify(error)}`)
        this.updateItemStatus(item.id, 3)
      }
      completed++
      this.progressValue = Math.floor((completed / total) * 100)
    }

    this.isRecognizing = false
    // 识别完成后排序
    this.sortLabelList()
    prompt.showToast({ message: `识别完成 · ${this.getSuccessCount()} 条记录`, duration: 2000 })
  }

  private addExtraLabelItem(imageUri: string, labelInfo: Partial<ShoeLabelInfo>) {
    const newLabel: LabelData = {
      id: Date.now() + Math.random(),
      imageUri: imageUri,
      brand: labelInfo.brand || '',
      model: labelInfo.model || '',
      width: labelInfo.width || '',
      size: labelInfo.size || '',
      rawText: labelInfo.rawText || '',
      status: 2
    }
    this.labelList = this.labelList.concat([newLabel])
  }

  /**
   * 提取尺码数值用于排序
   */
  private extractSizeValue(size: string): number {
    const match = size.match(/\d+\.?\d*/)
    return match ? parseFloat(match[0]) : 0
  }

  /**
   * 排序标签列表
   * 优先级：品牌首字母 -> 款式首字母 -> 鞋码从小到大
   */
  private sortLabelList() {
    const sortedList = this.labelList.slice().sort((a, b) => {
      // 优先按状态排序（已识别的在前面）
      if (a.status !== b.status) {
        return b.status - a.status
      }
      
      // 1. 按品牌首字母排序
      const brandA = (a.brand || '').toLowerCase()
      const brandB = (b.brand || '').toLowerCase()
      if (brandA !== brandB) {
        return brandA.localeCompare(brandB)
      }
      
      // 2. 按款式首字母排序
      const modelA = (a.model || '').toLowerCase()
      const modelB = (b.model || '').toLowerCase()
      if (modelA !== modelB) {
        return modelA.localeCompare(modelB)
      }
      
      // 3. 按鞋码从小到大排序
      const sizeA = this.extractSizeValue(a.size || '')
      const sizeB = this.extractSizeValue(b.size || '')
      return sizeA - sizeB
    })
    
    this.labelList = sortedList
    console.info(`[sortLabelList] 已排序，共 ${sortedList.length} 条`)
  }

  private updateItemStatus(id: number, status: number) {
    console.info(`[updateItemStatus] id=${id}, status=${status}`)
    const index = this.labelList.findIndex(item => item.id === id)
    console.info(`[updateItemStatus] findIndex result: ${index}`)
    if (index !== -1) {
      // 创建新数组并替换元素，确保触发UI更新
      const newList: LabelData[] = []
      for (let i = 0; i < this.labelList.length; i++) {
        if (i === index) {
          newList.push({
            id: this.labelList[i].id,
            imageUri: this.labelList[i].imageUri,
            brand: this.labelList[i].brand,
            model: this.labelList[i].model,
            width: this.labelList[i].width,
            size: this.labelList[i].size,
            rawText: this.labelList[i].rawText,
            status: status
          })
        } else {
          newList.push(this.labelList[i])
        }
      }
      this.labelList = newList
      console.info(`[updateItemStatus] 已更新，当前列表长度: ${this.labelList.length}`)
    } else {
      console.error(`[updateItemStatus] 未找到id=${id}的item`)
    }
  }

  private updateItemData(id: number, labelInfo: Partial<ShoeLabelInfo>, ocrResults: OCRResult[]) {
    const index = this.labelList.findIndex(item => item.id === id)
    if (index !== -1) {
      // 创建新数组并替换元素，确保触发UI更新
      const newList: LabelData[] = []
      for (let i = 0; i < this.labelList.length; i++) {
        if (i === index) {
          newList.push({
            id: this.labelList[i].id,
            imageUri: this.labelList[i].imageUri,
            brand: labelInfo.brand || this.labelList[i].brand,
            model: labelInfo.model || this.labelList[i].model,
            width: labelInfo.width || this.labelList[i].width,
            size: labelInfo.size || this.labelList[i].size,
            rawText: labelInfo.rawText || this.labelList[i].rawText,
            status: this.labelList[i].status
          })
        } else {
          newList.push(this.labelList[i])
        }
      }
      this.labelList = newList
    }
  }

  async exportCSV() {
    try {
      // 导出前先排序
      this.sortLabelList()
      const successList = this.labelList.filter(item => item.status === 2)
      if (successList.length === 0) {
        prompt.showToast({ message: '没有可导出的数据', duration: 1500 })
        return
      }
      const csv = OCRUtils.generateCSV(successList)
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19)
      const fileName = `攀岩鞋标签_${timestamp}.csv`
      const context = getContext(this) as common.UIAbilityContext
      const cacheDir = context.cacheDir
      const tempFilePath = `${cacheDir}/${fileName}`
      const file = fs.openSync(tempFilePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
      fs.writeSync(file.fd, csv)
      fs.closeSync(file)
      const savedPath = await this.saveWithPicker(csv, fileName)
      this.csvContent = csv
      this.csvFilePath = savedPath || tempFilePath
      this.showCSVPreview = true
    } catch (error) {
      prompt.showToast({ message: '导出失败', duration: 1500 })
    }
  }

  async saveWithPicker(content: string, fileName: string): Promise<string> {
    try {
      const documentPicker = new picker.DocumentViewPicker()
      const result = await documentPicker.save({ newFileNames: [fileName] })
      if (result && result.length > 0) {
        const savePath = result[0]
        const file = fs.openSync(savePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
        fs.writeSync(file.fd, content)
        fs.closeSync(file)
        return savePath
      }
    } catch (error) {
      const err = error as BusinessError
      if (err.code !== 801) {
        console.error('保存失败:', err.message)
      }
    }
    return ''
  }

  async shareCSV() {
    try {
      const successList = this.labelList.filter(item => item.status === 2)
      if (successList.length === 0) return
      const csv = OCRUtils.generateCSV(successList)
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19)
      const fileName = `攀岩鞋标签_${timestamp}.csv`
      const context = getContext(this) as common.UIAbilityContext
      const cachePath = `${context.cacheDir}/${fileName}`
      const file = fs.openSync(cachePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
      fs.writeSync(file.fd, csv)
      fs.closeSync(file)
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [{ action: 'ohos.want.action.sendData', type: 'text/csv', parameters: { 'ability.params.stream': cachePath } }],
        operationType: wantAgent.OperationType.START_ABILITIES,
        requestCode: 0
      }
      const agent = await wantAgent.getWantAgent(wantAgentInfo)
      await wantAgent.trigger(agent, { code: 0 })
    } catch (error) {
      prompt.showToast({ message: '分享失败', duration: 1500 })
    }
  }

  previewCSVContent() {
    // 预览前先排序
    this.sortLabelList()
    const successList = this.labelList.filter(item => item.status === 2)
    if (successList.length === 0) return
    this.csvContent = OCRUtils.generateCSV(successList)
    this.csvFilePath = '—'
    this.showCSVPreview = true
  }

  private getCSVStats(): CSVStats {
    const successList = this.labelList.filter(item => item.status === 2)
    return {
      successCount: successList.length,
      imageCount: new Set(successList.map(item => item.imageUri)).size
    }
  }
}

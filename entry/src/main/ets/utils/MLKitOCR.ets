import { textRecognition } from '@kit.CoreVisionKit'
import image from '@ohos.multimedia.image'
import { BusinessError } from '@ohos.base'

/**
 * OCR 结果项
 */
export interface OCRResult {
  text: string
  confidence: number
  groupId?: number
}

/**
 * ML Kit OCR 实现
 * 使用 HarmonyOS 官方 Core Vision Kit 文字识别能力
 */
export class MLKitOCR {
  
  private static isInitialized: boolean = false

  /**
   * 初始化 OCR
   */
  static async init(): Promise<boolean> {
    if (MLKitOCR.isInitialized) {
      return true
    }
    
    try {
      await textRecognition.init()
      MLKitOCR.isInitialized = true
      console.info('✅ OCR 初始化成功')
      return true
    } catch (error) {
      const e = error as BusinessError
      console.error('❌ OCR 初始化失败:', e.code, e.message)
      return false
    }
  }

  /**
   * 文字识别
   * @param pixelMap 图片
   * @param gridRows 行数
   * @param gridCols 列数
   */
  static async recognizeText(
    pixelMap: image.PixelMap, 
    gridRows: number = 1, 
    gridCols: number = 1
  ): Promise<OCRResult[]> {
    try {
      console.info('>>> 开始 Core Vision Kit 文字识别...')
      
      if (!MLKitOCR.isInitialized) {
        const initialized = await MLKitOCR.init()
        if (!initialized) {
          return []
        }
      }
      
      const imgInfo: image.ImageInfo = await pixelMap.getImageInfo()
      const width: number = imgInfo.size.width
      const height: number = imgInfo.size.height
      console.info(`>>> 图片尺寸: ${width}x${height}`)
      
      // 单图识别
      if (gridRows <= 1 && gridCols <= 1) {
        return await MLKitOCR.doRecognize(pixelMap)
      }
      
      // MxN 网格分割识别
      const allResults: OCRResult[] = []
      const cellWidth = Math.floor(width / gridCols)
      const cellHeight = Math.floor(height / gridRows)
      let groupId = 0
      
      for (let row = 0; row < gridRows; row++) {
        for (let col = 0; col < gridCols; col++) {
          const x = col * cellWidth
          const y = row * cellHeight
          const w = (col === gridCols - 1) ? (width - x) : cellWidth
          const h = (row === gridRows - 1) ? (height - y) : cellHeight
          
          const subPixelMap = await MLKitOCR.cropImage(pixelMap, x, y, w, h)
          if (subPixelMap) {
            const results = await MLKitOCR.doRecognize(subPixelMap)
            
            for (const result of results) {
              result.groupId = groupId
              allResults.push(result)
            }
            
            try {
              subPixelMap.release()
            } catch (e) {
              console.warn('释放子图失败:', e)
            }
          }
          
          groupId++
        }
      }
      
      console.info(`>>> ✅ 分割识别完成，共 ${allResults.length} 条文本`)
      return allResults
      
    } catch (error) {
      const e = error as BusinessError
      console.error('>>> ❌ 文字识别失败:', e.code, e.message)
      return []
    }
  }
  
  /**
   * 原生识别（使用官方方向检测）
   */
  private static async doRecognize(pixelMap: image.PixelMap): Promise<OCRResult[]> {
    const visionInfo: textRecognition.VisionInfo = { pixelMap }
    
    // 官方配置：开启方向检测（自动处理竖排/倒置）
    const config: textRecognition.TextRecognitionConfiguration = {
      isDirectionDetectionSupported: true
    }
    
    console.info(`>>> 调用官方 OCR，方向检测: 开启`)
    
    const result: textRecognition.TextRecognitionResult = 
      await textRecognition.recognizeText(visionInfo, config)
    
    console.info(`>>> OCR 原始结果: ${result.value?.substring(0, 100)}`)
    
    // 直接解析结果
    const ocrResults: OCRResult[] = []
    
    if (result.value) {
      const lines = result.value.split('\n').filter(line => line.trim().length > 0)
      for (const line of lines) {
        ocrResults.push({
          text: line.trim(),
          confidence: 0.9
        })
      }
    }
    
    console.info(`>>> 识别完成: ${ocrResults.length} 条`)
    return ocrResults
  }
  
  /**
   * 裁剪图片
   */
  private static async cropImage(
    pixelMap: image.PixelMap,
    x: number,
    y: number,
    width: number,
    height: number
  ): Promise<image.PixelMap | null> {
    try {
      const bytesPerPixel = 4
      const rowBytes = width * bytesPerPixel
      const totalBytes = rowBytes * height
      
      const buffer = new ArrayBuffer(totalBytes)
      
      for (let row = 0; row < height; row++) {
        const srcY = y + row
        const srcX = x
        
        const rowBuffer = new ArrayBuffer(rowBytes)
        const readOpts: image.PositionArea = {
          pixels: rowBuffer,
          offset: 0,
          stride: rowBytes,
          region: { 
            x: srcX, 
            y: srcY, 
            size: { width: width, height: 1 } 
          }
        }
        
        await pixelMap.readPixels(readOpts)
        
        const srcView = new Uint8Array(rowBuffer)
        const dstView = new Uint8Array(buffer, row * rowBytes, rowBytes)
        dstView.set(srcView)
      }
      
      const initOptions: image.InitializationOptions = {
        size: { width: width, height: height },
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true
      }
      
      return image.createPixelMapSync(buffer, initOptions)
      
    } catch (error) {
      const e = error as BusinessError
      console.error('>>> 裁剪失败:', e.code, e.message)
      return null
    }
  }

  /**
   * 释放资源
   */
  static async release(): Promise<void> {
    if (!MLKitOCR.isInitialized) {
      return
    }
    
    try {
      await textRecognition.release()
      MLKitOCR.isInitialized = false
      console.info('OCR 资源释放成功')
    } catch (error) {
      const e = error as BusinessError
      console.error('OCR 释放失败:', e.code, e.message)
    }
  }
}

import { MLKitOCR, OCRResult } from './MLKitOCR'
import image from '@ohos.multimedia.image'
import fs from '@ohos.file.fs'
import { BusinessError } from '@ohos.base'
import common from '@ohos.app.ability.common'

// 重新导出 OCRResult 类型
export { OCRResult } from './MLKitOCR'

/**
 * 鞋标信息
 */
export interface ShoeLabelInfo {
  id: number
  imageUri: string
  brand: string
  model: string
  width: string  // 鞋型：NARROW/WIDE/空
  size: string
  rawText: string
  status: number
}

/**
 * 品牌匹配结果
 */
interface BrandMatch {
  brand: string
  pos: number
}

/**
 * 文本行位置信息
 */
interface LinePosition {
  result: OCRResult
  start: number
  end: number
}

// 全局 context
let appContext: common.UIAbilityContext | null = null

// 全局网格设置
// 格式: { rows: 行数, cols: 列数 }
// 1x1=不分割, 1x2=横向双标签, 2x1=纵向双标签, 2x2=四宫格...
let globalGridRows: number = 1
let globalGridCols: number = 1

/**
 * 设置应用上下文
 */
export function setAppContext(context: common.UIAbilityContext): void {
  appContext = context
}

/**
 * 设置图片分割网格
 * @param rows 行数
 * @param cols 列数
 */
export function setGridSize(rows: number, cols: number): void {
  globalGridRows = Math.max(1, Math.min(rows, 5))
  globalGridCols = Math.max(1, Math.min(cols, 5))
  console.info(`>>> 设置网格: ${globalGridRows}x${globalGridCols}`)
}

/**
 * 获取当前网格设置
 * @returns [rows, cols]
 */
export function getGridSize(): number[] {
  return [globalGridRows, globalGridCols]
}

/**
 * 获取应用上下文
 */
export function getAppContext(): common.UIAbilityContext | null {
  return appContext
}

/**
 * OCR工具类
 */
export class OCRUtils {

  /**
   * 识别图片中的文字
   * 优先使用 ML Kit，失败时降级到模拟数据
   * @param imageUri 图片路径
   */
  static async recognizeText(imageUri: string): Promise<OCRResult[]> {
    let pixelMap: image.PixelMap | null = null
    
    try {
      console.info(`>>> 开始识别图片: ${imageUri}, 网格: ${globalGridRows}x${globalGridCols}`)
      
      // 尝试加载图片为 PixelMap
      pixelMap = await loadImageAsPixelMap(imageUri)
      
      if (!pixelMap) {
        console.error('>>> 图片加载失败，使用模拟数据')
        return await mockRecognizeText()
      }
      
      console.info('>>> 图片加载成功，尝试 ML Kit...')
      
      // 初始化 ML Kit
      const initialized = await MLKitOCR.init()
      if (!initialized) {
        console.warn('>>> ML Kit 初始化失败，使用模拟数据')
        pixelMap.release()
        return await mockRecognizeText()
      }
      
      // 使用 ML Kit 进行识别（支持网格分割）
      const results = await MLKitOCR.recognizeText(pixelMap, globalGridRows, globalGridCols)
      
      // 释放 PixelMap
      try {
        pixelMap.release()
      } catch (e) {
        console.warn('释放 PixelMap 时出错:', e)
      }
      
      // 如果 ML Kit 返回结果，直接返回
      if (results.length > 0) {
        console.info('>>> ML Kit 识别成功，返回', results.length, '条结果')
        return results
      }
      
      console.warn('>>> ML Kit 未识别到文字，使用模拟数据')
      return await mockRecognizeText()
      
    } catch (error) {
      const err = error as Error
      console.error('>>> 识别过程出错:', err.message)
      if (pixelMap) {
        try {
          pixelMap.release()
        } catch (e) {
          const releaseErr = e as Error
          console.warn('释放 PixelMap 时出错:', releaseErr.message)
        }
      }
      return await mockRecognizeText()
    }
  }

  /**
   * 从 OCR 结果提取鞋标信息（支持单图片多标签）
   */
  static extractLabelInfo(ocrResults: OCRResult[]): Partial<ShoeLabelInfo>[] {
    console.info('=================================')
    console.info(`OCR 结果共 ${ocrResults.length} 条`)
    
    // 检查是否有 groupId（网格分割结果）
    const hasGroupId = ocrResults.length > 0 && ocrResults[0].groupId !== undefined
    
    if (hasGroupId) {
      // 使用 groupId 直接分组（网格分割模式）
      console.info('使用 groupId 分组（网格分割模式）')
      
      const groupMap = new Map<number, OCRResult[]>()
      for (const result of ocrResults) {
        const gid: number = result.groupId ?? 0
        if (!groupMap.has(gid)) {
          groupMap.set(gid, [])
        }
        groupMap.get(gid)!.push(result)
      }
      
      const labels: Partial<ShoeLabelInfo>[] = []
      let groupIndex = 0
      
      for (const entry of groupMap) {
        const gid: number = entry[0]
        const groupResults: OCRResult[] = entry[1]
        const groupText = groupResults.map((r): string => r.text).join(' ')
        console.info(`\n组 ${gid} 文本: ${groupText.substring(0, 80)}...`)
        
        const brand = extractBrand(groupResults)
        const model = extractModel(groupResults)
        const width = extractWidth(groupResults)
        const size = extractSize(groupResults)
        
        console.info(`  -> 品牌: ${brand || 'X'}, 款式: ${model || 'X'}, 鞋型: ${width || 'X'}, 尺码: ${size || 'X'}`)
        
        const labelInfo: Partial<ShoeLabelInfo> = {
          brand: brand,
          model: model,
          width: width,
          size: size,
          rawText: groupText
        }
        
        // 只添加有效标签（有品牌或尺码）
        if (labelInfo.brand || labelInfo.size) {
          labels.push(labelInfo)
          console.info(`  -> 有效标签，已添加`)
        } else {
          console.info(`  -> 无效标签，已跳过`)
        }
        
        groupIndex++
      }
      
      console.info(`================================= 共提取 ${labels.length} 个标签`)
      return labels
    }
    
    // 没有 groupId，使用传统分割逻辑
    const fullText = ocrResults.map((r): string => r.text).join(' ')
    console.info('OCR 原始文本:')
    ocrResults.forEach((r, i) => console.info(`  ${i + 1}. ${r.text}`))
    console.info('OCR 全文:', fullText)
    
    // 检测图片中是否有多个标签
    const labelCount = detectLabelCount(ocrResults)
    console.info('检测到标签数量:', labelCount)
    
    if (labelCount <= 1) {
      // 单标签情况 - 双向交叉验证策略
      // 正序提取
      const normalBrand = extractBrand(ocrResults)
      const normalModel = extractModel(ocrResults)
      const normalWidth = extractWidth(ocrResults)
      const normalSize = extractSize(ocrResults)
      
      // 倒序提取（反转所有文本）
      const reversedResults = getReversedResults(ocrResults)
      const reversedBrand = extractBrand(reversedResults)
      const reversedModel = extractModel(reversedResults)
      const reversedWidth = extractWidth(reversedResults)
      const reversedSize = extractSize(reversedResults)
      
      // 智能合并：优先取识别到的，正序优先
      const brand = normalBrand || reversedBrand
      const model = normalModel || reversedModel
      const width = normalWidth || reversedWidth
      const size = normalSize || reversedSize
      
      console.info('双向提取结果:')
      console.info(`  正序: 品牌=${normalBrand || 'X'}, 款式=${normalModel || 'X'}, 鞋型=${normalWidth || 'X'}, 尺码=${normalSize || 'X'}`)
      console.info(`  倒序: 品牌=${reversedBrand || 'X'}, 款式=${reversedModel || 'X'}, 鞋型=${reversedWidth || 'X'}, 尺码=${reversedSize || 'X'}`)
      console.info(`  合并: 品牌=${brand || 'X'}, 款式=${model || 'X'}, 鞋型=${width || 'X'}, 尺码=${size || 'X'}`)
      
      const labelInfo: Partial<ShoeLabelInfo> = {
        brand: brand,
        model: model,
        width: width,
        size: size,
        rawText: fullText
      }
      return [labelInfo]
    }
    
    // 多标签情况：分割 OCR 结果并分别提取
    console.info('进入多标签分割流程...')
    const splitResults = splitMultiLabels(ocrResults)
    console.info(`分割为 ${splitResults.length} 组`)
    
    const labels: Partial<ShoeLabelInfo>[] = []
    
    for (let i = 0; i < splitResults.length; i++) {
      const resultGroup = splitResults[i]
      const groupText = resultGroup.map((r): string => r.text).join(' ')
      
      console.info(`\n第 ${i + 1} 组文本: ${groupText.substring(0, 50)}...`)
      
      const brand = extractBrand(resultGroup)
      const model = extractModel(resultGroup)
      const width = extractWidth(resultGroup)
      const size = extractSize(resultGroup)
      
      console.info(`  -> 品牌: ${brand || 'X'}, 款式: ${model || 'X'}, 鞋型: ${width || 'X'}, 尺码: ${size || 'X'}`)
      
      const labelInfo: Partial<ShoeLabelInfo> = {
        brand: brand,
        model: model,
        width: width,
        size: size,
        rawText: groupText
      }
      
      // 只添加有效标签（有品牌或尺码）
      if (labelInfo.brand || labelInfo.size) {
        labels.push(labelInfo)
        console.info(`  -> 有效标签，已添加`)
      } else {
        console.info(`  -> 无效标签，已跳过`)
      }
    }
    
    // 如果没有提取到有效标签，返回整体结果
    if (labels.length === 0) {
      console.warn('未提取到有效标签，返回整体结果')
      labels.push({
        brand: extractBrand(ocrResults),
        model: extractModel(ocrResults),
        size: extractSize(ocrResults),
        rawText: fullText
      })
    }
    
    console.info(`================================= 共提取 ${labels.length} 个标签`)
    return labels
  }

  /**
   * 生成 CSV 文件内容
   */
  static generateCSV(labels: ShoeLabelInfo[]): string {
    const headers = ['序号', '品牌', '款式', '鞋型', '尺码', '图片']
    const rows = labels.map((item, index): string => {
      // 从图片URI提取文件名
      const imageName = item.imageUri ? item.imageUri.split('/').pop() || '' : ''
      const columns = [
        (index + 1).toString(),
        escapeCsvField(item.brand || ''),
        escapeCsvField(item.model || ''),
        escapeCsvField(item.width || ''),
        escapeCsvField(item.size || ''),
        escapeCsvField(imageName)
      ]
      return columns.join(',')
    })
    
    return [headers.join(','), ...rows].join('\n')
  }
}

/**
 * 将图片 URI 转换为 PixelMap
 */
async function loadImageAsPixelMap(imageUri: string): Promise<image.PixelMap | null> {
  try {
    console.info('开始加载图片:', imageUri)
    
    // 直接使用 URI 创建 ImageSource
    console.info('尝试创建 ImageSource...')
    const imageSource = image.createImageSource(imageUri)
    
    const pixelMap = await imageSource.createPixelMap({
      editable: false,
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    })
    
    console.info('PixelMap 创建成功')
    return pixelMap
    
  } catch (error) {
    const err = error as Error
    console.error('直接创建 ImageSource 失败:', err.message)
    
    // 尝试从文件读取
    return await loadImageFromFile(imageUri)
  }
}

/**
 * 从文件加载图片
 */
async function loadImageFromFile(imageUri: string): Promise<image.PixelMap | null> {
  try {
    console.info('尝试从文件读取:', imageUri)
    
    // 使用 fs 打开文件
    const file = fs.openSync(imageUri, fs.OpenMode.READ_ONLY)
    console.info('fs.open 成功，fd:', file.fd)
    
    const stat = fs.statSync(file.fd)
    console.info('文件大小:', stat.size, '字节')
    
    const buffer = new ArrayBuffer(stat.size)
    fs.readSync(file.fd, buffer)
    fs.closeSync(file)
    
    console.info('成功读取文件到 buffer')
    
    const imageSource = image.createImageSource(buffer)
    const pixelMap = await imageSource.createPixelMap({
      editable: false,
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    })
    
    console.info('文件方式 PixelMap 创建成功')
    return pixelMap
    
  } catch (error) {
    const err = error as Error
    console.error('文件读取失败:', err.message)
    return null
  }
}

/**
 * 模拟 OCR 识别（降级方案）
 */
async function mockRecognizeText(): Promise<OCRResult[]> {
  return new Promise((resolve) => {
    setTimeout(() => {
      console.info('>>> 使用模拟 OCR 数据（ML Kit 失败或未配置）')
      const mockResults: OCRResult[] = [
        { text: 'La Sportiva', confidence: 0.95 },
        { text: 'Solution Comp', confidence: 0.92 },
        { text: 'Size: EUR 42', confidence: 0.88 },
        { text: 'Model: 20S', confidence: 0.85 }
      ]
      resolve(mockResults)
    }, 1500)
  })
}

/**
 * 转义 CSV 字段
 */
function escapeCsvField(field: string): string {
  if (field.includes(',') || field.includes('\n') || field.includes('"')) {
    const escaped = field.replace(/"/g, '""')
    return `"${escaped}"`
  }
  return field
}

/**
 * 品牌模式接口
 */
interface BrandPattern {
  pattern: RegExp
  name: string
}

/**
 * 检测图片中标签数量
 * 策略：统计品牌+尺码的组合数，支持同品牌多标签
 */
function detectLabelCount(results: OCRResult[]): number {
  const fullText = results.map((r): string => r.text).join(' ')
  
  // 标准化品牌匹配（支持带空格和不带空格）
  const brandPatterns: BrandPattern[] = [
    { pattern: /La\s*Sportiva/gi, name: 'La Sportiva' },
    { pattern: /Scarpa/gi, name: 'Scarpa' },
    { pattern: /Five\s*Ten|5\s*Ten/gi, name: 'Five Ten' },
    { pattern: /Butora/gi, name: 'Butora' },
    { pattern: /Evolv/gi, name: 'Evolv' },
    { pattern: /Mad\s*Rock/gi, name: 'Mad Rock' },
    { pattern: /Black\s*Diamond/gi, name: 'Black Diamond' },
    { pattern: /Red\s*Chili/gi, name: 'Red Chili' },
    { pattern: /Ocun/gi, name: 'Ocun' },
    { pattern: /So\s*iLL|Soill/gi, name: 'So iLL' },
    { pattern: /Tenaya/gi, name: 'Tenaya' },
    { pattern: /Boreal/gi, name: 'Boreal' },
    { pattern: /Climb\s*X/gi, name: 'Climb X' },
    { pattern: /Millet/gi, name: 'Millet' },
    { pattern: /Kailas/gi, name: 'Kailas' }
  ]

  const foundBrands: BrandMatch[] = []
  
  for (const bp of brandPatterns) {
    let match: RegExpExecArray | null = null
    while ((match = bp.pattern.exec(fullText)) !== null) {
      const bm: BrandMatch = { brand: bp.name, pos: match.index }
      foundBrands.push(bm)
    }
  }
  
  // 按位置排序
  foundBrands.sort((a, b) => a.pos - b.pos)

  // 去重：相邻的相同品牌（距离<150字符）视为同一标签的重复
  const uniqueBrands: BrandMatch[] = []
  for (const fb of foundBrands) {
    const last = uniqueBrands.length > 0 ? uniqueBrands[uniqueBrands.length - 1] : null
    if (last && last.brand.toLowerCase() === fb.brand.toLowerCase() && fb.pos - last.pos < 80) {
      continue
    }
    uniqueBrands.push(fb)
  }

  if (uniqueBrands.length === 0) {
    return 1  // 没检测到品牌，默认单标签
  }

  // 统计尺码出现位置（30-50范围内的数字）
  const sizeRegex = /(?:size[:\s]+)?(?:eur[:\s]+)?(3[0-9]|4[0-9]|50)(?:\.5)?/gi
  const foundSizes: number[] = []
  let sizeMatch: RegExpExecArray | null = null
  while ((sizeMatch = sizeRegex.exec(fullText)) !== null) {
    foundSizes.push(sizeMatch.index)
  }
  foundSizes.sort((a, b) => a - b)

  console.info(`检测到 ${foundBrands.length} 个品牌（去重后 ${uniqueBrands.length} 个），${foundSizes.length} 个尺码`)

  // 策略：基于去重后的品牌数量，检查每个品牌后有尺码
  let labelCount = 0
  let sizeIndex = 0

  for (let i = 0; i < uniqueBrands.length; i++) {
    const brandPos = uniqueBrands[i].pos
    const nextBrandPos = i < uniqueBrands.length - 1 ? uniqueBrands[i + 1].pos : brandPos + 999

    // 查找该品牌后的尺码（在当前品牌和下一个品牌之间）
    let hasSize = false
    while (sizeIndex < foundSizes.length && foundSizes[sizeIndex] < nextBrandPos) {
      if (foundSizes[sizeIndex] > brandPos && foundSizes[sizeIndex] - brandPos < 300) {
        hasSize = true
        sizeIndex++
        break
      }
      sizeIndex++
    }

    // 有品牌+尺码的组合，算一个有效标签
    if (hasSize || i === uniqueBrands.length - 1) {
      labelCount++
    }
  }
  
  // 保底：至少检测到1个，最多5个
  labelCount = Math.max(1, Math.min(labelCount, 5))
  
  if (labelCount > 1) {
    console.info(`检测到 ${labelCount} 个标签（支持同品牌多标签）`)
  }
  
  return labelCount
}

/**
 * 分割多标签 OCR 结果
 * 策略：以品牌+尺码的组合为单元进行分割
 * 支持同品牌多标签（通过尺码区分）
 */
function splitMultiLabels(results: OCRResult[]): OCRResult[][] {
  const fullText = results.map((r): string => r.text).join(' ')
  
  // 标准化品牌匹配
  const brandPatterns: BrandPattern[] = [
    { pattern: /La\s*Sportiva/gi, name: 'La Sportiva' },
    { pattern: /Scarpa/gi, name: 'Scarpa' },
    { pattern: /Five\s*Ten|5\s*Ten/gi, name: 'Five Ten' },
    { pattern: /Butora/gi, name: 'Butora' },
    { pattern: /Evolv/gi, name: 'Evolv' },
    { pattern: /Mad\s*Rock/gi, name: 'Mad Rock' },
    { pattern: /Black\s*Diamond/gi, name: 'Black Diamond' },
    { pattern: /Red\s*Chili/gi, name: 'Red Chili' },
    { pattern: /Ocun/gi, name: 'Ocun' },
    { pattern: /So\s*iLL|Soill/gi, name: 'So iLL' },
    { pattern: /Tenaya/gi, name: 'Tenaya' },
    { pattern: /Boreal/gi, name: 'Boreal' },
    { pattern: /Climb\s*X/gi, name: 'Climb X' },
    { pattern: /Millet/gi, name: 'Millet' },
    { pattern: /Kailas/gi, name: 'Kailas' }
  ]

  // 找出所有品牌位置
  const brandMatches: BrandMatch[] = []
  for (const bp of brandPatterns) {
    let match: RegExpExecArray | null = null
    while ((match = bp.pattern.exec(fullText)) !== null) {
      const bm: BrandMatch = { brand: bp.name, pos: match.index }
      brandMatches.push(bm)
    }
  }
  brandMatches.sort((a, b) => a.pos - b.pos)

  // 去重：相邻的相同品牌（距离<80字符）视为同一标签的重复，只保留第一个用于分割
  const uniqueMatches: BrandMatch[] = []
  for (const bm of brandMatches) {
    const last = uniqueMatches.length > 0 ? uniqueMatches[uniqueMatches.length - 1] : null
    if (last && last.brand.toLowerCase() === bm.brand.toLowerCase() && bm.pos - last.pos < 80) {
      continue
    }
    uniqueMatches.push(bm)
  }

  if (uniqueMatches.length <= 1) {
    return [results]
  }

  // 构建文本行位置映射
  let currentPos = 0
  const linePositions: LinePosition[] = []
  for (const result of results) {
    const text = result.text
    const lp: LinePosition = {
      result: result,
      start: currentPos,
      end: currentPos + text.length
    }
    linePositions.push(lp)
    currentPos += text.length + 1
  }

  // 根据最近的品牌位置将文本行分组
  const groupMap = new Map<number, OCRResult[]>()
  for (const um of uniqueMatches) {
    groupMap.set(um.pos, [])
  }

  for (const lp of linePositions) {
    // 找到最近的品牌位置
    let nearestPos = uniqueMatches[0].pos
    let minDistance = Math.abs(lp.start - uniqueMatches[0].pos)

    for (const um of uniqueMatches) {
      const distance = Math.abs(lp.start - um.pos)
      if (distance < minDistance) {
        minDistance = distance
        nearestPos = um.pos
      }
    }

    // 添加到对应组
    const group = groupMap.get(nearestPos)
    if (group) {
      group.push(lp.result)
    }
  }

  // 收集分组结果
  const groups: OCRResult[][] = []
  for (const um of uniqueMatches) {
    const group = groupMap.get(um.pos)
    if (group && group.length > 0) {
      groups.push(group)
    }
  }

  console.info(`多标签分割完成，共 ${groups.length} 组（支持同品牌多标签）`)
  for (let i = 0; i < groups.length; i++) {
    const preview = groups[i].map(r => r.text).join(', ').substring(0, 50)
    console.info(`  组 ${i + 1}: ${preview}...`)
  }

  return groups.length > 0 ? groups : [results]
}

/**
 * 从 OCR 结果提取品牌
 * 支持完整匹配和分段匹配（处理品牌被拆开的情况）
 */
function extractBrand(results: OCRResult[]): string {
  const fullText = results.map((r): string => r.text).join(' ')
  const normalizedText = fullText.toLowerCase().replace(/\s+/g, '')
  
  // 标准化品牌匹配（忽略空格和大小写）
  const brandMap: Record<string, string> = {
    'lasportiva': 'La Sportiva',
    'scarpa': 'Scarpa',
    'fiveten': 'Five Ten',
    '5ten': 'Five Ten',
    'butora': 'Butora',
    'btora': 'Butora',
    'butoa': 'Butora',  // 倒置近似
    'butor': 'Butora',  // OCR漏字母
    'rotub': 'Butora',  // 倒置
    'eutora': 'Butora', // OCR误识别
    'evolv': 'Evolv',
    'madrock': 'Mad Rock',
    'blackdiamond': 'Black Diamond',
    'redchili': 'Red Chili',
    'ocun': 'Ocun',
    'soill': 'So iLL',
    'tenaya': 'Tenaya',
    'boreal': 'Boreal',
    'climbx': 'Climb X',
    'millet': 'Millet',
    'kailas': 'Kailas'
  }
  
  // 1. 先尝试完整匹配
  const keys = Object.keys(brandMap)
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i]
    if (normalizedText.includes(key)) {
      return brandMap[key]
    }
  }
  
  // 2. 处理品牌被拆开的情况
  const splitBrandMap: Record<string, string[]> = {
    'soill': ['so', 'ill'],
    'lasportiva': ['la', 'sportiva'],
    'fiveten': ['five', 'ten'],
    'blackdiamond': ['black', 'diamond'],
    'madrock': ['mad', 'rock'],
    'redchili': ['red', 'chili']
  }
  
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i]
    const parts = splitBrandMap[key]
    if (parts) {
      let allFound = true
      for (let j = 0; j < parts.length; j++) {
        if (!normalizedText.includes(parts[j])) {
          allFound = false
          break
        }
      }
      if (allFound) {
        return brandMap[key]
      }
    }
  }
  
  // 3. 检测倒置文字（如 BUTORA 倒置后可能被识别为 AROTOB 或类似）
  // 将文本反转，再尝试匹配
  const reversedText = normalizedText.split('').reverse().join('')
  console.info(`>>> 尝试倒置匹配: 原="${normalizedText}" 反转="${reversedText}"`)
  
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i]
    if (reversedText.includes(key)) {
      console.info(`>>> 倒置匹配成功: ${key} -> ${brandMap[key]}`)
      return brandMap[key]
    }
  }
  
  // 4. 倒置模糊匹配（针对 "AとOTUB" 这类 OCR 误识别）
  // 尝试从反转文本中提取可能的字母序列匹配
  const reversedAlpha = reversedText.replace(/[^a-z]/g, '') // 只保留字母
  console.info(`>>> 倒置纯字母: "${reversedAlpha}"`)
  
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i]
    // 如果反转后的纯字母包含品牌名（>=4个字符的匹配）
    if (key.length >= 4 && reversedAlpha.includes(key)) {
      console.info(`>>> 倒置模糊匹配成功: ${key} -> ${brandMap[key]}`)
      return brandMap[key]
    }
  }
  
  // 5. 备用：根据款式推断品牌
  const model = extractModel(results)
  if (model) {
    const brandFromModel = getBrandByModel(model)
    if (brandFromModel) {
      console.info(`>>> 款式推断品牌: ${model} -> ${brandFromModel}`)
      return brandFromModel
    }
  }
  
  return ''
}

/**
 * 根据款式推断品牌（备用策略）
 */
function getBrandByModel(model: string): string {
  const modelBrandMap: Record<string, string> = {
    // Butora 款式
    'LIBRA': 'Butora',
    'KOMET': 'Butora',
    'ACRO': 'Butora',
    'GOMI': 'Butora',
    'ALTURA': 'Butora',
    'NARU': 'Butora',
    'MUSA': 'Butora',
    // La Sportiva
    'Solution': 'La Sportiva',
    'Theory': 'La Sportiva',
    'Skwama': 'La Sportiva',
    'TC Pro': 'La Sportiva',
    'Miura': 'La Sportiva',
    'Katana': 'La Sportiva',
    // Scarpa
    'DRAGO': 'Scarpa',
    'Instinct': 'Scarpa',
    'Chimera': 'Scarpa',
    'Magos': 'Scarpa',
    'Vapor': 'Scarpa',
    // So iLL
    'Torque': 'So iLL',
    'Step': 'So iLL',
    // Five Ten
    'Hiangle': 'Five Ten',
    'Anasazi': 'Five Ten',
    // Evolv
    'Shaman': 'Evolv',
    'Zenist': 'Evolv'
  }
  
  // 尝试匹配（不区分大小写）
  const upperModel = model.toUpperCase()
  const keys = Object.keys(modelBrandMap)
  for (let i = 0; i < keys.length; i++) {
    if (upperModel.includes(keys[i].toUpperCase())) {
      return modelBrandMap[keys[i]]
    }
  }
  
  return ''
}

/**
 * 获取反转后的 OCR 结果（用于倒置文字识别）
 */
function getReversedResults(results: OCRResult[]): OCRResult[] {
  return results.map((r): OCRResult => ({
    text: r.text.split('').reverse().join(''),
    confidence: r.confidence,
    groupId: r.groupId
  }))
}

/**
 * 从 OCR 结果提取鞋型（NARROW/WIDE）
 */
function extractWidth(results: OCRResult[]): string {
  const fullText = results.map((r): string => r.text).join(' ').toUpperCase()
  
  // NARROW 及其近似变体
  if (fullText.includes('NARROW') || fullText.includes('NABROW') || 
      fullText.includes('NAROW') || fullText.includes('NARRO')) {
    return 'NARROW'
  }
  // WIDE 及其近似变体
  if (fullText.includes('WIDE') || fullText.includes('WID')) {
    return 'WIDE'
  }
  
  return ''
}

/**
 * 从 OCR 结果提取款式
 */
function extractModel(results: OCRResult[]): string {
  const modelPatterns = [
    // La Sportiva
    /Solution\s+Comp/i, /Solution/i, /Theory/i, /Skwama/i,
    /TC\s*Pro/i, /Miura/i, /Katana/i, /Futura/i, /Genius/i,
    /Kataki/i, /Otaki/i, /Testarossa/i, /Mantra/i,
    // Scarpa
    /DRAGO\s+XT/i, /DRAGO\s+LV/i, /DRAGO/i, /Instinct\s+VS/i, /Instinct\s+VSR/i,
    /Instinct/i, /Chimera/i, /Magos/i, /Quantic/i,
    /Vapor\s+S/i, /Vapor\s+Lace/i, /Vapor/i, /Veloce/i,
    /Mojito/i, /Force\s+V/i, /Maestro/i, /Boostic/i,
    // Five Ten
    /Hiangle/i, /Anasazi/i, /Verdon/i, /Quantum/i,
    /Street/i, /Dragon/i, /Moccasym/i,
    // Evolv
    /Shaman/i, /Zenist/i, /Defy/i, /Gym/i,
    // Mad Rock
    /Drone/i, /Redline/i,
    // Black Diamond
    /Zone/i, /Momentum/i, /Shadow/i,
    // Other
    /Origin/i, /Zen/i, /Aggro/i,
    // So iLL
    /Torque/i, /Step/i, /Free\s*Range/i, /Street\s*LV/i, /New\s*Zero/i, /The\s*Runner/i,
    // Butora（长的模式放前面优先匹配）
    // 款式 + 宽/窄（简化输出，去掉中间的颜色词）
    /LIBRA\s+VC/i, /LIBRA/i, /KOMET/i,
    /ACRO/i, /GOMI/i, /ALTURA/i, /NARU/i, /MUSA/i,
  ]
  
  const fullText = results.map((r): string => r.text).join(' ')
  
  for (const pattern of modelPatterns) {
    const match = fullText.match(pattern)
    if (match) {
      return match[0]
    }
  }
  
  for (const result of results) {
    const text = result.text
    if (/^[A-Z][a-zA-Z]*\s*\d+$/.test(text)) {
      return text
    }
    const modelMatch = text.match(/[Mm]odel[:\s]+(.+)/)
    if (modelMatch) {
      return modelMatch[1].trim()
    }
  }
  
  return ''
}

/**
 * 从 OCR 结果提取尺码
 * 限制范围：30~50
 */
function extractSize(results: OCRResult[]): string {
  const fullText = results.map((r): string => r.text).join(' ')
  console.info(`>>> 提取尺码，文本: ${fullText.substring(0, 100)}...`)
  
  // 改进的正则表达式，支持更多格式
  const sizePatterns = [
    // SIZE: 38.5 或 SIZE : 38.5 或 SIZE:38.5
    /[Ss][Ii][Zz][Ee]\s*[:\s]\s*(\d+(?:\.5)?)/,
    // EUR 38.5 或 eur 38.5
    /[Ee][Uu][Rr]\s*[:\s]?\s*(\d+(?:\.5)?)/,
    // US 8.5
    /[Uu][Ss]\s*[:\s]?\s*(\d+(?:\.5)?)/,
    // UK 7.5
    /[Uu][Kk]\s*[:\s]?\s*(\d+(?:\.5)?)/,
    // 38.5 EU 或 38 EU
    /(\d+(?:\.5)?)\s*[Ee][Uu]/,
    // 38.5 US
    /(\d+(?:\.5)?)\s*[Uu][Ss]/,
    // 38.5 UK
    /(\d+(?:\.5)?)\s*[Uu][Kk]/,
    // 纯数字 38.5 或 38（限制范围）
    /\b(3[0-9]|4[0-9]|50)(?:\.5)?\b/
  ]
  
  for (const pattern of sizePatterns) {
    const match = fullText.match(pattern)
    if (match) {
      const size = match[1]
      const sizeNum = parseFloat(size)
      
      console.info(`>>> 匹配到尺码: ${size}, 数字: ${sizeNum}`)
      
      // 限制鞋码范围 30~50
      if (sizeNum < 30 || sizeNum > 50) {
        console.info(`>>> 尺码 ${sizeNum} 超出范围，跳过`)
        continue
      }
      
      const patternStr = pattern.source.toLowerCase()
      if (patternStr.includes('eur') || patternStr.includes('eu')) {
        console.info(`>>> 返回 EUR ${size}`)
        return `EUR ${size}`
      } else if (patternStr.includes('us')) {
        console.info(`>>> 返回 US ${size}`)
        return `US ${size}`
      } else if (patternStr.includes('uk')) {
        console.info(`>>> 返回 UK ${size}`)
        return `UK ${size}`
      } else {
        // 默认 EUR（攀岩鞋通常用欧码）
        console.info(`>>> 默认返回 EUR ${size}`)
        return `EUR ${size}`
      }
    }
  }
  
  console.info(`>>> 未匹配到尺码`)
  return ''
}

import { fileIo } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'

/**
 * 文件工具类
 */
export class FileUtils {

  /**
   * 复制文件到指定目录
   */
  static copyFile(srcPath: string, destPath: string): boolean {
    try {
      fileIo.copyFileSync(srcPath, destPath)
      return true
    } catch (err) {
      const error: BusinessError = err as BusinessError
      console.error('复制文件失败:', JSON.stringify(error))
      return false
    }
  }

  /**
   * 检查文件是否存在
   */
  static fileExists(path: string): boolean {
    try {
      return fileIo.accessSync(path)
    } catch (err) {
      return false
    }
  }

  /**
   * 创建目录
   */
  static createDir(path: string): boolean {
    try {
      fileIo.mkdirSync(path)
      return true
    } catch (err) {
      const error: BusinessError = err as BusinessError
      console.error('创建目录失败:', JSON.stringify(error))
      return false
    }
  }

  /**
   * 读取文件内容为字符串
   */
  static readFile(path: string): string {
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
      const stat = fileIo.statSync(file.fd)
      const buf = new ArrayBuffer(stat.size)
      fileIo.readSync(file.fd, buf)
      fileIo.closeSync(file)
      const decoder = new util.TextDecoder()
      return decoder.decodeToString(new Uint8Array(buf))
    } catch (err) {
      const error: BusinessError = err as BusinessError
      console.error('读取文件失败:', JSON.stringify(error))
      return ''
    }
  }

  /**
   * 写入字符串到文件
   */
  static writeFile(path: string, content: string): boolean {
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
      const encoder = new util.TextEncoder()
      const buf: Uint8Array = encoder.encodeInto(content)
      fileIo.writeSync(file.fd, buf.buffer)
      fileIo.closeSync(file)
      return true
    } catch (err) {
      const error: BusinessError = err as BusinessError
      console.error('写入文件失败:', JSON.stringify(error))
      return false
    }
  }

  /**
   * 获取文件大小（字节）
   */
  static getFileSize(path: string): number {
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
      const stat = fileIo.statSync(file.fd)
      fileIo.closeSync(file)
      return stat.size
    } catch (err) {
      return -1
    }
  }

  /**
   * 格式化文件大小显示
   */
  static formatFileSize(bytes: number): string {
    if (bytes < 1024) return bytes + ' B'
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(2) + ' KB'
    if (bytes < 1024 * 1024 * 1024) return (bytes / 1024 / 1024).toFixed(2) + ' MB'
    return (bytes / 1024 / 1024 / 1024).toFixed(2) + ' GB'
  }
}

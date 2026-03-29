import { abilityAccessCtrl, Context } from '@kit.AbilityKit'
import { bundleManager } from '@kit.BundleKit'
import { BusinessError } from '@kit.BasicServicesKit'

/**
 * 权限工具类
 */
export class PermissionUtils {

  /**
   * 应用需要的权限列表
   */
  static readonly REQUIRED_PERMISSIONS: string[] = [
    'ohos.permission.READ_MEDIA',
    'ohos.permission.WRITE_MEDIA',
    'ohos.permission.INTERNET'
  ]
  
  /**
   * 存储权限（用于保存CSV到下载目录）
   */
  static readonly STORAGE_PERMISSIONS: string[] = [
    'ohos.permission.READ_MEDIA',
    'ohos.permission.WRITE_MEDIA'
  ]

  /**
   * 检查权限是否已授权
   */
  static async checkPermission(permission: string): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager()
    try {
      const appInfo = bundleManager.getApplicationInfoSync('label_reader', 0, 0)
      const grantStatus = atManager.checkAccessTokenSync(appInfo.accessTokenId, permission)
      return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
    } catch (err) {
      const error: BusinessError = err as BusinessError
      console.error('检查权限失败:', JSON.stringify(error))
      return false
    }
  }

  /**
   * 检查所有必需权限
   */
  static async checkAllPermissions(): Promise<Record<string, boolean>> {
    const results: Record<string, boolean> = {}
    for (const permission of PermissionUtils.REQUIRED_PERMISSIONS) {
      results[permission] = await PermissionUtils.checkPermission(permission)
    }
    return results
  }

  /**
   * 请求权限
   */
  static async requestPermissions(permissions: string[], context: Context): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager()
    try {
      const result = await atManager.requestPermissionsFromUser(context, permissions)
      return result.authResults.every((result: number): boolean => result === 0)
    } catch (err) {
      const error: BusinessError = err as BusinessError
      console.error('请求权限失败:', JSON.stringify(error))
      return false
    }
  }

  /**
   * 请求所有必需权限
   */
  static async requestAllPermissions(context: Context): Promise<boolean> {
    return PermissionUtils.requestPermissions(PermissionUtils.REQUIRED_PERMISSIONS, context)
  }
}

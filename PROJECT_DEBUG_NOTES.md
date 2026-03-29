# label_reader 项目Debug笔记

## 项目信息
- **名称**: 攀岩鞋标签识别
- **创建日期**: 2026/3/27
- **开发环境**: DevEco Studio 4.0+, HarmonyOS SDK API 11/12

## 核心问题与解决方案

### 1. 工程结构配置

#### SDK版本格式
```json5
// build-profile.json5
{
  "app": {
    "products": [{
      "compatibleSdkVersion": "6.0.2(22)",  // ✅ 字符串格式
      "targetSdkVersion": "6.0.2(22)",
      "runtimeOS": "HarmonyOS"
    }]
  }
}
```

#### AppScope目录结构
```
AppScope/                          # 应用级配置，必须创建
├── app.json5                      # 应用配置
│   {
│     "app": {
│       "bundleName": "com.example.labelreader",
│       "icon": "$media:app_icon",      // 必需
│       "label": "$string:app_name",    // 必需
│       "apiReleaseType": "Release1"    // 注意是Release1
│     }
│   }
└── resources/base/media/
    └── app_icon.png               # 应用图标，必需
```

### 2. 资源文件问题

#### 错误1: 非法资源目录名
**错误**: `Invalid resource directory name 'graphic'`
**解决**: `graphic/` → `media/`

#### 错误2: 资源命名冲突
**错误**: `Resource 'icon' conflict`
**原因**: `media/icon.json` 和 `media/icon.png` 同名
**解决**: 删除 `icon.json`，重命名图片为 `app_icon.png`

#### 错误3: 资源文件位置错误
**错误**: `Invalid path 'theme.json', not a directory`
**解决**: `base/theme.json` → `base/profile/theme.json`

### 3. ArkTS语法问题

#### 问题1: 使用any类型
**错误**: `Use explicit types instead of "any"`
**解决**: 所有变量必须显式声明类型
```typescript
// 错误
let data: any = ...

// 正确
interface DataType { id: number; name: string }
let data: DataType = { id: 1, name: '' }
```

#### 问题2: 对象展开运算符
**错误**: `arkts-no-spread`
**解决**: 使用 `splice` 或 `Object.assign`
```typescript
// 错误
this.list = [...this.list, newItem]

// 正确
this.list.splice(index, 1, item)
```

#### 问题3: 独立函数使用this
**错误**: `arkts-no-standalone-this`
**解决**: 使用 `static` 方法或类名调用
```typescript
// 错误
private extractBrand() { return this.brands }

// 正确
private static extractBrand() { return OCRUtils.brands }
```

#### 问题4: 状态类型
**建议**: 使用数字常量替代字符串联合类型
```typescript
// 不推荐
status: 'pending' | 'success' | 'failed'

// 推荐
const STATUS_PENDING = 0
const STATUS_SUCCESS = 1
status: number
```

### 4. 模块导入路径

**最终选择**: 使用 `@ohos` 路径（稳定兼容）
```typescript
import picker from '@ohos.file.picker'
import fs from '@ohos.file.fs'
import prompt from '@ohos.prompt'
import util from '@ohos.util'
import common from '@ohos.app.ability.common'
import { BusinessError } from '@ohos.base'
```

**注意**: `@kit` 路径需要SDK安装对应Kit，否则会报错找不到模块。

### 5. OCR功能

**当前实现**: 使用模拟数据
```typescript
// OCRUtils.ets - 模拟OCR返回固定数据
static async recognizeText(imageUri: string): Promise<OCRResult[]> {
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve([
        { text: 'La Sportiva', confidence: 0.95 },
        { text: 'Solution Comp', confidence: 0.92 },
        { text: 'Size: EUR 42', confidence: 0.88 }
      ])
    }, 1500)
  })
}
```

**真实OCR接入**: 需要华为ML Kit或第三方OCR API

### 6. CSV导出功能

**保存位置**: 应用私有目录
```
/data/app/el2/100/base/com.example.labelreader/files/攀岩鞋标签_xxx.csv
```

**查看方式**: 
1. 应用内预览（添加预览按钮显示CSV内容）
2. 连接电脑通过adb查看
3. 通过系统分享发送到其他应用

**注意**: 用户无法通过手机文件管理器直接访问应用私有目录

### 7. 最终按钮布局
```
[选择图片] [开始识别] [导出CSV] [预览CSV] [清空]
- 蓝色      绿色      橙色      紫色      红色
```

## 关键文件清单

| 文件 | 作用 | 关键配置 |
|------|------|----------|
| `build-profile.json5` | 工程构建配置 | SDK版本用字符串格式 |
| `AppScope/app.json5` | 应用配置 | 必须包含icon和label |
| `entry/oh-package.json5` | 模块依赖 | 当前无额外依赖 |
| `entry/src/main/module.json5` | 模块配置 | 权限声明 |
| `entry/src/main/ets/pages/Index.ets` | 主页面 | UI和逻辑 |
| `entry/src/main/ets/utils/OCRUtils.ets` | OCR工具 | 模拟识别逻辑 |

## 调试命令

```bash
# 清理缓存
hvigor clean

# 查看Node版本（如需要npm安装）
D:\nodejs\node.exe --version

# 查看文件
adb shell ls /data/app/el2/100/base/com.example.labelreader/files/
```

## 经验总结

1. **SDK版本**: HarmonyOS使用带括号的版本字符串 `"6.0.2(22)"`
2. **资源目录**: base下只能有element/media/profile三种
3. **图标必备**: AppScope/resources/base/media/app_icon.png必须存在
4. **类型严格**: ArkTS禁止any，所有变量必须有显式类型
5. **导入路径**: 优先使用@ohos，@kit需要额外安装SDK
6. **展开运算符**: 对象不能用...，数组操作用splice
7. **文件保存**: 应用私有目录用户不可见，需要应用内预览或分享功能

---
*文档生成日期: 2026/3/27*
*Skill已更新: harmonyos-debug*

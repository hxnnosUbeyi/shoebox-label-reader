# 鸿蒙项目 Bugfix 经验总结

> 项目名称：label_reader（攀岩鞋标签识别）
> 整理时间：2026/3/27
> 适用版本：HarmonyOS SDK 5.0.0.600+, DevEco Studio 4.0+

---

## 一、工程结构配置问题

### 1.1 SDK 版本配置格式
**错误现象**：
```
compileSdkVersion、compatibleSdkVersion或targetSdkVersion的值格式错误
```

**解决方案**：
使用字符串格式（带括号版本号）：
```json5
// build-profile.json5
{
  "app": {
    "products": [{
      "name": "default",
      "compatibleSdkVersion": "6.0.2(22)",  // ✅ 字符串格式
      "targetSdkVersion": "6.0.2(22)",
      "runtimeOS": "HarmonyOS"
    }]
  }
}
```

**注意**：HarmonyOS 使用带括号的版本字符串，如 `"6.0.2(22)"`，而不是数字 `11`。

---

### 1.2 缺少 AppScope 目录
**错误现象**：
```
missingProperty: 'icon'
```

**解决方案**：
必须创建 `AppScope` 目录存放应用级配置：
```
label_reader/
├── AppScope/
│   ├── app.json5              # 应用配置
│   └── resources/base/
│       ├── element/string.json
│       └── media/
│           └── app_icon.png   # 应用图标（必需）
├── entry/
└── build-profile.json5
```

**AppScope/app.json5 示例**：
```json5
{
  "app": {
    "bundleName": "com.example.labelreader",
    "vendor": "example",
    "versionCode": 1000000,
    "versionName": "1.0.0",
    "icon": "$media:app_icon",      // 必需！
    "label": "$string:app_name",
    "minAPIVersion": 12,
    "targetAPIVersion": 12,
    "apiReleaseType": "Release1"    // 注意是 Release1 不是 Release
  }
}
```

---

## 二、资源文件规范

### 2.1 资源目录命名
**错误现象**：
```
Invalid resource directory name 'graphic'
Resource Pack Error: 11211104
```

**解决方案**：
`resources/base/` 下只能有三种目录：

| 目录名 | 用途 | 示例文件 |
|--------|------|----------|
| `element` | 字符串、颜色、样式 | `string.json`, `color.json` |
| `media` | 图片、音频、视频 | `icon.png`, `app_icon.png` |
| `profile` | 配置文件、主题 | `main_pages.json`, `theme.json` |

**错误示例**：
```
resources/base/graphic/     ❌ 非法目录名
resources/base/theme.json   ❌ 不能直接放文件
```

**正确示例**：
```
resources/base/media/icon.png
resources/base/profile/theme.json
```

---

### 2.2 资源命名冲突
**错误现象**：
```
Resource 'icon' conflict
Resource Pack Error: 11211117
```

**原因**：
同目录下不能有同名资源（忽略扩展名）：
```
media/
├── icon.json    ❌
└── icon.png     ❌ 冲突！
```

**解决方案**：
1. 删除 `icon.json`（如果是自动生成的空文件）
2. 或者重命名图片为 `app_icon.png`

---

### 2.3 图标资源要求
**必需文件**：
1. `AppScope/resources/base/media/app_icon.png` - 应用图标
2. `entry/src/main/resources/base/media/icon.png` - 模块图标

**注意**：图片格式必须为 PNG 或 JPG，不能是 SVG。

---

## 三、ArkTS 语法规范

### 3.1 禁止 any 类型
**错误现象**：
```
ArkTS syntax error: 'any' type is not allowed
```

**解决方案**：
所有变量必须显式声明类型：
```typescript
// ❌ 错误
let data: any = ...
function process(data: any) {}

// ✅ 正确
interface LabelData {
  id: number
  name: string
}
let data: LabelData = { id: 1, name: '' }
function process(data: LabelData): void {}
```

---

### 3.2 禁止对象展开运算符
**错误现象**：
```
arkts-no-spread: Spread operator is not allowed on non-array types
```

**解决方案**：
```typescript
// ❌ 错误（对象展开）
const merged = { ...obj1, ...obj2 }
this.list = [...this.list, newItem]

// ✅ 正确（使用 Object.assign 或 splice）
const merged = Object.assign({}, obj1, obj2)
this.list.push(newItem)           // 直接 push
this.list.splice(index, 1, item)  // 替换元素
```

---

### 3.3 索引访问类型限制
**错误现象**：
```
arkts-no-aliases-by-index: Indexed access is not allowed
```

**解决方案**：
```typescript
// ❌ 错误
status: 'pending' | 'success' | 'failed'
getStatus(status: LabelData['status'])  // 索引访问

// ✅ 正确（使用数字常量）
const STATUS_PENDING = 0
const STATUS_SUCCESS = 1
const STATUS_FAILED = 2
status: number
getStatus(status: number): string
```

---

### 3.4 禁止 as const
**错误现象**：
```
arkts-no-as-const: 'as const' assertions are not allowed
```

**解决方案**：
```typescript
// ❌ 错误
status: 'pending' as const

// ✅ 正确
status: number = STATUS_PENDING
```

---

## 四、API 导入路径

### 4.1 新旧模块对照表

| 功能 | 旧路径 (@ohos) | 新路径 (@kit) |
|------|----------------|---------------|
| 文件选择器 | `@ohos.file.picker` | `@kit.FilePickerKit` |
| 文件系统 | `@ohos.file.fs` | `@kit.CoreFileKit` |
| 提示框 | `@ohos.prompt` | `@kit.ArkUI` (不稳定) |
| Ability | `@ohos.app.ability.UIAbility` | `@kit.AbilityKit` |
| 权限 | `@ohos.abilityAccessCtrl` | `@kit.AbilityKit` |
| Bundle | `@ohos.bundle.bundleManager` | `@kit.BundleKit` |
| 日志 | `@ohos.hilog` | `@kit.PerformanceAnalysisKit` |
| 窗口 | `@ohos.window` | `@kit.ArkUI` |
| 工具 | `@ohos.util` | `@kit.ArkTS` |
| 错误类型 | `@ohos.base` | `@kit.BasicServicesKit` |

**推荐**：统一使用 `@kit` 新路径，但如果遇到编译问题，可以尝试回退到 `@ohos`。

---

### 4.2 showToast 的特殊处理
**问题**：`@kit.ArkUI` 的 `promptAction.showToast` 在某些版本不稳定

**解决方案**：使用 `@ohos.prompt`：
```typescript
// ✅ 稳定方案
import prompt from '@ohos.prompt'

prompt.showToast({
  message: '提示信息',
  duration: 2000
})
```

---

### 4.3 getContext 使用
**错误现象**：
```
getContext() is deprecated
```

**解决方案**：
```typescript
import { Context } from '@kit.AbilityKit'

@Entry
@Component
struct Index {
  private context: Context = getContext(this) as Context
  
  async exportCSV() {
    const filesDir = this.context.filesDir
    // ...
  }
}
```

**注意**：`getContext(this)` 目前仍可用，但需显式转换为 `Context` 类型。

---

## 五、文件选择器 API

### 5.1 正确的导入和使用
```typescript
import { PhotoViewPicker, PhotoSelectOptions, PhotoViewMIMETypes } from '@kit.FilePickerKit'

interface SelectResult {
  photoUris: string[]
  isOriginalPhoto: boolean
}

async selectImages() {
  const options: PhotoSelectOptions = {
    maxSelectNumber: 50,
    MIMEType: PhotoViewMIMETypes.IMAGE_TYPE
  }
  const picker = new PhotoViewPicker()
  const result: SelectResult = await picker.select(options)
  
  // result.photoUris 是图片 URI 数组
  const uris: string[] = result.photoUris
}
```

---

## 六、文件系统操作

### 6.1 写入 CSV 文件示例
```typescript
import { fileIo } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { Context } from '@kit.AbilityKit'

async exportCSV(context: Context, content: string) {
  const filesDir = context.filesDir
  const filePath = `${filesDir}/data.csv`
  
  const file = fileIo.openSync(filePath, 
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
  
  const encoder = new util.TextEncoder()
  const buf: Uint8Array = encoder.encodeInto(content)
  
  fileIo.writeSync(file.fd, buf.buffer)
  fileIo.closeSync(file)
}
```

---

## 七、调试建议

### 7.1 清理缓存命令
```bash
hvigor clean
hvigor --debug
```

### 7.2 常见错误速查

| 错误码/信息 | 原因 | 解决方案 |
|------------|------|----------|
| 11211101 | 资源文件位置错误 | 检查 theme.json 是否在 profile 目录 |
| 11211104 | 非法资源目录名 | graphic → media |
| 11211117 | 资源命名冲突 | 删除 icon.json 或重命名 |
| 11211120 | 资源未定义 | 添加 app_icon.png |
| 00303038 | 缺少必需属性 | app.json5 添加 icon |
| Configuration Error | SDK版本格式错误 | 使用 `"6.0.2(22)"` 字符串 |

---

## 八、项目文件结构（最终正确版）

```
label_reader/
├── AppScope/                          # 应用级配置（必需）
│   ├── app.json5                      # 应用配置（含 icon）
│   └── resources/base/
│       ├── element/string.json
│       └── media/app_icon.png         # 应用图标（必需）
│
├── entry/
│   ├── src/main/
│   │   ├── ets/
│   │   │   ├── entryability/
│   │   │   │   └── EntryAbility.ets   # 使用 @kit.AbilityKit
│   │   │   ├── pages/
│   │   │   │   └── Index.ets          # 主页面
│   │   │   └── utils/
│   │   │       ├── OCRUtils.ets
│   │   │       ├── FileUtils.ets      # 使用 @kit.CoreFileKit
│   │   │       └── PermissionUtils.ets
│   │   └── resources/base/
│   │       ├── element/
│   │       │   ├── color.json
│   │       │   └── string.json
│   │       ├── media/
│   │       │   ├── icon.png           # 模块图标
│   │       │   └── app_icon.png       # 避免与 icon.json 冲突
│   │       └── profile/
│   │           ├── main_pages.json
│   │           └── theme.json         # 必须放这里
│   │
│   ├── build-profile.json5
│   └── oh-package.json5
│
├── build-profile.json5                # SDK 版本用字符串格式
├── hvigorfile.ts
└── oh-package.json5
```

---

## 九、关键经验总结

1. **SDK 版本**：HarmonyOS 使用 `"6.0.2(22)"` 字符串格式，不是数字 `11`
2. **资源目录**：`base` 下只能有 `element`、`media`、`profile` 三种子目录
3. **图标必备**：`AppScope/resources/base/media/app_icon.png` 必须存在
4. **类型严格**：ArkTS 禁止 `any`，所有变量必须有显式类型
5. **API 迁移**：优先使用 `@kit` 新路径，但 `prompt` 建议用 `@ohos`
6. **展开运算符**：对象不能用 `...`，数组操作推荐用 `splice`
7. **状态管理**：用数字常量替代字符串联合类型（0, 1, 2 替代 'pending', 'success'）

---

*文档结束*

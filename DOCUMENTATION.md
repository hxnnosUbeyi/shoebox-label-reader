# 攀岩鞋标签识别应用 - 技术文档

## 一、项目概述

**攀岩鞋标签识别**是一款基于 HarmonyOS (鸿蒙) 平台开发的移动应用，专门用于批量识别攀岩鞋盒标签上的文字信息，自动提取品牌、款式、尺码等关键数据，并支持导出为 CSV 格式的表格文件。

### 1.1 应用信息
| 项目 | 内容 |
|------|------|
| 应用名称 | 攀岩鞋标签识别 |
| 包名 | com.example.labelreader |
| 版本 | 1.0.0 |
| 目标平台 | HarmonyOS |
| 最低 API 版本 | 12 |
| 开发语言 | ArkTS |

### 1.2 核心功能
- 📷 **批量图片选择** - 支持从相册一次选择最多 50 张图片
- 🔍 **OCR 文字识别** - 集成 HarmonyOS Core Vision Kit 进行文字识别
- 📊 **智能信息提取** - 自动提取品牌、款式、尺码信息
- 📁 **CSV 导出** - 一键导出识别结果为 CSV 表格文件
- 👁️ **CSV 预览** - 支持在应用内预览生成的 CSV 内容

---

## 二、项目结构

```
label_reader/
├── AppScope/                           # 应用级配置
│   ├── app.json5                       # 应用配置（包名、版本等）
│   └── resources/                      # 应用级资源
│
├── entry/                              # 应用入口模块
│   ├── src/main/ets/                   # ArkTS 源代码
│   │   ├── entryability/
│   │   │   └── EntryAbility.ets        # 应用入口 Ability
│   │   ├── pages/
│   │   │   └── Index.ets               # 主页面（核心业务逻辑）
│   │   ├── components/
│   │   │   └── ImagePreview.ets        # 图片预览组件
│   │   └── utils/
│   │       ├── OCRUtils.ets            # OCR 核心工具类
│   │       ├── MLKitOCR.ets            # ML Kit OCR 实现
│   │       ├── FileUtils.ets           # 文件操作工具
│   │       └── PermissionUtils.ets     # 权限管理工具
│   │
│   ├── src/main/resources/             # 模块资源文件
│   │   ├── base/element/               # 颜色、字符串定义
│   │   ├── base/media/                 # 图标、图片资源
│   │   └── base/profile/               # 页面配置、主题
│   │
│   ├── src/main/module.json5           # 模块配置
│   └── oh-package.json5                # 模块依赖配置
│
├── hvigor/                             # 构建配置
├── build-profile.json5                 # 工程构建配置
├── hvigorfile.ts                       # 编译脚本
└── oh-package.json5                    # 工程依赖配置
```

---

## 三、核心模块详解

### 3.1 主页面 (Index.ets)

**文件位置**: `entry/src/main/ets/pages/Index.ets`

**功能职责**:
- 应用主界面渲染
- 图片选择与批量管理
- 调用 OCR 识别流程
- CSV 导出与预览

**核心数据结构**:
```typescript
interface LabelData {
  id: number           // 唯一标识
  imageUri: string     // 图片 URI
  brand: string        // 品牌
  model: string        // 款式
  size: string         // 尺码
  rawText: string      // 原始识别文本
  status: number       // 状态：0=待识别, 1=识别中, 2=成功, 3=失败
}
```

**主要方法**:

| 方法 | 功能 | 说明 |
|------|------|------|
| `selectImages()` | 选择图片 | 调用系统相册选择器，最多 50 张 |
| `startRecognition()` | 开始识别 | 批量处理待识别图片，更新进度条 |
| `exportCSV()` | 导出 CSV | 生成 CSV 文件并保存到应用私有目录 |
| `previewCSVContent()` | 预览 CSV | 显示 CSV 内容弹窗 |

**UI 组件结构**:
```
Column (根容器)
├── HeaderBuilder()      # 标题栏 + 进度显示
├── EmptyBuilder()       # 空状态提示（无图片时）
├── ListBuilder()        # 图片列表（有图片时）
├── FooterBuilder()      # 底部操作按钮
└── CSVPreviewDialog()   # CSV 预览弹窗
```

---

### 3.2 OCR 工具类 (OCRUtils.ets)

**文件位置**: `entry/src/main/ets/utils/OCRUtils.ets`

**功能职责**:
- 图片文字识别（ML Kit + 降级方案）
- 攀岩鞋标签信息提取
- CSV 文件生成

**核心接口**:
```typescript
// OCR 识别结果
interface OCRResult {
  text: string       // 识别文本
  confidence: number // 置信度
}

// 鞋标信息
interface ShoeLabelInfo {
  id: number
  imageUri: string
  brand: string    // 品牌
  model: string    // 款式
  size: string     // 尺码
  rawText: string  // 原始文本
  status: number
}
```

**主要方法**:

| 方法 | 功能 | 说明 |
|------|------|------|
| `recognizeText(imageUri)` | 识别图片文字 | 优先使用 ML Kit，失败时降级到模拟数据 |
| `extractLabelInfo(results)` | 提取标签信息 | 从 OCR 结果解析品牌、款式、尺码 |
| `generateCSV(labels)` | 生成 CSV | 将识别结果转为 CSV 格式 |
| `setAppContext(context)` | 设置上下文 | 供图片处理使用 |

**信息提取规则**:

1. **品牌提取** (`extractBrand`)
   - 内置品牌库：La Sportiva, Scarpa, Five Ten, Butora, Evolv, Mad Rock 等
   - 支持大小写不敏感匹配
   - 回退规则：匹配首字母大写的单词

2. **款式提取** (`extractModel`)
   - 内置款式库：Solution, Theory, Skwama, TC Pro, Miura, Katana 等
   - 正则匹配 `Model:` 前缀
   - 匹配字母+数字组合

3. **尺码提取** (`extractSize`)
   - 支持 EUR/US/UK 格式
   - 正则模式：`/size[:\s]+(\d+(?:\.5)?)/i`
   - 智能识别 35-50 范围内的数字为欧码

**图片加载流程**:
```
图片 URI → loadImageAsPixelMap() → PixelMap
         ↓ 失败
         → loadImageFromFile() → fs.open → buffer → PixelMap
```

---

### 3.3 ML Kit OCR 实现 (MLKitOCR.ets)

**文件位置**: `entry/src/main/ets/utils/MLKitOCR.ets`

**功能职责**:
- 封装 HarmonyOS Core Vision Kit 文字识别能力
- 提供初始化、识别、资源释放完整生命周期管理

**主要方法**:

| 方法 | 功能 |
|------|------|
| `init()` | 初始化 OCR 引擎 |
| `recognizeText(pixelMap)` | 识别 PixelMap 中的文字 |
| `release()` | 释放 OCR 资源 |

**调用示例**:
```typescript
import { MLKitOCR } from './MLKitOCR'
import image from '@ohos.multimedia.image'

// 初始化
await MLKitOCR.init()

// 创建 PixelMap
const imageSource = image.createImageSource(imageUri)
const pixelMap = await imageSource.createPixelMap()

// 识别文字
const results = await MLKitOCR.recognizeText(pixelMap)
// 返回: [{ text: 'La Sportiva', confidence: 0.9 }, ...]

// 释放资源
await MLKitOCR.release()
```

**依赖库**:
- `@kit.CoreVisionKit` - HarmonyOS 官方视觉能力库

---

### 3.4 文件工具类 (FileUtils.ets)

**文件位置**: `entry/src/main/ets/utils/FileUtils.ets`

**功能职责**:
- 文件复制、创建、读写操作
- 文件大小获取与格式化

**主要方法**:

| 方法 | 功能 |
|------|------|
| `copyFile(src, dest)` | 复制文件 |
| `fileExists(path)` | 检查文件是否存在 |
| `createDir(path)` | 创建目录 |
| `readFile(path)` | 读取文件内容为字符串 |
| `writeFile(path, content)` | 写入字符串到文件 |
| `getFileSize(path)` | 获取文件大小 |
| `formatFileSize(bytes)` | 格式化文件大小显示 |

**依赖库**:
- `@kit.CoreFileKit` - 文件操作
- `@kit.ArkTS` - TextEncoder/TextDecoder

---

### 3.5 权限工具类 (PermissionUtils.ets)

**文件位置**: `entry/src/main/ets/utils/PermissionUtils.ets`

**功能职责**:
- 应用权限检查与申请

**所需权限**:
```typescript
static readonly REQUIRED_PERMISSIONS: string[] = [
  'ohos.permission.READ_MEDIA',   // 读取媒体文件
  'ohos.permission.WRITE_MEDIA',  // 写入媒体文件
  'ohos.permission.INTERNET'      // 网络访问
]
```

**主要方法**:

| 方法 | 功能 |
|------|------|
| `checkPermission(permission)` | 检查单个权限 |
| `checkAllPermissions()` | 检查所有必需权限 |
| `requestPermissions(permissions, context)` | 申请权限 |
| `requestAllPermissions(context)` | 申请所有必需权限 |

**依赖库**:
- `@kit.AbilityKit` - 权限管理
- `@kit.BundleKit` - 应用信息获取

---

### 3.6 图片预览组件 (ImagePreview.ets)

**文件位置**: `entry/src/main/ets/components/ImagePreview.ets`

**功能职责**:
- 显示鞋盒标签图片
- 展示识别结果（品牌、款式、尺码）
- 支持展开/收起查看原始识别文本

**属性**:
```typescript
@Prop labelInfo: ShoeLabelInfo  // 标签信息数据
@State isExpanded: boolean      // 是否展开
```

**状态显示**:
| 状态值 | 显示文本 | 颜色 |
|--------|----------|------|
| 0 | 待识别 | #999999 |
| 1 | 识别中 | #2196F3 |
| 2 | 已识别 | #4CAF50 |
| 3 | 失败 | #F44336 |

---

### 3.7 应用入口 (EntryAbility.ets)

**文件位置**: `entry/src/main/ets/entryability/EntryAbility.ets`

**功能职责**:
- 管理应用生命周期
- 加载主页面

**生命周期回调**:
- `onCreate()` - 应用创建
- `onDestroy()` - 应用销毁
- `onWindowStageCreate()` - 窗口创建，加载 Index 页面
- `onWindowStageDestroy()` - 窗口销毁
- `onForeground()` - 应用进入前台
- `onBackground()` - 应用进入后台

---

## 四、数据流图

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  系统相册    │────▶│  Index.ets  │────▶│  图片列表    │
│ 选择图片    │     │  选择图片   │     │ LabelData[] │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │ 开始识别    │
                                        │ startRecognition()
                                        └──────┬──────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          │                          │
                    ▼                          ▼                          ▼
            ┌─────────────┐           ┌─────────────┐           ┌─────────────┐
            │  加载图片    │──────────▶│  ML Kit     │──────────▶│  提取信息    │
            │ loadPixelMap│           │ recognize   │           │ extractLabel│
            └─────────────┘           └─────────────┘           └──────┬──────┘
                                                                       │
                                                                       ▼
                                                              ┌─────────────┐
                                                              │  更新列表    │
                                                              │ updateItem  │
                                                              └──────┬──────┘
                                                                     │
                                                                     ▼
                                                              ┌─────────────┐
                                                              │  导出 CSV   │
                                                              │ exportCSV() │
                                                              └──────┬──────┘
                                                                     │
                                                                     ▼
                                                              ┌─────────────┐
                                                              │  CSV 文件   │
                                                              │ filesDir/   │
                                                              └─────────────┘
```

---

## 五、支持的攀岩鞋品牌

当前版本内置识别以下品牌：

| 品牌 | 国家 | 代表款式 |
|------|------|----------|
| La Sportiva | 意大利 | Solution, Theory, Skwama, Miura, Katana, TC Pro, Futura, Kataki, Otaki, Testarossa, Mantra, Genius |
| Scarpa | 意大利 | **DRAGO LV**, DRAGO, Instinct VS, Instinct VSR, Instinct, Chimera, Magos, Quantic, Vapor S, Vapor Lace, Vapor, Veloce, Mojito, Force V, Maestro, Boostic |
| Five Ten | 美国 | Anasazi, Hiangle, Verdon, Quantum, Street, Dragon, Moccasym |
| Butora | 韩国 |  |
| Evolv | 美国 | Shaman, Zenist, Defy, Gym |
| Mad Rock | 美国 | Drone, Redline |
| Black Diamond | 美国 | Zone, Momentum, Shadow |
| Red Chili | 德国 |  |
| Ocun | 捷克 |  |
| So iLL | 美国 |  |
| Tenaya | 西班牙 |  |
| Boreal | 西班牙 |  |
| Millet | 法国 |  |
| Kailas | 中国 |  |

---

## 六、开发环境

### 6.1 必要条件
- **DevEco Studio**: 4.0 Release 或更高版本
- **HarmonyOS SDK**: API 12
- **Node.js**: 14.x 或更高版本

### 6.2 运行设备
- 华为手机/平板（HarmonyOS 4.0+）
- DevEco Studio 模拟器

### 6.3 构建命令
```bash
# 安装依赖
npm install

# 构建项目
hvigor build

# 构建 HAP 包
hvigor assembleHap
```

---

## 七、API 依赖清单

| 模块 | 依赖库 | 用途 |
|------|--------|------|
| OCRUtils | `@ohos.file.fs` | 文件系统操作 |
| OCRUtils | `@ohos.multimedia.image` | 图片处理 |
| OCRUtils | `@ohos.app.ability.common` | 应用上下文 |
| MLKitOCR | `@kit.CoreVisionKit` | 文字识别 |
| FileUtils | `@kit.CoreFileKit` | 文件操作 |
| FileUtils | `@kit.ArkTS` | 编解码 |
| PermissionUtils | `@kit.AbilityKit` | 权限管理 |
| PermissionUtils | `@kit.BundleKit` | 应用信息 |
| Index | `@ohos.file.picker` | 相册选择器 |
| Index | `@ohos.prompt` | Toast 提示 |

---

## 八、注意事项

1. **图片格式**: 支持 JPG、PNG 等常见格式
2. **识别精度**: 建议在光线充足的环境下拍摄标签
3. **文件存储**: CSV 文件保存在应用私有目录 `filesDir`，可通过设备文件管理器访问
4. **权限申请**: 首次使用需要授予存储权限才能选择图片

---

## 九、扩展开发

### 9.1 添加新品牌识别
在 `OCRUtils.ets` 中修改 `extractBrand()` 函数的 brands 数组：
```typescript
const brands = [
  'La Sportiva', 'Scarpa', 
  'New Brand'  // 添加新品牌
]
```

### 9.2 添加新款式识别
在 `extractModel()` 函数的 modelPatterns 数组中添加正则表达式：
```typescript
const modelPatterns = [
  /Solution\s+Comp/i,
  /New Model/i  // 添加新款式
]
```

### 9.3 自定义 CSV 格式
修改 `generateCSV()` 方法中的 headers 和 rows 映射逻辑。

---

**文档版本**: 1.0  
**更新日期**: 2026/3/29

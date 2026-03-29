# 攀岩鞋标签识别 (Climbing Shoe Label Reader)

鸿蒙HarmonyOS应用，用于识别攀岩鞋盒上的标签信息，自动提取品牌、款式、尺码，并导出CSV表格。

## 开发环境

- DevEco Studio 4.0 Release 或更高版本
- HarmonyOS SDK API 11
- ArkTS语言

## 功能特点

- 📷 **批量图片选择** - 支持一次选择多张鞋盒图片（最多50张）
- 🔍 **智能OCR识别** - 自动识别标签上的文字信息
- 📊 **信息提取** - 自动提取品牌、款式、尺码
- 📁 **CSV导出** - 一键导出所有识别结果为CSV表格
- 🎯 **多品牌支持** - 内置常见攀岩鞋品牌识别库

## 支持的攀岩鞋品牌

- La Sportiva (拉思珀蒂瓦) - Solution, Theory, Skwama, Miura 等
- **Scarpa (斯卡帕)** - DRAGO LV, DRAGO, Instinct, Chimera, Vapor 等
- Five Ten - Hiangle, Anasazi, Verdon 等
- Butora
- Mad Rock
- Red Chili
- Boreal
- Evolv
- Tenaya (天娜)
- Ocun
- Black Diamond (黑钻)
- Unparallel
- Saltic
- Millet

## 项目结构

```
label_reader/
├── entry/src/main/ets/
│   ├── entryability/EntryAbility.ets    # 应用入口
│   ├── pages/Index.ets                   # 主页面
│   ├── components/ImagePreview.ets       # 图片预览组件
│   └── utils/
│       ├── OCRUtils.ets                  # OCR核心工具
│       ├── MLKitOCR.ets                  # ML Kit集成示例
│       ├── FileUtils.ets                 # 文件工具
│       └── PermissionUtils.ets           # 权限管理
├── entry/src/main/resources/base/        # 资源文件
├── build-profile.json5                   # 工程构建配置
├── hvigorfile.ts                         # 工程编译脚本
├── entry/build-profile.json5             # 模块构建配置
├── entry/oh-package.json5                # 模块依赖配置
└── entry/obfuscation-rules.txt           # 混淆规则
```

## 如何运行

1. 使用 DevEco Studio 4.0+ 打开本项目
2. 等待自动同步完成（Sync）
3. 连接鸿蒙设备或启动模拟器
4. 点击运行按钮 (Run)

## 使用说明

1. **选择图片** - 点击"选择图片"按钮，从相册中选择鞋盒标签图片
2. **开始识别** - 点击"开始识别"按钮，应用会自动识别所有图片
3. **查看结果** - 在列表中查看每张图片的识别结果
4. **导出CSV** - 点击"导出CSV"按钮，将结果保存为表格文件

## 集成OCR服务

当前版本使用模拟OCR数据。实际应用中需要接入OCR服务：

### 方案1: 华为ML Kit（推荐）

在 `entry/oh-package.json5` 中添加依赖：
```json
{
  "dependencies": {
    "@kit/VisionKit": "^1.0.0"
  }
}
```

然后修改 `OCRUtils.ets` 中的 `recognizeText` 方法：
```typescript
import { textRecognition } from '@kit/VisionKit'

static async recognizeText(imageUri: string): Promise<OCRResult[]> {
  // 加载图片为PixelMap
  const pixelMap = await this.loadPixelMap(imageUri)
  
  // 调用ML Kit识别
  const result = await textRecognition.recognizeText(pixelMap, {
    OCRType: textRecognition.OCRType.NORMAL
  })
  
  return result.blocks.map(block => ({
    text: block.text,
    confidence: block.score || 0.9
  }))
}
```

### 方案2: 第三方OCR API

参考 `MLKitOCR.ets` 中的 `BaiduOCR` 或 `TencentOCR` 类。

## 许可证

MIT License

## 作者

创建于 2026/3/27

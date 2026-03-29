# OCR集成指南

本文档介绍如何为本项目集成实际的OCR服务。

## 方案对比

| 方案 | 优点 | 缺点 | 适用场景 |
|------|------|------|----------|
| 华为ML Kit | 离线识别、速度快、免费 | 需要集成SDK | 推荐方案 |
| 百度OCR | 识别准确率高 | 需要联网、收费 | 在线识别 |
| 腾讯OCR | 识别准确率高 | 需要联网、收费 | 在线识别 |
| Tesseract | 完全离线、免费 | 集成复杂、体积大 | 离线场景 |

## 方案1: 华为ML Kit (推荐)

### 1. 添加依赖

在 `entry/oh-package.json5` 中添加:

```json
{
  "dependencies": {
    "@kit/VisionKit": "^1.0.0"
  }
}
```

### 2. 修改 OCRUtils.ets

```typescript
import { textRecognition } from '@kit/VisionKit';
import image from '@ohos.multimedia.image';

export class OCRUtils {
  static async recognizeText(imageUri: string): Promise<OCRResult[]> {
    // 1. 加载图片为PixelMap
    const pixelMap = await this.loadPixelMap(imageUri);
    
    // 2. 调用ML Kit识别
    const result = await textRecognition.recognizeText(pixelMap, {
      OCRType: textRecognition.OCRType.NORMAL
    });
    
    // 3. 转换结果
    return result.blocks.map(block => ({
      text: block.text,
      confidence: block.score || 0.9
    }));
  }
  
  private static async loadPixelMap(uri: string): Promise<image.PixelMap> {
    // 实现图片加载逻辑
    // ...
  }
}
```

### 3. 配置混淆规则

在 `entry/proguard-rules.pro` 中添加:

```
-keep class com.huawei.hms.mlsdk.** { *; }
```

## 方案2: 百度OCR API

### 1. 申请API Key

访问 [百度AI开放平台](https://ai.baidu.com/) 申请:
- API Key
- Secret Key

### 2. 修改 MLKitOCR.ets

在 `BaiduOCR` 类中填入你的密钥:

```typescript
export class BaiduOCR {
  private static API_KEY = '你的API Key';
  private static SECRET_KEY = '你的Secret Key';
  // ...
}
```

### 3. 网络权限

确保在 `module.json5` 中已申请网络权限。

## 方案3: Tesseract OCR (WASM)

### 1. 下载Tesseract.js

```bash
npm install tesseract.js
```

### 2. 集成到项目

```typescript
import Tesseract from 'tesseract.js';

export class TesseractOCR {
  static async recognizeText(imageUri: string): Promise<OCRResult[]> {
    const result = await Tesseract.recognize(
      imageUri,
      'chi_sim+eng',  // 中文简体+英文
      { logger: m => console.log(m) }
    );
    
    return result.data.lines.map(line => ({
      text: line.text,
      confidence: line.confidence / 100
    }));
  }
}
```

## 模型训练（可选）

如果你的鞋盒标签有特殊格式，可以训练专用OCR模型:

1. 收集样本图片（至少100张）
2. 使用 [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR) 训练
3. 导出模型并在端侧部署

## 测试建议

1. **图片质量** - 确保图片清晰、光线充足
2. **拍摄角度** - 尽量正面拍摄，避免倾斜
3. **文字大小** - 确保标签文字在图片中足够大
4. **多品牌测试** - 测试不同品牌的鞋盒标签

## 常见问题

### Q: 识别准确率不高怎么办？
A: 
- 检查图片清晰度
- 调整OCR参数
- 针对特定品牌优化识别规则

### Q: 离线环境下如何使用？
A: 
- 使用华为ML Kit（支持离线）
- 或集成Tesseract WASM

### Q: 如何处理多种语言？
A:
- 设置OCR语言参数
- 或者使用多语言混合识别模式

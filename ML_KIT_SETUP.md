# ML Kit 集成说明

## 配置步骤

### 1. 确保 Gradle 配置正确

项目已配置 `build.gradle` 和 `entry/build.gradle` 文件。

### 2. 配置华为开发者账号

1. 访问 [华为开发者联盟](https://developer.huawei.com/)
2. 注册/登录账号
3. 创建项目并添加应用
4. 获取 `agconnect-services.json` 文件

### 3. 替换配置文件

将下载的 `agconnect-services.json` 文件替换 `entry/agconnect-services.json`

### 4. 启用ML Kit服务

在华为开发者控制台中，确保为项目启用了 **ML Kit** 服务。

### 5. 重新构建项目

```bash
# 清理构建
cd entry
gradle clean

# 重新构建
gradle build
```

## 代码说明

### OCRUtils.ets
- `recognizeText()` - 主识别方法，先尝试ML Kit，失败则降级到模拟数据
- `loadImageAsPixelMap()` - 将图片URI转换为PixelMap供ML Kit使用
- `extractLabelInfo()` - 从OCR结果提取鞋标信息
- `generateCSV()` - 生成CSV文件内容

### MLKitOCR.ets
- `recognizeText()` - ML Kit包装类，使用MLTextAnalyzer进行识别
- 包含降级机制，ML Kit失败时返回模拟数据

## 注意事项

1. **API限制**：免费版ML Kit有每日调用次数限制
2. **网络要求**：首次使用需要联网下载模型
3. **权限**：确保应用有存储和网络权限

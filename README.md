# 鞋盒标签识别器 (Shoebox Label Reader)

一款基于 HarmonyOS 的智能鞋盒标签识别应用，专为攀岩鞋库存管理设计。自动识别鞋盒标签上的品牌、款式、鞋型和尺码信息，支持批量处理并导出 CSV 报表。

> **English Version**: [README_EN.md](./README_EN.md)

---

## ✨ 功能特性

| 功能 | 描述 |
|------|------|
| 📷 **批量图片识别** | 支持同时选择多张鞋盒图片（最多 50 张）进行批量识别 |
| 🔍 **智能 OCR 识别** | 基于 Core Vision Kit 文字识别能力，自动提取标签文字 |
| 🏷️ **信息智能提取** | 自动识别品牌、款式、鞋型（宽/窄版）、尺码 |
| 📊 **网格分割支持** | 支持 1×1 到 3×3 网格分割，一次识别多个鞋盒 |
| 📁 **CSV 导出** | 一键导出所有识别结果为 CSV 表格，支持排序 |
| 🎨 **现代化 UI** | 深色主题、极简设计，操作流畅直观 |

---

## 🚀 技术栈

- **框架**: HarmonyOS API 12, ArkTS
- **UI**: ArkUI 声明式 UI
- **OCR**: Core Vision Kit (ML Kit) 文字识别
- **构建工具**: Hvigor

---

## 🏔️ 支持的攀岩鞋品牌

| 品牌 | 代表款式 |
|------|---------|
| **La Sportiva** | Solution, Theory, Skwama, Miura, Katana |
| **Scarpa** | DRAGO, Instinct, Chimera, Vapor, Boostic |
| **Five Ten** | Hiangle, Anasazi, Verdon |
| **Butora** | LIBRA VC, KOMET, ACRO, GOMI, ALTURA |
| **So iLL** | Torque, Step, Free Range |
| **Evolv** | Shaman, Zenist |
| **Mad Rock** | Drone, Redline |
| **Tenaya** | Oasi, Tarifa |
| **Black Diamond** | Zone, Momentum |
| **Ocun** | Bullit, Rebel |
| **Boreal** | Ninja, Joker |
| ... | 持续更新中 |

---

## 📁 项目结构

```
label_reader/
├── entry/src/main/ets/
│   ├── entryability/EntryAbility.ets    # 应用入口
│   ├── pages/Index.ets                   # 主页面（UI 逻辑）
│   ├── components/ImagePreview.ets       # 图片预览组件
│   └── utils/
│       ├── OCRUtils.ets                  # OCR 核心工具（识别+提取）
│       ├── MLKitOCR.ets                  # Core Vision Kit 封装
│       ├── FileUtils.ets                 # 文件操作工具
│       └── PermissionUtils.ets           # 权限管理
├── entry/src/main/resources/             # 资源文件
├── AppScope/                             # 应用级配置
├── build-profile.json5                   # 工程构建配置
├── hvigorfile.ts                         # 编译脚本
└── oh-package.json5                      # 依赖配置
```

---

## 🛠️ 安装与运行

### 环境要求

- DevEco Studio 4.0 Release 或更高版本
- HarmonyOS SDK API 12
- ArkTS 语言支持

### 运行步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/hxnnosUbeyi/shoebox-label-reader.git
   cd shoebox-label-reader
   ```

2. **打开项目**
   - 使用 DevEco Studio 打开项目文件夹
   - 等待自动同步完成（Sync）

3. **运行应用**
   - 连接鸿蒙设备或启动模拟器
   - 点击运行按钮 (Run)

---

## 📖 使用指南

### 1. 选择图片
点击底部「选择图片」按钮，从相册中选择鞋盒标签照片。

### 2. 设置网格（可选）
如果图片包含多个鞋盒，点击网格按钮（1×1, 1×2, 2×2, 3×3）进行分割。

### 3. 开始识别
点击「开始识别」按钮，应用会自动识别所有图片。

### 4. 查看结果
识别结果将显示在列表中，包括：
- **品牌**: 如 Butora, La Sportiva
- **款式**: 如 KOMET, LIBRA VC
- **鞋型**: NARROW（窄版）/ WIDE（宽版）
- **尺码**: 如 EUR 42

### 5. 导出 CSV
点击「导出 CSV」按钮，将结果保存为表格文件，支持通过邮件或即时通讯分享。

---

## 🔧 核心功能实现

### OCR 识别流程

```
用户图片 → 网格分割（可选）→ Core Vision Kit OCR → 
文字提取 → 品牌/款式/尺码解析 → 结果显示
```

### 智能识别策略

1. **双向识别**: 正序 + 倒序文字识别，处理倒置标签
2. **款式推断品牌**: 若未识别品牌，根据款式自动推断
3. **近似匹配**: 支持 OCR 误识别的模糊匹配（如 NABROW → NARROW）

### 关键代码示例

```typescript
// 从 OCR 结果提取鞋标信息
function extractLabelInfo(results: OCRResult[]): ShoeLabelInfo {
  return {
    brand: extractBrand(results),      // 品牌识别
    model: extractModel(results),      // 款式识别
    width: extractWidth(results),      // 鞋型识别（NARROW/WIDE）
    size: extractSize(results)         // 尺码提取
  }
}
```

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 添加新品牌支持

在 `OCRUtils.ets` 中编辑以下映射表：

```typescript
const brandMap: Record<string, string> = {
  'newbrand': 'New Brand',
  // ...
}
```

---

## 📄 许可证

MIT License

---

## 👤 作者

创建于 2026/3/27

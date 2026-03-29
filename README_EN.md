# Shoebox Label Reader

An intelligent shoebox label recognition application based on HarmonyOS, designed for climbing shoe inventory management. Automatically recognizes brand, model, width type, and size information from shoebox labels, supports batch processing and CSV export.

> **中文版**: [README.md](./README.md)

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 📷 **Batch Image Recognition** | Supports selecting multiple shoebox images (up to 50) for batch recognition |
| 🔍 **Smart OCR Recognition** | Based on Core Vision Kit text recognition, automatically extracts label text |
| 🏷️ **Intelligent Information Extraction** | Auto-recognizes brand, model, width type (NARROW/WIDE), and size |
| 📊 **Grid Split Support** | Supports 1×1 to 3×3 grid splitting for multiple shoeboxes in one image |
| 📁 **CSV Export** | One-click export of all recognition results to CSV spreadsheet with sorting |
| 🎨 **Modern UI** | Dark theme, minimalist design, smooth and intuitive operation |

---

## 🚀 Tech Stack

- **Framework**: HarmonyOS API 12, ArkTS
- **UI**: ArkUI Declarative UI
- **OCR**: Core Vision Kit (ML Kit) Text Recognition
- **Build Tool**: Hvigor

---

## 🏔️ Supported Climbing Shoe Brands

| Brand | Representative Models |
|-------|----------------------|
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
| ... | Continuously updating |

---

## 📁 Project Structure

```
label_reader/
├── entry/src/main/ets/
│   ├── entryability/EntryAbility.ets    # Application entry
│   ├── pages/Index.ets                   # Main page (UI logic)
│   ├── components/ImagePreview.ets       # Image preview component
│   └── utils/
│       ├── OCRUtils.ets                  # OCR core utilities (recognition + extraction)
│       ├── MLKitOCR.ets                  # Core Vision Kit wrapper
│       ├── FileUtils.ets                 # File operation utilities
│       └── PermissionUtils.ets           # Permission management
├── entry/src/main/resources/             # Resource files
├── AppScope/                             # Application-level configuration
├── build-profile.json5                   # Project build configuration
├── hvigorfile.ts                         # Build script
└── oh-package.json5                      # Dependency configuration
```

---

## 🛠️ Installation & Running

### Requirements

- DevEco Studio 4.0 Release or higher
- HarmonyOS SDK API 12
- ArkTS language support

### Running Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/hxnnosUbeyi/shoebox-label-reader.git
   cd shoebox-label-reader
   ```

2. **Open the project**
   - Open the project folder in DevEco Studio
   - Wait for automatic synchronization (Sync) to complete

3. **Run the application**
   - Connect a HarmonyOS device or start the emulator
   - Click the Run button

---

## 📖 Usage Guide

### 1. Select Images
Click the "Select Images" button at the bottom and choose shoebox label photos from the album.

### 2. Set Grid (Optional)
If the image contains multiple shoeboxes, click the grid buttons (1×1, 1×2, 2×2, 3×3) to split.

### 3. Start Recognition
Click the "Start Recognition" button, and the app will automatically recognize all images.

### 4. View Results
Recognition results will be displayed in the list, including:
- **Brand**: e.g., Butora, La Sportiva
- **Model**: e.g., KOMET, LIBRA VC
- **Width**: NARROW / WIDE
- **Size**: e.g., EUR 42

### 5. Export CSV
Click the "Export CSV" button to save results as a spreadsheet file, which can be shared via email or instant messaging.

---

## 🔧 Core Functionality Implementation

### OCR Recognition Flow

```
User Image → Grid Split (Optional) → Core Vision Kit OCR → 
Text Extraction → Brand/Model/Size Parsing → Result Display
```

### Smart Recognition Strategy

1. **Bidirectional Recognition**: Normal + reversed text recognition to handle inverted labels
2. **Brand Inference from Model**: If brand is not recognized, automatically infer from model
3. **Fuzzy Matching**: Supports fuzzy matching for OCR misrecognitions (e.g., NABROW → NARROW)

### Key Code Example

```typescript
// Extract shoe label info from OCR results
function extractLabelInfo(results: OCRResult[]): ShoeLabelInfo {
  return {
    brand: extractBrand(results),      // Brand recognition
    model: extractModel(results),      // Model recognition
    width: extractWidth(results),      // Width type recognition (NARROW/WIDE)
    size: extractSize(results)         // Size extraction
  }
}
```

---

## 🤝 Contributing

Issues and Pull Requests are welcome!

### Adding New Brand Support

Edit the mapping table in `OCRUtils.ets`:

```typescript
const brandMap: Record<string, string> = {
  'newbrand': 'New Brand',
  // ...
}
```

---

## 📄 License

MIT License

---

## 👤 Author

Created on 2026/3/27

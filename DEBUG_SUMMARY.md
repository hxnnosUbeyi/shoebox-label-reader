# 鸿蒙项目 Debug 重点总结

## 一、工程配置问题

### 1. SDK版本格式
```json5
// 错误
"compileSdkVersion": 11

// 正确 - HarmonyOS使用字符串格式
"compatibleSdkVersion": "6.0.2(22)"
"targetSdkVersion": "6.0.2(22)"
```

### 2. AppScope目录（必需）
```
label_reader/
├── AppScope/                      # 应用级配置，必须有
│   ├── app.json5                  # 必须包含icon和label
│   └── resources/base/media/
│       └── app_icon.png           # 应用图标，必需
```

**app.json5关键配置：**
```json5
{
  "app": {
    "bundleName": "com.example.xxx",
    "icon": "$media:app_icon",      // 必需
    "label": "$string:app_name",    // 必需
    "apiReleaseType": "Release1"    // 注意是Release1不是Release
  }
}
```

---

## 二、资源文件规范

### 1. 资源目录限制
`resources/base/`下**只能**有三种目录：
- `element/` - 字符串、颜色定义
- `media/` - 图片、音频
- `profile/` - 配置文件

**常见错误：**
```
graphic/        ❌ 非法目录名
theme.json      ❌ 不能直接放base下，要放profile/
```

### 2. 资源命名冲突
**不能**在同目录下有同名资源（忽略扩展名）：
```
media/
├── icon.json   ❌
└── icon.png    ❌ 冲突！
```

**解决：** 删除icon.json，或重命名为app_icon.png

---

## 三、ArkTS语法限制

### 1. 禁止any类型
```typescript
// ❌ 错误
let data: any = ...

// ✅ 正确
interface DataType {
  id: number
  name: string
}
let data: DataType = { id: 1, name: '' }
```

### 2. 禁止对象展开运算符
```typescript
// ❌ 错误
const merged = { ...obj1, ...obj2 }
this.list = [...this.list, newItem]

// ✅ 正确
const merged = Object.assign({}, obj1, obj2)
this.list.push(newItem)
this.list.splice(index, 1, item)
```

### 3. 状态类型建议
```typescript
// ❌ 不推荐（字符串联合类型有兼容性问题）
status: 'pending' | 'success' | 'failed'

// ✅ 推荐（使用数字常量）
const STATUS_PENDING = 0
const STATUS_SUCCESS = 1
status: number
```

### 4. 类方法中的this
```typescript
// ❌ 错误 - 独立函数中使用this
private extractBrand() {
  return this.brand    // 报错！
}

// ✅ 正确 - 使用类名调用
private static extractBrand() {
  return OCRUtils.brands
}
```

---

## 四、模块导入路径

### 推荐方案（根据SDK版本选择）

| SDK版本 | 推荐路径 | 说明 |
|---------|----------|------|
| API 11+ | `@ohos.xxx` | 稳定兼容 |
| API 12+ | `@kit.xxx` | 新Kit命名，但可能未安装 |

### 实际可用的@ohos导入
```typescript
// 文件选择器
import picker from '@ohos.file.picker'

// 文件系统
import fs from '@ohos.file.fs'

// 提示框
import prompt from '@ohos.prompt'

// 工具
import util from '@ohos.util'

// 上下文
import common from '@ohos.app.ability.common'

// 错误类型
import { BusinessError } from '@ohos.base'
```

**注意：** `@kit.xxx` 不是通过npm安装的，是SDK内置模块，如果Sync报错找不到，说明SDK未安装该Kit，应改回`@ohos`。

---

## 五、CSV文件保存问题

### 问题
应用私有目录`/data/app/.../files/`用户无法通过文件管理器访问

### 解决思路
1. **应用内预览** - 添加"预览CSV"按钮，显示内容供复制
2. **保存到公共目录** - 需要申请存储权限，且HarmonyOS有严格限制
3. **分享功能** - 通过系统分享发送到微信/邮件

**推荐方案：** 应用内预览 + 文本可复制

---

## 六、调试技巧

### 1. 查看日志
```typescript
console.info('调试信息')
console.error('错误:', JSON.stringify(error))
```

### 2. 清理缓存
```bash
hvigor clean
```

### 3. 常见错误码速查

| 错误码 | 原因 | 解决 |
|--------|------|------|
| 11211101 | 资源文件位置错误 | theme.json移到profile/ |
| 11211104 | 非法资源目录名 | graphic→media |
| 11211117 | 资源命名冲突 | 删除icon.json |
| 11211120 | 资源未定义 | 添加app_icon.png |
| 00303038 | 缺少必需属性 | app.json5添加icon |
| 10605008 | 使用any类型 | 改为显式类型 |
| 10605093 | 独立函数使用this | 改为类名调用或static |

---

## 七、开发流程建议

1. **创建项目后先检查：**
   - AppScope是否存在
   - app_icon.png是否添加
   - build-profile.json5 SDK版本格式

2. **添加资源时注意：**
   - 图片放media/
   - 配置放profile/
   - 字符串放element/

3. **写代码时注意：**
   - 所有变量声明类型
   - 不用对象展开运算符
   - 类方法使用static或类名调用

4. **调试时使用：**
   - console.info打印路径
   - 应用内预览查看内容
   - DevEco Studio Logcat查看日志

---

*总结日期：2026/3/27*
*项目：label_reader*

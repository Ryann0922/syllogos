# Syllogos

📚 **Syllogos** 是一款功能强大的 Flutter 应用，专为大学综合测评信息管理而设计。采用 Material Design 3 Expressive 设计语言，提供现代化的用户界面和流畅的交互体验。

![Version](https://img.shields.io/badge/version-1.3.0-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.12+-green)
![License](https://img.shields.io/badge/license-MIT-brightgreen)

## ✨ 主要功能

### 📖 条目管理
- **条目分类存储**：支持按类别组织条目，灵活的分类 TabBar 导航
- **条目详情编辑**：完整的条目信息编辑界面，支持日期、分数、所属类别、结清状态等
- **证明文件管理**：支持添加、删除、预览多种格式的证明文件（图片、文档等）
- **缩略图预览**：条目列表显示图片缩略图，支持点击放大预览

### 📊 统计分析
- **学年统计**：自动计算当前学年的统计数据
- **达标指示**：直观展示各类别的达标情况（绿色达标/红色未达标）
- **进度条追踪**：实时显示达标进度百分比
- **多维统计**：条目计数、总分、平均分、目标分对比展示

### ⚙️ 个性化设置
- **动态取色**：支持 Android 12+ 从系统壁纸自动提取主色
- **色盘选择**：10 种预设颜色可选（靛蓝、青绿、粉红等）
- **主题切换**：支持跟随系统、亮色、暗色三种主题模式
- **学年配置**：灵活设置学年起始月份
- **WebDAV 同步**：配置 WebDAV 服务器实现云端备份与恢复

### 💾 数据导出
- **ZIP 打包导出**：将所有数据和证明文件打包为 ZIP 格式
- **目录结构**：
  ```
  export.zip
  ├── classes/
  │   └── 类别信息 JSON
  ├── entries/
  │   └── 条目信息 JSON + 证明文件
  └── proofs/
      └── 所有证明文件
  ```
- **云端上传**：直接上传到配置的 WebDAV 服务器

## 🚀 快速开始

### 环境要求
- Flutter 3.12.0+
- Dart 3.12.0+
- Android SDK 34+ （用于构建 APK）

### 安装依赖
```bash
flutter pub get
```

### 构建应用
```bash
# 开发版本
flutter run

# 发布版本 APK
flutter build apk --release

# 输出路径
build/app/outputs/flutter-apk/app-release.apk
```

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 🎨 设计原则

本项目严格遵循 **Google Material Design 3** 规范，包括：
- **Color System**: 采用 `ColorScheme.fromSeed` 实现动态取色和一致的色彩系统
- **Typography**: 使用系统推荐的文字样式（titleLarge、bodyMedium 等）
- **Components**: M3 标准组件（Card、Chip、ProgressIndicator 等）
- **Expressive Design**: 使用 DottedBorder 等装饰元素实现表达式设计语言

## 💳 Credits

感谢以下开源项目和设计指南的支持：

### 核心依赖
- **hive** & **hive_flutter**: 高效的本地存储解决方案
- **file_picker**: 跨平台文件选择功能
- **archive**: ZIP 文件打包和解包
- **webdav_client**: WebDAV 云端同步支持
- **dynamic_color**: Android 12+ 动态取色支持

### 设计参考
- [Google Material Design 3](https://m3.material.io/) - 现代化 UI 设计规范
- [Flutter Material 3 文档](https://docs.flutter.dev/ui/material) - Flutter M3 实现指南
- [Material Design 3 颜色系统](https://m3.material.io/styles/color/the-color-system/color-roles) - 颜色设计原则

### 开发工具
- **Flutter 3.12.0+** - 跨平台应用框架
- **Dart 3.12.0+** - 编程语言
- **VS Code** - 开发环境

---

**版本历史**
- **v1.3.0** (2026-05-21): 修复保存/编辑/统计页 Bug，升级 M3 Expressive 设计
- **v1.2.1** (2026-05-21): UI 改进，强制日期选择，分类拖动排序
- **v1.2.0**: 分数上限功能，条目详情优化
- **v1.1.0**: 多选功能，搜索和筛选
- **v1.0.0**: 初始版本，基础功能完整

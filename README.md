# Meeting Note

一个基于Flutter的多模型实时会议记录系统，支持语音识别、智能摘要和多平台部署。

## 🌟 项目特点

- **实时音频录制与转录**：支持实时语音识别，将会议内容转换为文字
- **多参与者会议支持**：自动识别不同发言者，区分发言内容
- **AI智能会议摘要**：利用大语言模型自动生成会议摘要和纪要
- **数据统计与分析**：提供会议数据统计和分析功能
- **跨平台支持**：一套代码支持Web、桌面和移动端
- **多模型支持**：可配置多种ASR和LLM模型

## 🖥️ 支持平台

- **Web**：可在浏览器中直接运行
- **桌面端**：Linux、Windows、macOS
- **移动端**：Android、iOS

## 🚀 快速开始

### 环境要求

- Flutter 3.10 或更高版本
- Dart 3.0 或更高版本
- 支持的IDE（如Android Studio、VS Code等）

### 安装依赖

```bash
flutter pub get
```

### 运行项目

#### 开发模式运行

```bash
# 运行在Chrome浏览器中
flutter run -d chrome

# 运行在Linux桌面
flutter run -d linux

# 运行在Android设备
flutter run -d android
```

### 构建项目

#### Web构建
```bash
# 构建Web Release版本
flutter build web --release

# 构建Web Debug版本
flutter build web --debug
```

#### 桌面端构建
```bash
# Linux
flutter config --enable-linux-desktop
flutter build linux

# Windows
flutter config --enable-windows-desktop
flutter build windows

# macOS
flutter config --enable-macos-desktop
flutter build macos
```

#### 移动端构建
```bash
# Android APK
flutter build apk

# iOS (需要macOS环境)
flutter build ios
```

## 🛠️ 技术架构

### 核心技术栈

- **Flutter**：跨平台UI框架
- **flutter_webrtc**：WebRTC支持，用于音频捕获
- **sqflite**：本地数据库存储
- **dio**：网络请求库
- **provider**：状态管理

### 主要功能模块

1. **音频录制模块**
   - 支持WebRTC音频捕获
   - 跨平台音频设备适配
   - 实时音频流处理

2. **语音识别模块**
   - 支持阿里云ASR等多模型
   - 实时语音转文字
   - 多语言支持

3. **会议管理模块**
   - 会议创建、编辑、删除
   - 会议列表展示
   - 会议详情查看

4. **AI摘要模块**
   - 基于大语言模型的摘要生成
   - 支持多种摘要模板
   - 会议问答功能

5. **数据存储模块**
   - 本地SQLite数据库
   - 会议数据持久化
   - 数据导出功能

## 📦 GitHub Actions自动化

本项目包含完整的GitHub Actions工作流，支持：

- 自动为所有平台构建Release和Debug版本
- 自动创建GitHub Release并上传构建产物
- 支持Web、Linux、Windows、macOS、Android、iOS所有平台

工作流文件：[.github/workflows/build_and_release.yml](.github/workflows/build_and_release.yml)

## 📁 项目结构

```
lib/
├── models/              # 数据模型
├── providers/           # 状态管理
├── screens/             # 页面组件
├── services/            # 业务逻辑服务
├── utils/               # 工具类
└── widgets/             # 自定义组件
```

## ⚙️ 配置说明

项目配置文件位于 `assets/config.json`，可配置：

- ASR模型参数
- 摘要模型参数
- 存储配置

## 🤝 贡献指南

欢迎提交Issue和Pull Request来改进项目！

1. Fork项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启Pull Request

## 📄 许可证

本项目采用MIT许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 📧 联系方式

项目维护者 - [@laochenfei233](https://github.com/laochenfei233)

项目链接: [https://github.com/laochenfei233/meeting_note](https://github.com/laochenfei233/meeting_note)
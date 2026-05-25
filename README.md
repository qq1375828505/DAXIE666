# 网文写作IDE - Android

> 🚀 完全单机运行的网文写作IDE Android版。AI写作辅助 · 番茄风格预设 · 小说记忆系统 · 多模型支持

[![GitHub Release](https://img.shields.io/github/v/release/qq1375828505/DAXIE666)](https://github.com/qq1375828505/DAXIE666/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.29+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📥 下载安装

最新版：**V1.3.3** — [直接下载 APK](https://github.com/qq1375828505/DAXIE666/releases/download/v1.3.3/novel-ide-android-v1.3.3.apk)

> 支持 Android 6.0+（minSdk 23），无需注册，安装即用。

## ✨ 功能特色

### 📝 写作核心
- **智能编辑器** — TextField 高性能方案，支持 Undo/Redo、查找替换、语音输入
- **自动保存** — 1.5秒延迟保存 + dispose 强制保存，绝不丢稿
- **防丢稿机制** — 3分钟自动快照，保留20个历史版本，一键恢复
- **字数统计** — 实时字数、每日统计图表、连续打卡、达标通知
- **性能保护** — 单章超过10000/15000字自动提醒拆章

### 🤖 AI 写作助手
- **AI 对话窗口** — 底部导航独立Tab，多会话管理，自动上下文压缩（40条消息触发）
- **AI 续写/润色/起标题** — 编辑器底部抽屉，选中文字右键即可调用
- **爽点检查/水文检测/全文审查** — 一键生成专业审查报告
- **多模型支持** — OpenAI 兼容协议 + Anthropic 协议，支持添加和切换多个 AI 模型
- **测试连接** — 配置后一键测试 API 连通性和模型可用性
- **25个番茄预设** — 都市/玄幻/穿越/悬疑/女频，覆盖2026年爆款风格
- **自定义 Agent** — 创建专属写作 Agent，支持从文件导入

### 📚 资料管理（8种类型）
- 角色卡、设定卡、地点、势力、道具、伏笔、参考资料
- **小说记忆文件** — 自动更新，AI 对话时自动注入上下文

### 📦 导入导出
- **保存到本地** — 导出 ZIP 直接保存到手机，不依赖分享面板
- **分享功能** — 通过 QQ/微信 等快速分享作品
- **勾选式导出** — 章节自由选择，10种内容类型可勾选（章节、角色、设定、伏笔等）
- **导入 .novelpack** — 一键导入完整作品包

### 🔒 隐私与安全
- **完全单机运行** — 不依赖后端服务，数据全部本地存储
- **API Key 加密** — 使用 Android Keystore 安全存储
- **三级隐私模式** — 脱敏处理，保护创作隐私
- **19项权限声明** — 运行时授权，透明可控

## 🏗️ 技术栈

| 技术 | 用途 |
|------|------|
| Flutter 3.29+ / Dart | 跨平台 UI 框架 |
| Riverpod | 状态管理 |
| sqflite | 本地数据库（7张表） |
| Hive | 配置存储 |
| flutter_secure_storage | API Key 加密 |
| Dio | HTTP 请求（多协议支持） |
| fl_chart | 统计图表 |
| archive | ZIP 压缩包 |
| share_plus | 系统分享 |
| file_picker | 文件选择 |
| speech_to_text | 语音输入 |
| permission_handler | 运行时权限 |

## 📂 项目结构
```
lib/
├── main.dart
├── core/                      # 常量、主题、路由
├── data/
│   ├── models/                # 数据模型（Freezed）
│   ├── datasources/           # 数据库(v3)、文件、安全存储
│   ├── repositories/          # 数据仓库（含统计）
│   ├── presets/               # 25个番茄预设
│   └── services/              # AI服务、记忆、配置、统计
├── presentation/
│   └── pages/
│       ├── writing/           # 编辑器（含导出按钮）
│       ├── works/             # 作品列表、导出、长按菜单
│       ├── outline/           # 大纲（含主线大纲编辑+导出）
│       ├── materials/         # 资料管理（8Tab + 设置按钮+导出）
│       ├── profile/           # 设置页（AI配置、统计、配置文件）
│       ├── ai/                # AI对话、精修、全文审查
│       └── tomato/            # 番茄报告页、Agent市场
├── presentation/state/        # Riverpod Providers
└── docs/                      # 技术文档
```

## 🛠️ 开发运行

```bash
# 1. 克隆项目
git clone https://github.com/qq1375828505/DAXIE666.git

# 2. 安装 Flutter SDK (>=3.29.0)
# 3. 安装依赖
flutter pub get

# 4. 生成代码（首次运行）
flutter pub run build_runner build --delete-conflicting-outputs

# 5. 运行
flutter run

# 6. 打包 APK
flutter build apk --release
```

## 📋 注意事项
- 首次运行需要执行 `build_runner` 生成 `.freezed.dart` 和 `.g.dart`
- Android 需要 `minSdk 23`、`compileSdk 36`
- 启动时会弹出权限请求弹窗（存储、通知、麦克风）
- AI 功能需要网络连接（配置 API Key 后使用）
- 纯单机运行，不依赖后端服务

## 💾 数据存储
- 作品正文：`NovelProjects/{novelId}_{title}/chapters/*.md`
- 索引数据库：`novel_ide.db`（7张表）
- 配置：`Hive` + `app_config.json`
- API Key：`Android Keystore`（flutter_secure_storage）
- 记忆文件：`NovelProjects/memories/{novelId}_memory.txt`

## 📜 版本历史
| 版本 | 说明 |
|------|------|
| V1.0.0 | 基础框架、作品管理、编辑器、AI基础动作 |
| V1.1.0 | 资料管理扩展、大纲增强、番茄报告UI |
| V1.2.0 | 写作统计、全文审查、多模型路由、AgentForge |
| V1.3.0 | AI对话窗口、导出重写、小说记忆系统 |
| V1.3.1 | 多协议支持、测试连接、配置文件、上下文压缩 |
| V1.3.2 | 运行时权限、卷长按菜单、全页面导出、19项权限 |
| V1.3.3 | 修复内容丢失Bug、导出保存到本地、dispose强制保存、路径一致性修复 |

## 📄 License

MIT

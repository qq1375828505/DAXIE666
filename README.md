# 网文写作IDE - Android

> 🚀 完全单机运行的网文写作IDE Android版。AI写作辅助 · 富文本编辑 · 番茄预设 · 8种主题 · 小说记忆

[![GitHub Release](https://img.shields.io/github/v/release/qq1375828505/DAXIE666)](https://github.com/qq1375828505/DAXIE666/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.29+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📥 下载安装

最新版：**V1.4.0** — [直接下载 APK](https://github.com/qq1375828505/DAXIE666/releases/download/v1.4.0/novel-ide-android-v1.4.0.apk)

> 支持 Android 6.0+（minSdk 23），无需注册，安装即用。

## ✨ 功能特色

### 📝 写作核心
- **双编辑器模式** — 纯文本编辑器（轻量）+ WebView 富文本编辑器（加粗/标题/引用/列表/链接）
- **自动保存** — 1.5秒延迟保存 + dispose 强制保存，绝不丢稿
- **防丢稿机制** — 3分钟自动快照，保留20个历史版本，一键恢复
- **字数统计** — 实时字数、每日统计图表、连续打卡、达标通知
- **语音输入** — 中文语音转文字，免打字
- **查找替换** — 单章内查找 + 跨章节全局搜索替换（高亮关键词）

### 🎨 主题皮肤（8种）
- 白色 · 黑色 · 蓝色护眼 · 黄色暖光 · 绿色清新 · 粉色 · 日系木色 · 红色热情
- 设置页网格卡片选择，一键切换，自动持久化
- 每种主题独立定义 primary/secondary/background/text 色值

### 🤖 AI 写作助手
- **AI 对话窗口** — 底部导航独立Tab，多会话管理，自动上下文压缩（40条消息触发）
- **AI 续写/润色/起标题** — 编辑器底部抽屉，选中文字右键即可调用
- **爽点检查/水文检测/全文审查** — 一键生成专业审查报告
- **文章校对引擎** — 60+ 常见错别字词库 + 标点符号修正 + 中英文混用检测 + 重复用字检测
- **多模型支持** — OpenAI 兼容协议 + Anthropic 协议，支持添加和切换多个 AI 模型
- **测试连接** — 配置后一键测试 API 连通性和模型可用性
- **25个番茄预设** — 都市/玄幻/穿越/悬疑/女频，覆盖2026年爆款风格
- **自定义 Agent** — 创建专属写作 Agent，支持从文件导入

### 📚 资料管理（8种类型）
- 角色卡、设定卡、地点、势力、道具、伏笔、参考资料
- **小说记忆文件** — 自动更新，AI 对话时自动注入上下文

### 📦 导入导出
- **EPUB 导出** — 标准 EPUB 3.0 格式，可用 Kindle/Apple Books/Calibre 打开
- **ZIP 导出** — 章节 + 10种资料打包，保存到本地或系统分享
- **勾选式导出** — 章节自由选择，全选/全不选一键操作
- **导入 .novelpack** — 一键导入完整作品包
- **导入 TXT/MD/DOCX** — 自动拆章导入，自动创建新作品

### 🛠️ 编辑器增强
- **快捷操作栏** — 底部可滚动9按钮工具栏（撤销/重做/查找/替换/AI/语音/快词/保存/设置）
- **快捷短语** — 一键插入常用标点符号（省略号/破折号/各种括号）
- **设定提醒** — 检查小说设定冲突，自动标记异常

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
| Hive | 配置存储 + 主题持久化 |
| flutter_secure_storage | API Key 加密 |
| Dio | HTTP 请求（多协议支持） |
| webview_flutter | 富文本编辑器（复用起点作家JS引擎） |
| fl_chart | 统计图表 |
| archive | ZIP 压缩包 + EPUB 生成 |
| share_plus | 系统分享 |
| file_picker | 文件选择 |
| speech_to_text | 语音输入 |
| permission_handler | 运行时权限 |

## 📂 项目结构
```
lib/
├── main.dart
├── core/
│   ├── constants.dart            # 常量定义
│   ├── router.dart               # 路由管理（含富文本/搜索/Agent路由）
│   └── theme/
│       ├── app_themes.dart       # 8种主题皮肤定义
│       └── skin_provider.dart    # 主题状态管理（Hive持久化）
├── data/
│   ├── models/                   # 数据模型（Freezed）
│   ├── datasources/              # 数据库(v3)、文件、安全存储
│   ├── repositories/             # 数据仓库（含统计）
│   ├── presets/                  # 25个番茄预设
│   └── services/
│       ├── ai_service.dart       # AI多协议调用
│       ├── proofread_service.dart # 文章校对引擎（60+错别字词库）
│       ├── epub_export_service.dart # EPUB电子书导出
│       ├── novel_memory.dart     # 小说记忆系统
│       └── ...
├── presentation/
│   └── pages/
│       ├── writing/
│       │   ├── editor_page.dart        # 纯文本编辑器（+9按钮工具栏）
│       │   ├── rich_editor_page.dart   # WebView富文本编辑器
│       │   ├── global_search_page.dart # 跨章节全局搜索替换
│       │   └── proofread_page.dart     # 文章校对结果页
│       ├── works/                # 作品列表、导出（含EPUB）
│       ├── outline/              # 大纲（含主线大纲+拖拽排序）
│       ├── materials/            # 资料管理（8Tab）
│       ├── profile/              # 设置页（8种主题选择器+AI配置）
│       ├── ai/                   # AI对话、精修、全文审查
│       └── tomato/               # 番茄报告页、Agent市场
├── presentation/state/           # Riverpod Providers
└── assets/
    └── editor/                   # WebView编辑器资源（9个JS/CSS/HTML文件）
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
- 富文本编辑器使用 WebView，首次加载约 0.5 秒
- 纯单机运行，不依赖后端服务

## 💾 数据存储
- 作品正文：`NovelProjects/{novelId}_{title}/chapters/*.md`
- 索引数据库：`novel_ide.db`（7张表）
- 配置：`Hive` + `app_config.json`
- API Key：`Android Keystore`（flutter_secure_storage）
- 记忆文件：`NovelProjects/memories/{novelId}_memory.txt`
- 主题皮肤：`Hive` settings box（skin_type 字段）

## 📜 版本历史
| 版本 | 说明 |
|------|------|
| V1.0.0 | 基础框架、作品管理、编辑器、AI基础动作 |
| V1.1.0 | 资料管理扩展、大纲增强、番茄报告UI |
| V1.2.0 | 写作统计、全文审查、多模型路由、AgentForge |
| V1.3.0 | AI对话窗口、导出重写、小说记忆系统 |
| V1.3.1 | 多协议支持、测试连接、配置文件、上下文压缩 |
| V1.3.2 | 运行时权限、卷长按菜单、全页面导出、19项权限 |
| V1.3.3 | 修复内容丢失Bug、导出保存到本地、dispose强制保存 |
| V1.3.4 | 小说文件导入(TXT/MD/DOCX)、AI智能分析填充资料库、界面交互优化 |
| V1.3.5 | 修复导出保存到本地失败、修复_showImportDialog类作用域错误 |
| V1.4.0 | **8种主题皮肤 · WebView富文本编辑器 · EPUB导出 · 文章校对引擎 · 跨章节搜索 · 快捷操作栏 · DOCX自动创建作品** |

## 📄 License

MIT

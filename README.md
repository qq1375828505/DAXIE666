# 网文写作IDE - Android V1.3.2

完全单机运行的网文写作IDE Android版。支持AI写作辅助、番茄风格预设、小说记忆系统。

## 下载安装

[![GitHub Release](https://img.shields.io/github/v/release/qq1375828505/DAXIE666)](https://github.com/qq1375828505/DAXIE666/releases)

最新版：**V1.3.2** — [直接下载APK](https://github.com/qq1375828505/DAXIE666/releases/download/v1.3.2/novel-ide-android-v1.3.2.apk)

## 功能特性

### 核心功能
- [x] 作品管理（新建、删除、重命名、长按菜单）
- [x] 卷章管理（卷→章树形结构、长按重命名/删除、拖拽排序）
- [x] 单章编辑器（TextField方案、只编辑当前章节、Undo/Redo）
- [x] 自动保存（1.5秒延迟保存）+ 手动保存按钮
- [x] 防丢稿机制（3分钟快照、保留20个历史版本）
- [x] 字数统计与性能警告（>10000字提示拆章）
- [x] 查找替换功能
- [x] 深色模式 + 字体设置

### AI 功能
- [x] AI 对话窗口（底部导航Tab、会话管理、自动上下文压缩）
- [x] AI 续写/润色/起标题（编辑器底部抽屉）
- [x] 爽点检查/水文检测/全文审查（报告页面）
- [x] 多模型支持（OpenAI兼容 + Anthropic 协议）
- [x] 测试连接 + 获取模型列表
- [x] 25个番茄预设（都市/玄幻/穿越/悬疑/女频）
- [x] 自定义Agent创建 + 从文件导入

### 资料管理（8种类型）
- [x] 角色卡、设定卡、地点、势力、道具、伏笔、参考资料
- [x] **小说记忆文件**（自动更新，AI自动读取上下文）

### 数据管理
- [x] **全页面导出按钮**（写作/作品/大纲/资料页 AppBar）
- [x] 勾选式导出（章节自由选择、TXT格式ZIP压缩）
- [x] 导入 .novelpack 作品包
- [x] 每日字数统计图表（fl_chart）
- [x] 连续打卡 + 达标通知
- [x] 软件配置文件（JSON自定义行为）

### 权限与兼容性
- [x] **运行时权限请求**（启动时弹出授权弹窗）
- [x] 19项Android权限完整声明
- [x] Android 6.0+ 兼容（minSdk 23）
- [x] 纯单机运行，不依赖后端服务

### 技术栈
- Flutter 3.29+ / Dart
- Riverpod 状态管理
- sqflite 本地数据库（7张表）
- Hive 配置存储
- flutter_secure_storage API Key加密
- permission_handler 运行时权限
- Dio HTTP请求（多协议支持）
- fl_chart 统计图表
- archive 压缩包

## 项目结构
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

## 运行方式

```bash
# 1. 安装 Flutter SDK (>=3.29.0)
# 2. 安装依赖
flutter pub get

# 3. 生成 Freezed 代码（首次运行）
flutter pub run build_runner build --delete-conflicting-outputs

# 4. 运行
flutter run

# 5. 打包 APK
flutter build apk --release
```

## 注意事项
- 首次运行需要执行 `build_runner` 生成 `.freezed.dart` 和 `.g.dart`
- Android 需要 `minSdk 23`、`compileSdk 36`
- 启动时会弹出权限请求弹窗（存储、通知、麦克风）
- AI功能需要网络连接（配置API Key后使用）
- 纯单机运行，不依赖后端服务

## 数据存储
- 作品正文：`NovelProjects/{novelId}_{title}/chapters/*.md`
- 索引数据库：`novel_ide.db`（7张表）
- 配置：`Hive` + `app_config.json`
- API Key：`Android Keystore`（flutter_secure_storage）
- 记忆文件：`NovelProjects/memories/{novelId}_memory.txt`

## 版本历史
| 版本 | 说明 |
|------|------|
| V1.0.0 | 基础框架、作品管理、编辑器、AI基础动作 |
| V1.1.0 | 资料管理扩展、大纲增强、番茄报告UI |
| V1.2.0 | 写作统计、全文审查、多模型路由、AgentForge |
| V1.3.0 | AI对话窗口、导出重写、小说记忆系统 |
| V1.3.1 | 多协议支持、测试连接、配置文件、上下文压缩 |
| V1.3.2 | 运行时权限、卷长按菜单、全页面导出、19项权限 |

## License

MIT

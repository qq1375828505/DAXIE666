# 网文写作IDE - Android V1

完全单机运行的网文写作IDE Android版。

## 功能特性

### V1 核心功能
- [x] 作品管理（新建、删除、导入/导出）
- [x] 卷章管理（卷→章树形结构、拖拽排序、状态管理）
- [x] 单章编辑器（TextField方案、只编辑当前章节）
- [x] 自动保存（1.5秒延迟保存）
- [x] 防丢稿机制（3分钟快照、保留20个历史版本）
- [x] 字数统计与性能警告（>10000字提示拆章）
- [x] AI 续写/润色/起标题（底部抽屉交互）
- [x] 番茄预设切换（6个内置预设：赘婿、签到、种田、灵异、大女主、规则怪谈）
- [x] 长按选词AI菜单（润色、扩写、续写）
- [x] 语音输入
- [x] 查找功能
- [x] AI 模型配置（API Key加密存储）
- [x] 深色模式
- [x] 源文件目录结构（Markdown + JSON）
- [x] SQLite 索引数据库

### 技术栈
- Flutter 3.x
- Riverpod 状态管理
- sqflite 本地数据库
- Hive 配置存储
- flutter_secure_storage API Key加密
- Dio HTTP请求
- speech_to_text 语音输入

## 项目结构
```
lib/
├── core/                  # 常量、主题、路由
├── data/
│   ├── models/            # 数据模型（Freezed）
│   ├── datasources/       # 数据库、文件、安全存储
│   └── repositories/      # 数据仓库
├── presentation/
│   ├── pages/             # 页面
│   │   ├── writing/       # 写作页、编辑器
│   │   ├── works/         # 作品列表、详情
│   │   ├── outline/       # 大纲页
│   │   ├── materials/     # 资料页
│   │   ├── profile/       # 我的页
│   │   ├── ai/            # AI抽屉
│   │   └── tomato/        # 番茄预设
│   ├── state/             # Riverpod Providers
│   └── widgets/           # 通用组件
└── main.dart
```

## 运行方式

1. 安装 Flutter SDK (>=3.0.0)
2. 进入项目目录
3. 执行代码生成：
   ```bash
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   ```
4. 运行：
   ```bash
   flutter run
   ```
5. 打包：
   ```bash
   flutter build apk --release
   ```

## 注意事项
- 首次运行需要执行 `build_runner` 生成 `.freezed.dart` 和 `.g.dart` 文件
- Android 需要 `minSdk 21`
- 语音输入需要 RECORD_AUDIO 权限
- 文件导入导出需要存储权限

## 数据存储
- 作品正文：`/Android/data/com.example.novel_ide/files/NovelProjects/{novelId}_{title}/chapters/*.md`
- 索引数据库：`novel_ide.db`
- 配置：`Hive`
- API Key：`Android Keystore`（通过 flutter_secure_storage）

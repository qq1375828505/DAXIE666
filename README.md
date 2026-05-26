# 网文写作IDE

> 🚀 完全单机运行的网文写作IDE。AI写作辅助 · 双编辑器 · 富文本排版 · 8种主题 · 文章校对 · EPUB导出

[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**网文写作IDE** 是一款面向网络小说作者的全流程单机写作工具，不依赖任何云端服务，所有数据存储在本地设备上。

---

## 📥 下载安装

| 平台 | 状态 | 下载 |
|------|------|------|
| **Android** | ✅ 已发布 | [下载 APK](https://github.com/qq1375828505/novelIDE/releases/latest) |
| **Windows** | 🔨 开发中 | [查看源码](win版/novel-ide-windows/) |

> Android 版支持 Android 6.0+，无需注册，安装即用。
> Windows 版基于 Electron + Monaco Editor，正在开发中。

---

## 🖼️ 项目总览

```
网文写作IDE/
├── Android/          ← DAXIE666（Flutter 单机版）
│   ├── 双编辑器（纯文本 + WebView富文本）
│   ├── AI写作助手（对话/续写/润色/校对/审查）
│   ├── 8种主题皮肤
│   ├── EPUB/ZIP 导出
│   └── 完全单机，数据本地存储
│
├── win版/            ← Electron + Monaco Editor（开发中）
│   ├── 富文本编辑器（Monaco Editor）
│   ├── 桌面级快捷键支持
│   └── 待实现：同步 Android 端功能
│
├── Windows技术方案.md  ← Windows版技术文档
└── Android技术方案.md  ← Android版技术文档
```

---

## 📝 Android 版功能详解

### 一、双编辑器 — 随心切换

网文写作IDE提供两种编辑器模式，用户可在作品详情页选择章节后进入：

| 对比项 | 纯文本编辑器 | WebView 富文本编辑器 |
|--------|------------|-------------------|
| **定位** | 轻量极速，专注码字 | 专业排版，发布级作品 |
| **底层实现** | Flutter 原生 `TextField` | WebView + 起点作家 `rich_editor.js` |
| **文本格式** | 纯文本 / Markdown | 加粗、斜体、H1/H2标题、引用块、有序/无序列表 |
| **插入功能** | 文字输入 | 图片、超链接、@提及角色、#话题标签 |
| **工具栏** | 底部9按钮可滚动快捷栏 | 顶部格式工具栏（B/I/H1/H2/引用/列表/链接/图片/撤销/重做） |
| **自动保存** | 1.5秒延迟 + 退出强制保存 | 通过 FlutterBridge 同步内容后保存 |
| **撤销重做** | 50步 Dart 原生栈 | JS 原生 `document.execCommand('undo'/'redo')` |
| **语音输入** | speech_to_text 中文语音 | 同左 |
| **查找示替换** | 当前章节 + 跨章节全局搜索 | JS 原生查找 |

**WebView 编辑器架构**：
```
Flutter 层 (Dart)                    WebView 层 (JavaScript)
┌──────────────────────┐            ┌──────────────────────┐
│  RichEditorPage      │◄──────────►│  editor.html         │
│  ├─ WebViewController│  Channel   │  ├─ rich_editor.js   │
│  ├─ 格式工具栏       │◄─JSON──►  │  ├─ style.css        │
│  └─ FlutterBridge    │           │  └─ WeReadApi.js     │
└──────────────────────┘           └──────────────────────┘

JS → Flutter: onTextChange / onSelectionChange / onAtClicked
Flutter → JS: RE.setBold() / RE.setHeading() / RE.insertImage()
```

### 二、全文搜索与替换

- **跨章节全局搜索** — 输入关键词，自动扫描全部章节的标题和正文，逐章逐行匹配
- **黄色高亮** — 搜索结果中匹配关键词黄色背景高亮
- **搜索导航** — `上一条/下一条` 快速跳转，显示 `当前序号/总数` 进度
- **逐条替换** — 选中某条结果，点击替换按钮，仅替换该处匹配
- **全部替换** — 一键替换当前关键词在所有章节中的全部匹配项
- **替换后更新** — 自动更新数据库中的章节字数统计

### 三、文章校对引擎

纯 Dart 原生实现，无需联网，离线即可使用：

| 校对维度 | 实现方式 | 规则数 |
|---------|---------|--------|
| **错别字检测** | 同音字/形近字静态词库 `List<[错误, 正确]>` | 60+ 对 |
| **标点修正** | 字符串模式匹配 + 替换 | 12 条规则 |
| **中英文混用** | 正则检测中文后跟英文标点 | 动态检测 |
| **重复用字** | 正则 `([一-鿿])\1{2,}` 检测连续重复字 | 动态检测 |

**校对结果页面功能**：
- 顶部统计摘要（错别字 N 条 / 标点 N 条 / 建议 N 条）
- 筛选栏（全部 / 错别字 / 标点 / 建议），点击切换
- 结果卡片：红色左边框 = 错别字、橙色 = 标点、蓝色 = 建议
- 每条显示：类型标签 + 章节名 + `原文 → 建议` + 上下文片段

### 四、AI 写作助手

#### 4.1 AI 对话
- 独立 Tab 页面，底部导航第5个入口
- **多会话管理** — 创建/切换/删除多个对话
- **历史记录** — 所有对话保存到 SQLite 数据库
- **上下文压缩** — 超过40条消息后自动压缩历史，避免 token 超限
- **文件附件** — 支持通过文件选择器上传图片

#### 4.2 编辑器内 AI 操作
- 长按选中文字 → 右键弹出菜单 → **润色 / 扩写 / 续写 / 联网查证**
- AI 结果通过底部抽屉（AiDrawer）展示
- 联网搜索通过底部抽屉（SearchDrawer）展示，支持保存搜索结果到资料库

#### 4.3 精修与审查
- **一键精修**（PolishEnginePage）— 8个审查维度可勾选：
  语病检查 / 节奏分析 / 文风统一 / 冗余删除 / 对话优化 / 描写增强 / 钩子检测 / 战力一致性
  每条结果提供 `采用 / 插入 / 重新生成 / 跳过` 四个操作
- **全文审查**（FullTextReviewPage）— 4种审查类型：
  设定冲突检测 / 战力一致性 / 伏笔追踪 / 角色一致性
- **爽点密度报告** — 分析每章爽点分布，标记密集/稀疏区域
- **水文检测报告** — 检测凑字数、重复描写、信息密度低的段落
- **爆款标题生成** — AI 根据章节内容生成多个候选标题

#### 4.4 自定义 Agent
- **Agent 市场** — 内置番茄专区智能体（大纲生成器、爽点检查器等）
- **创建 Agent** — 自定义名称、Emoji 图标、系统提示词、参数模板
- **导入 Agent** — 从 JSON 文件导入已有 Agent 配置
- **运行 Agent** — 参数输入 → 聊天式交互 → 结果展示

#### 4.5 多模型支持
| 协议 | 兼容模型 |
|------|---------|
| OpenAI 兼容 | GPT-4o / GPT-3.5 / DeepSeek / 通义千问 / 智谱 GLM / 本地 Ollama 等 |
| Anthropic | Claude Sonnet / Claude Opus |

每个模型独立配置：名称、API 地址、模型名、API Key
- **获取模型列表** — 一键从 API 端点拉取可用模型
- **测试连接** — 验证 API 地址和 Key 是否正确
- **自由切换** — 多个模型间一键切换，不同场景用不同模型

#### 4.6 番茄风格预设
内置 25 个预设，覆盖主流网文风格：
- **都市**：都市、职场、商战、校园、娱乐圈...
- **玄幻**：仙侠、修真、洪荒、奇幻、末世...
- **穿越**：重生、系统、穿越历史、异世界...
- **悬疑**：推理、恐怖、盗墓、灵异...
- **女频**：言情、宫斗、宅斗、种田、甜宠...

### 五、资料管理系统

8种资料类型，每个类型独立数据库表：

| 类型 | 字段 | 特色功能 |
|------|------|---------|
| **角色卡** | 名字、定位、外貌、性格、背景、关系 | AI 生成角色头像 |
| **设定卡** | 名称、分类、描述 | 世界观体系管理 |
| **地点** | 名称、分类、描述、特征、规则 | 地理位置关系 |
| **势力** | 名称、分类、描述、首领、实力等级、成员列表 | 成员列表支持多人 |
| **道具** | 名称、分类、描述、品阶、持有者、是否关键道具 | 关键道具标记 |
| **伏笔** | 标题、描述、状态（已埋/已回收/已废弃）、闲置章数 | 自动统计闲置章数 |
| **参考资料** | 标题、内容、来源、来源URL | 联网搜索结果一键保存 |
| **AI 记忆文件** | 自动维护 | 每次打开AI对话时自动更新并注入上下文 |

### 六、导入导出系统

#### 导出
| 格式 | 说明 | 适用场景 |
|------|------|---------|
| **EPUB** | 标准 EPUB 3.0，按卷/章组织目录，含 CSS 样式 | Kindle / Apple Books / Calibre |
| **ZIP** | 章节 TXT + 10种资料文本文件打包 | 备份 / 电脑端编辑 |
| **保存到本地** | FilePicker 选择手机存储位置 | 长期保存 |
| **系统分享** | share_plus 调用系统分享面板 | QQ / 微信 / 蓝牙发送 |

**ZIP 可导出内容（10种可勾选）**：
作品信息 / 章节正文 / 卷信息+大纲 / 角色卡 / 设定卡 / 地点 / 势力 / 道具 / 伏笔 / 参考资料 / AI记忆文件

#### 导入
| 文件类型 | 导入行为 |
|---------|---------|
| `.novelpack` | 解压导入完整作品包（含所有结构） |
| `.txt` | 自动识别章节分隔符 → 智能拆章 → 自动创建新作品 |
| `.md` | 同上 |
| `.docx` | 同上（需 Flutter 端 DOCX 解析） |

### 七、8种主题皮肤

| 主题 | 色系 | 主色 | 适合场景 |
|------|------|------|---------|
| 白色 | 浅灰白底 | #6B4EFF（紫蓝） | 日常写作（默认） |
| 黑色 | 深色 | #9B8AFF（亮紫） | 夜间写作 |
| 蓝色护眼 | 柔和蓝底 | #4A90D9 | 长时间码字 |
| 黄色暖光 | 暖黄底 | #D4A843 | 咖啡厅/沙发 |
| 绿色清新 | 浅绿底 | #4CAF50 | 办公室/教室 |
| 粉色 | 浅粉底 | #E91E63 | 言情/女频 |
| 日系木色 | 木质底 | #A0845C | 散文/文艺 |
| 红色热情 | 浅红底 | #D32F2F | 玄幻/战斗 |

**实现方式**：
- 每种主题是一个 `SkinTheme` 对象，包含 13 个颜色属性
- `SkinTheme.toThemeData()` 生成 Material 3 `ThemeData`
- 设置页网格卡片选择器，2行4列，每张卡片显示3色预览点+主题名+描述
- 通过 `Hive.box('settings').put('skin_type', index)` 持久化

### 八、编辑器增强功能

| 功能 | 说明 |
|------|------|
| **快捷操作栏** | 底部可滚动9按钮：撤销/重做/查找/替换/AI/语音/快词/保存/设置 |
| **快捷短语面板** | 底部弹窗，一键插入 `…… —— 「」 『』 【】` 等常用标点 |
| **语音输入** | speech_to_text 中文语音转文字，支持标点识别 |
| **自动保存** | 1.5秒延迟防抖（Timer）+ `dispose` 强制保存，绝不丢稿 |
| **历史快照** | 每3分钟自动快照章节内容，保留最近20个版本 |
| **撤销/重做** | 50步操作历史栈（List\<String\>），支持跨保存周期 |
| **字数统计** | 实时字数 + fl_chart 柱状图 + 连续打卡天数 + 每日目标进度条 |
| **章节数超限** | 超10000字黄色警告，超15000字红色建议拆章 |
| **设定提醒** | 扫描全部章节，检测角色名/时间线/设定冲突 |
| **通知提醒** | flutter_local_notifications 字数目标达标通知 |

### 九、作品与大纲管理

**作品管理（首页）**
- 底部导航「作品」Tab 为 App 首页
- 顶部渐变统计栏：作品数 / 总字数 / 总章节
- 作品列表卡片：封面缩略图 + 书名 + 简介 + 字数 + 章节数 + 更新时间
- 新建 / 重命名 / 删除作品
- 每部作品独立存储为 `NovelProjects/{id}_{title}/` 目录
- 长按作品卡片弹出操作菜单（重命名 / 导出 / 删除）
- 空状态引导：一键创建或导入 TXT/MD 文件

**大纲管理**
- 主线大纲编辑区 — 自由撰写故事主线，支持富文本
- 多卷管理 — 新建卷、拖拽排序（ReorderableListView）
- 多章管理 — 新建章节、拖拽排序
- 章节状态 — 草稿（灰色）/ 进行中（蓝色）/ 已完成（绿色）/ 已定稿（金色）
- 大纲与正文关联 — 每个章节可绑定梗概摘要

### 十、写作统计

- **今日字数** — 当天累计写作字数
- **连续打卡** — 连续写作天数统计
- **累计字数** — 全部作品总字数
- **30天柱状图** — fl_chart 展示近30天每日字数
- **目标进度** — 每日字数目标（可调500~20000），LinearProgressIndicator 进度条
- **下拉刷新** — RefreshIndicator 实时更新数据

### 十一、隐私与安全

| 机制 | 说明 |
|------|------|
| **完全单机** | 所有数据存储在手机本地，不连接任何后端服务器 |
| **API Key 加密** | 使用 Android Keystore + flutter_secure_storage 加密 |
| **离线模式** | 断网时自动切换，写作/编辑/保存/AI记忆不受影响 |
| **19项权限声明** | 存储、通知、麦克风、网络等，运行时逐项授权 |

---

## 💻 Windows 版（开发中）

Windows 版正在开发中，基于以下技术栈：

| 技术 | 用途 |
|------|------|
| Electron | 桌面应用框架 |
| TypeScript | 业务逻辑 |
| Monaco Editor | 代码级编辑器（VS Code 同款） |
| Tailwind CSS | UI 样式 |
| electron-vite | 构建工具 |

**已规划功能**（对标 Android 版）：
- 作品/卷/章节管理
- 富文本编辑器（Monaco Editor + Markdown）
- AI 对话与精修
- 资料管理（角色卡/设定/大纲/伏笔）
- EPUB / TXT 导出
- SQLite 本地数据存储
- `.novelpack` 作品包兼容（与 Android 版互通）

**Windows 版优势**：
- 桌面级快捷键（Ctrl+S 保存、Ctrl+Z 撤销等）
- 大屏幕多窗口（编辑器 + 大纲 + 资料并排显示）
- 更大的存储空间和更完整的文件系统访问

> 💡 Windows 版源码位于 `win版/novel-ide-windows/` 目录，技术方案详见 `Windows技术方案.md`

---

## 🏗️ 技术架构

### 技术栈总览

| 层级 | Android (Flutter) | Windows (Electron) |
|------|-------------------|-------------------|
| **框架** | Flutter 3.29+ / Dart | Electron + TypeScript |
| **UI** | Material 3 + Riverpod | Tailwind CSS |
| **编辑器** | TextField + WebView(rich_editor.js) | Monaco Editor |
| **数据库** | SQLite (sqflite) | SQLite (better-sqlite3) |
| **配置** | Hive + flutter_secure_storage | electron-store |
| **网络** | Dio (OpenAI + Anthropic) | fetch/axios (同) |
| **打包** | APK | NSIS / AppImage / DMG |

### Android 项目结构

```
lib/
├── main.dart                          # 入口
├── core/
│   ├── constants.dart                 # 常量
│   ├── router.dart                    # 路由
│   └── theme/
│       ├── app_themes.dart            # 8种主题
│       └── skin_provider.dart         # 主题 Provider
├── data/
│   ├── models/                        # Freezed 数据模型
│   ├── datasources/                   # 数据库 + 文件 + 安全存储
│   ├── repositories/                  # 数据仓库
│   ├── presets/                       # 25个番茄预设
│   └── services/                      # AI/校对/EPUB/导入/记忆/通知
├── presentation/
│   ├── state/                         # Riverpod Providers
│   └── pages/                         # 全部页面（12个目录，30+页面）
└── assets/editor/                     # WebView 编辑器资源（9个JS/CSS/HTML）
```

### 数据流架构

```
用户操作 → UI (Material 3 Widget)
    ↓
状态管理 (Riverpod Provider/StateNotifier)
    ↓
业务逻辑 (Service 层)
    ↓
数据层
├── SQLite (sqflite) — 作品/章节/卷/角色/统计
├── Hive — 主题/配置持久化
├── 文件系统 (path_provider) — 正文Markdown + 记忆文件
└── Secure Storage — API Key 加密
```

---

## 🛠️ 开发运行

### Android 版

```bash
# 1. 克隆仓库
git clone https://github.com/qq1375828505/novelIDE.git

# 2. 进入项目目录
cd DAXIE666

# 3. 安装依赖
flutter pub get

# 4. 生成 Freezed 代码（首次必须）
flutter pub run build_runner build --delete-conflicting-outputs

# 5. 运行
flutter run

# 6. 打包 Release APK
flutter build apk --release
```

### Windows 版

```bash
# 1. 进入 Windows 版目录
cd "win版/novel-ide-windows"

# 2. 安装依赖
npm install

# 3. 开发模式运行
npm run dev

# 4. 打包
npm run build
```

### 环境要求

| 项目 | Android 版 | Windows 版 |
|------|-----------|-----------|
| SDK | Flutter >= 3.29.0 | Node.js >= 18 |
| 系统 | Android 6.0+ (minSdk 23) | Windows 10+ |
| 编译 | compileSdk 36 | Electron Vite |

---

## 💾 数据存储

### Android 版

| 数据 | 方式 | 路径 |
|------|------|------|
| 作品正文 | Markdown 文件 | `NovelProjects/{novelId}_{title}/chapters/*.md` |
| 作品索引 | SQLite | `novel_ide.db`（7张表） |
| 主题配置 | Hive | `settings` box |
| API Key | Android Keystore | flutter_secure_storage |
| AI 记忆 | 文本文件 | `NovelProjects/memories/{novelId}_memory.txt` |
| 导出文件 | ZIP / EPUB | 用户通过 FilePicker 选择位置 |

### 作品源文件格式

```
NovelProjects/
└── {novelId}_{novelTitle}/
    ├── project.json          # 作品元数据（书名/作者/描述/大纲）
    ├── volumes.json          # 卷列表
    ├── chapters/
    │   ├── {chapterId}.md    # 章节正文（Markdown格式）
    │   └── ...
    └── materials/
        ├── characters.json   # 角色卡
        ├── settings.json     # 设定卡
        ├── locations.json    # 地点
        ├── factions.json     # 势力
        ├── items.json        # 道具
        ├── hooks.json        # 伏笔
        └── references.json   # 参考资料
```

---

## 📄 License

MIT

---

## 🤝 支持与反馈

- 提交 Issue：[GitHub Issues](https://github.com/qq1375828505/novelIDE/issues)
- 源码仓库：[DAXIE666](https://github.com/qq1375828505/novelIDE)

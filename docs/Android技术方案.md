# 网文写作IDE — Android移动端技术方案（单机独立版）
## 完整移动端小说写作IDE，完全单机运行

---

## 1. 产品定位

网文写作IDE的Android移动端，定位为**完整移动端小说写作IDE**，不是Windows版的附属工具，也不是单纯的灵感便签或AI聊天软件。

Android版可以独立完成：
- 新建作品、卷、章节
- 管理章节顺序、章节状态和章节梗概
- 编辑正文、自动保存、版本快照、防丢稿恢复
- 维护角色卡、设定卡、大纲、伏笔、参考资料
- 调用用户自行配置的AI API完成续写、润色、起标题、爽点检查等写作动作
- 导入/导出统一作品源文件或`.novelpack`作品包

**核心原则：**
- 完全单机运行，不需要账号系统，不需要云同步，不依赖共享后端
- 作品数据优先以Markdown/JSON源文件保存，SQLite只做索引、缓存和统计
- 用户可通过USB、网盘、局域网传输、LocalSend、Syncthing等方式手动同步源文件
- 与Windows版互不依赖，但两端应使用统一作品源文件格式，便于手动迁移

---

## 2. 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| 框架 | Flutter 3.x | Android单端优先，后续可复用部分逻辑 |
| 状态管理 | Riverpod | 管理作品、章节、编辑器状态、AI状态 |
| 本地索引 | SQLite (sqflite) | 作品列表、章节索引、搜索索引、写作统计、缓存 |
| 本地配置 | Hive | 主题、字体、编辑器偏好、最近打开记录 |
| 作品源文件 | Markdown + JSON | 正文、角色、设定、大纲、伏笔、AI预设 |
| 作品包 | `.novelpack` | 本质为zip，便于手动同步和备份 |
| 编辑器 | **TextField(maxLines: null)** | 只编辑当前章节，避免整本加载 |
| 网络 | Dio | 直接请求用户配置的AI API、搜索API |
| 安全 | flutter_secure_storage | API Key加密 |
| 权限 | permission_handler | 运行时权限请求（存储、麦克风、通知等） |
| 文件 | file_picker + path_provider + archive | 导入导出源文件和`.novelpack` |
| 图表 | fl_chart | 写作统计 |

---

## 3. 核心架构

### 3.1 完全单机
```
┌─────────────────────────────────────────┐
│       Android完整单机写作IDE              │
│  ┌─────────────┐  ┌─────────────────┐   │
│  │   Flutter   │  │ SQLite + Hive   │   │
│  │   UI层      │  │ 本地数据存储    │   │
│  └──────┬──────┘  └─────────────────┘   │
│         │                                │
│  ┌──────┴──────────────────────────┐    │
│  │      业务逻辑层（Dart）          │    │
│  │  - 作品/卷/章节管理              │    │
│  │  - AI调用（直接请求用户API）      │    │
│  │  - 联网搜索（直接请求搜索API）    │    │
│  │  - 事实提取/冲突检测（本地规则+可选本地模型）│
│  │  - 钩子追踪                      │    │
│  │  - 一键精修（直接请求用户API）    │    │
│  │  - Agent运行（V3，本地解释器）    │    │
│  │  - 模型路由（本地配置）           │    │
│  │  - 费用统计（本地计算）           │
│  │  - 源文件导入/导出(.novelpack)   │    │
│  └──────────────────────────────────┘    │
│                                          │
│  外部连接：用户自行配置的AI API、搜索API   │
│  无：云端同步、账号系统、后端服务          │
└─────────────────────────────────────────┘
```

### 3.2 与Windows版关系

**互不依赖，但格式互通：**
- 无账号，两端不互通
- 无云同步，作品各自保存在本地
- AI配置各自独立（各自存各自的API Key）
- Android可以独立新建、编辑、管理和导出小说
- Windows和Android使用统一作品源文件格式，用户手动同步源文件
- 作品迁移：导出`.novelpack`或源文件目录 → 手动传输 → 导入

### 3.3 统一作品源文件格式

推荐以源文件目录作为作品本体，`.novelpack`作为压缩备份和迁移格式。

```text
NovelProject/
├── project.json              # 作品元信息：书名、作者、简介、分类、创建时间
├── volumes.json              # 卷信息
├── chapter_index.json        # 章节顺序、标题、状态、字数、更新时间
├── chapters/                 # 章节正文，Markdown格式
│   ├── 0001.md
│   ├── 0002.md
│   └── 0003.md
├── characters.json           # 角色卡
├── outline.json              # 主线大纲、分卷大纲、章节梗概
├── facts.json                # 关键设定/事实卡
├── hooks.json                # 伏笔、回收状态
├── references/               # 参考资料
├── prompts/                  # AI预设、番茄预设、用户自定义Prompt
├── assets/                   # 封面、图片等资源
└── settings.json             # 作品级设置
```

`.novelpack`本质为zip包，内部保持以上目录结构。导入时解压为源文件目录，导出时重新打包。

---

## 4. 编辑器（TextField方案）

### 4.1 为什么不用flutter_quill
- 长文档（>10万字）卡顿
- Delta格式与Markdown转换复杂
- 实时字数统计性能差
- 不支持自定义下划线

### 4.2 TextField + 自定义样式
```dart
TextField(
  controller: textController,
  maxLines: null,
  minLines: 20,
  decoration: InputDecoration(border: InputBorder.none),
  style: TextStyle(
    fontFamily: 'NotoSerifSC',
    fontSize: 18,
    height: 1.8,
  ),
  onChanged: (text) {
    ref.read(wordCountProvider.notifier).update(text.length);
  },
)
```

**Markdown预览/编辑分离：**
- 编辑模式：纯文本+Markdown标记
- 预览模式：渲染后的富文本（可选）

### 4.3 移动端编辑限制

- 永远只打开当前章节，不一次性加载整本书
- 单章建议控制在3000-8000字
- 单章超过10000字提示拆章
- 单章超过15000字提示性能风险
- 字数统计只实时计算当前章节，全书字数通过索引异步汇总

### 4.4 防丢稿机制

- 停止输入1.5秒后自动保存
- App进入后台、切换章节、退出编辑器时立即保存
- 每3-5分钟生成一次本地快照
- 每章保留最近20个历史版本
- 异常退出后，下次打开提示恢复草稿
- 保存状态在编辑器顶部展示：保存中 / 已保存 / 保存失败 / 上次保存时间

---

## 5. 页面结构

### 5.1 底部导航（5个Tab）

Android版是完整移动端小说写作IDE，底部导航以作品创作为中心。

```dart
NavItem(icon: Icons.edit_note, label: '写作', page: WritingPage()),
NavItem(icon: Icons.auto_stories, label: '作品', page: WorksPage()),
NavItem(icon: Icons.account_tree, label: '大纲', page: OutlinePage()),
NavItem(icon: Icons.inventory_2, label: '资料', page: MaterialsPage()),
NavItem(icon: Icons.chat_bubble, label: 'AI对话', page: AiChatPage()),
```

注：「我的」页面（AI配置、Agent市场、字数目标、统计、深色模式、字体、软件配置、备份）已移至**资料页右上角设置按钮**，不再占用底部导航。

### 5.2 写作页（WritingPage）

- 当前章节编辑器
- 顶部显示：作品名、当前章节、保存状态、当前章字数
- AppBar右上角：导出按钮、保存按钮、查找、更多菜单
- 底部工具栏：撤销、重做、保存
- 长按选词：复制/剪切/润色/扩写/改对白/联网查证
- AI作为底部抽屉或浮动按钮出现，不抢占正文区域

### 5.3 作品页（WorksPage）

- 我的作品列表
- 最近编辑
- 新建作品
- 导入作品源文件/`.novelpack`
- 导出作品源文件/`.novelpack`
- 作品备份与恢复

### 5.4 大纲页（OutlinePage）

- 卷→章→节树形结构
- 章节拖拽排序
- 章节状态：未写/草稿/待精修/已完成/已导出
- 主线大纲、分卷大纲、章节梗概
- 可从大纲页直接跳转到章节编辑

### 5.5 资料页（MaterialsPage）

- 角色卡
- 设定卡/事实卡
- 地点、势力、道具
- 伏笔与回收状态
- 参考资料库

### 5.6 AI入口设计

AI有**两个入口**：
1. **底部导航「AI对话」Tab**：独立聊天页、会话管理、模型切换、预设选择
2. **写作页内AI抽屉**：正文选中后弹出润色/扩写/续写/联网查证等快捷操作

---

## 6. 功能模块

### 6.1 作品与章节管理
- 新建/删除/重命名作品
- 新建/删除/重命名卷、章、节
- 卷→章→节树形结构
- 长按拖拽排序
- 章节拆分、合并、移动
- 章节状态：未写/草稿/待精修/已完成/已导出
- 自动保存源文件，同时更新SQLite索引
- 版本历史（本地快照）

### 6.2 联网搜索
- 长按选词→"联网查证"
- 底部DraggableSheet展示结果
- 结果保存到本地参考资料库
- **直接请求搜索API**

### 6.3 自定义大模型 (ModelHub)
- 本地模型：Ollama（通过局域网连接桌面端Ollama，或手机端Termux运行）
- 云端API：用户自行配置
- 模型选择器（底部弹出）
- 费用卡片（本地计算）
- **API Key加密存储**：Android Keystore

### 6.4 设定提醒 (SettingReminder) — 分阶段

第一版不做夸张的“全文剧情自动审查”，先做稳定可靠的设定提醒。

**V1：手动标记 + 简单匹配**
- 手动标记关键设定：角色境界、道具归属、人物关系、地点规则
- 字符串/关键词匹配潜在冲突
- 手动添加伏笔，追踪闲置章节
- 提醒列表展示（不实时下划线，避免影响输入性能）

**V2：轻量本地模型**
- BERT-tiny实体识别
- 半自动事实提取
- 人工确认后写入事实卡

**V3：全文语义（实验室）**

### 6.5 一键精修 (AutoPolishEngine)
- 8维度精修：语病、节奏、文风、冗余、对话、描写、钩子、战力
- 手机端采用**卡片式审阅**，不做左右分栏
- 原文卡片 → 修改后卡片 → 采用/插入下方/复制/重新生成/放弃
- 支持逐段采纳/跳过
- **直接调用用户配置的模型API**

### 6.6 AgentForge（V3）
- 第一版只预留入口，不作为主导航核心功能
- Agent市场（本地YAML + 可导入）
- Agent配置页
- 运行结果以消息气泡展示
- **本地运行，直接调用模型API**

### 6.7 权限管理

App启动时通过 `permission_handler` 请求运行时权限：
- 存储读写（READ/WRITE_EXTERNAL_STORAGE, MANAGE_EXTERNAL_STORAGE）
- 媒体文件读取（READ_MEDIA_IMAGES/VIDEO/AUDIO，Android 13+）
- 通知（POST_NOTIFICATIONS）
- 麦克风（RECORD_AUDIO，语音输入备用）
- 前台服务（FOREGROUND_SERVICE）
- 后台运行（WAKE_LOCK, REQUEST_IGNORE_BATTERY_OPTIMIZATIONS）
- 网络状态（ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE）
- 振动（VIBRATE）
- 音频设置（MODIFY_AUDIO_SETTINGS）
- 屏幕录制检测（DETECT_SCREEN_RECORDING）

### 6.8 离线模式
- 无网络时：写作、编辑、查看100%可用
- AI功能降级：使用本地模型或禁用
- 联网后无自动同步（单机版无云端）

### 6.9 本地通知
- 字数目标提醒（晚上9点）
- 连续打卡提醒

### 6.10 源文件导入导出
- 导入源文件目录
- 导入`.novelpack`作品包
- 导出源文件目录
- 导出`.novelpack`作品包
- 导出Markdown/TXT/EPUB/PDF
- 导入时校验`project.json`、`chapter_index.json`和章节文件完整性
- 导出前自动生成最新SQLite索引和源文件快照

---

## 7. 番茄小说专属模块 (TomatoStudio) — 新增

### 7.1 定位
针对**番茄小说平台**快节奏、强爽点、高密度的写作风格，提供一键切换的AI预设和专属Agent。番茄读者偏好：黄金三章强钩子、每章3-4个爽点、节奏快不拖沓、标题吸睛。

Android V1只保留常用预设和快捷写作动作；完整25个预设、Agent市场、复杂爽点报告放到V2/V3，避免第一版过重。

### 7.2 番茄AI写作预设（25个内置，一键切换）

内置25个预设，覆盖2026年5月番茄最新爆款风格。预设存储为本地YAML，支持用户修改和新建。

---

**【原10个预设保留】**

```yaml
# presets/tomato/classic/

# 1. 都市赘婿·隐忍爆发
name: "都市赘婿·隐忍爆发"
description: "前期隐忍被瞧不起，后期身份揭露打脸，情绪压抑→爆发"
category: "urban"
tags: ["打脸", "身份揭露", "情绪反差", "护短"]
system_prompt: |
  你是一位擅长都市赘婿流的网文作家。写作风格要求：
  1. 开篇即冲突：主角被丈母娘/小舅子/前妻羞辱，读者立刻产生代入感
  2. 隐忍铺垫：主角有隐藏身份但暂时不揭穿，让读者憋着一口气
  3. 爆发爽点：在最关键时刻揭露身份，打脸反派，爽感拉满
  4. 节奏：每章至少2个爽点，每3章一个大高潮
  5. 对话：反派嚣张跋扈，主角冷静克制（形成反差）
  6. 描写：重点写反派被打脸后的表情、心理、周围人反应（爽感放大器）
  禁止：大段环境描写、无关日常、主角主动解释背景

# 2. 都市神医·一针定乾坤
name: "都市神医·一针定乾坤"
description: "医术通天，救人打脸两不误，专业术语+震撼效果"
category: "urban"
tags: ["医术", "救人", "打脸", "专业感"]
system_prompt: |
  你是一位擅长都市神医流的网文作家。写作风格要求：
  1. 医术描写：用看似专业的中医术语（银针、穴位、经脉），让读者感觉"很厉害"
  2. 救人场景：先被西医/庸医判死刑，主角出手妙手回春，形成强烈反差
  3. 打脸节奏：每救一个人，就踩一个看不起中医的反派
  4. 爽点设计：病重→绝望→主角出手→秒好转→众人震惊→反派跪舔
  5. 节奏：每章1个病例+1个打脸，不拖泥带水

# 3. 都市战神·龙帅归来
name: "都市战神·龙帅归来"
description: "沙场战神回归都市，护妻女、灭仇敌，铁血柔情"
category: "urban"
tags: ["战神", "护短", "身份揭露", "铁血"]
system_prompt: |
  你是一位擅长都市战神流的网文作家。写作风格要求：
  1. 开篇：战神接到妻女受辱消息，连夜赶回，杀气腾腾
  2. 护短：谁敢动我家人，灭你满门（读者最爽的护短情节）
  3. 身份揭露：一层层揭露战神身份（龙帅、战神、至尊），每层都比上一层震撼
  4. 打斗：一招秒，不啰嗦，重点写敌人从嚣张到恐惧的转变
  5. 情感线：对敌人冷酷无情，对妻女温柔体贴（反差萌）
  6. 节奏：每章至少1个身份揭露+1个打斗爽点

# 4. 玄幻签到·开局无敌
name: "玄幻签到·开局无敌"
description: "签到系统送奖励，一路碾压，爽点密集"
category: "fantasy"
tags: ["签到", "系统", "碾压", "无敌"]
system_prompt: |
  你是一位擅长玄幻签到流的网文作家。写作风格要求：
  1. 签到奖励：每天签到给逆天奖励，奖励要有画面感（异象、天地变色）
  2. 碾压感：主角永远比敌人强一个大境界，打架就是秒
  3. 敌人设计：敌人嚣张→主角签到变强→敌人傻眼→读者爽
  4. 节奏：每章1次签到+1次打脸，不拖沓
  5. 描写重点：奖励的视觉效果、敌人震惊的表情、周围人的反应
  6. 禁止：苦战、受伤、逃命（签到流不允许虐主）

# 5. 玄幻系统·任务狂魔
name: "玄幻系统·任务狂魔"
description: "系统发布任务，完成任务变强，任务设计有趣"
category: "fantasy"
tags: ["系统", "任务", "骚操作", "有趣"]
system_prompt: |
  你是一位擅长玄幻系统流的网文作家。写作风格要求：
  1. 任务设计：任务要有趣、有反差（如"让敌人叫你爸爸"、"当众跳支舞"）
  2. 奖励诱惑：任务奖励要让人眼红，读者都想接任务
  3. 完成过程：主角用骚操作完成任务，不按常理出牌
  4. 爽点：任务完成→奖励到账→实力暴涨→打脸之前看不起主角的人
  5. 节奏：每章1-2个任务，保持新鲜感

# 6. 玄幻无敌·横推诸天
name: "玄幻无敌·横推诸天"
description: "开局满级，一路横推，绝对无敌"
category: "fantasy"
tags: ["无敌", "碾压", "横推", "爽"]
system_prompt: |
  你是一位擅长玄幻无敌流的网文作家。写作风格要求：
  1. 无敌设定：主角开局就是最强，不需要修炼升级
  2. 看点：看主角怎么花式吊打各路天才、老祖、神明
  3. 敌人设计：敌人越强、越嚣张，被打脸时越爽
  4. 打斗：一招秒，重点写敌人从不可一世到怀疑人生的过程
  5. 节奏：每章至少1个强敌+1次碾压
  6. 禁止：苦战、受伤、需要别人救（无敌流不能虐主）

# 7. 穿越种田·发家致富
name: "穿越种田·发家致富"
description: "穿越古代/异世界，用现代知识种田经商，温馨日常+偶尔打脸"
category: "穿越"
tags: ["种田", "温馨", "现代知识", "日常"]
system_prompt: |
  你是一位擅长穿越种田流的网文作家。写作风格要求：
  1. 现代知识：用现代知识在古代/异世界降维打击（制盐、酿酒、火药、医术）
  2. 温馨日常：种田、做饭、盖房子、养宠物的温馨描写（让读者放松）
  3. 打脸节奏：日常中穿插打脸（地主欺负→主角用知识反击→众人震惊）
  4. 节奏：3章日常+1章打脸，张弛有度
  5. 描写重点：食物的美味、田园的美景、主角的惬意生活
  6. 情感线：慢热但甜，从陌生到依赖

# 8. 穿越年代·改革开放
name: "穿越年代·改革开放"
description: "穿越七八十年代，抓住时代机遇发家，年代感+爽感"
category: "穿越"
tags: ["年代", "改革开放", "商机", "赚钱"]
system_prompt: |
  你是一位擅长穿越年代文的网文作家。写作风格要求：
  1. 年代细节：准确还原七八十年代的生活细节（粮票、公社、万元户）
  2. 时代机遇：主角抓住改革开放机遇（倒腾、做生意、办厂）
  3. 打脸对象：看不起主角的亲戚、邻居、领导
  4. 节奏：每章1个商机+1次打脸，赚钱速度让读者爽
  5. 描写重点：钱的面额、物资的珍贵、众人从鄙视到巴结的转变

# 9. 悬疑灵异·捉鬼天师
name: "悬疑灵异·捉鬼天师"
description: "灵异事件+悬疑解谜，恐怖氛围+揭秘爽感"
category: "suspense"
tags: ["灵异", "悬疑", "恐怖", "揭秘"]
system_prompt: |
  你是一位擅长悬疑灵异流的网文作家。写作风格要求：
  1. 氛围营造：开篇即诡异（噩梦、异响、离奇死亡），让读者毛骨悚然
  2. 悬疑设计：层层递进的谜团，每章抛出1个新线索+1个新疑问
  3. 揭秘爽感：真相揭露时要震撼（反转、意料之外情理之中）
  4. 节奏：恐怖→调查→更恐怖→揭秘→爽（恶鬼被收/真相大白）
  5. 描写重点：恐怖场景的氛围（声音、光影、心理）、揭秘时的逻辑链条

# 10. 盗墓探险·寻龙点穴
name: "盗墓探险·寻龙点穴"
description: "古墓探险+风水玄学，惊险刺激+宝物收获"
category: "suspense"
tags: ["盗墓", "探险", "风水", "宝物"]
system_prompt: |
  你是一位擅长盗墓流的网文作家。写作风格要求：
  1. 古墓设计：每个墓都有独特机关和背景故事（历史真实感）
  2. 风水术语：用看似专业的风水术语（寻龙诀、分金定穴、八卦阵）
  3. 惊险节奏：安全→危机→化解→更大危机→死里逃生
  4. 收获爽感：每章至少1件宝物出土，宝物要有来头和威力
  5. 描写重点：古墓的阴森氛围、机关的巧妙、宝物的震撼效果
```

---

**【新增15个2026年5月爆款预设】**

```yaml
# presets/tomato/2026/

# 11. 规则怪谈·发疯破局流（S级顶流）
name: "规则怪谈·发疯破局流"
description: "诡异副本+隐藏规则+乐子人主角，男频女频通杀"
category: "suspense"
tags: ["规则怪谈", "无限流", "发疯", "乐子人", "单元剧"]
system_prompt: |
  你是一位擅长规则怪谈无限流的网文作家。2026年最火风格，核心公式：
  1. 副本设计：每个副本有3条明规则+2条隐藏规则（其中1条是陷阱规则）
  2. 主角设定：能看见隐藏规则/能修改规则/或纯发疯乐子人
  3. 破局方式：不是遵守规则活下去，而是"我就是规则本身"或"发疯创死NPC"
  4. 节奏：每章至少1次规则冲突+1次反转，单元剧+主线暗线并行
  5. 描写重点：规则的文字游戏、NPC的诡异行为、主角发疯时的爽感
  6. 禁止：苦大仇深、圣母心、按常理出牌

  快捷指令响应：
  - "生成本章规则" → 输出3明规则+2隐藏规则+1陷阱规则
  - "添加诡异NPC" → 生成有反转的NPC设定
  - "规则冲突" → 设计主角与规则的对抗情节

# 12. 县城振兴·全民分红流（S级顶流）
name: "县城振兴·全民分红流"
description: "重生贫困县城，绑定振兴系统，全民分红逆袭"
category: "urban"
tags: ["县城", "振兴", "分红", "集体致富", "基建"]
system_prompt: |
  你是一位擅长县城振兴流的网文作家。2026年最大黑马，核心公式：
  1. 开篇：重生/穿越回贫困县城，绑定"故土振兴系统"
  2. 系统机制：全民分红（人口×基础金额×发展系数），不是个人神豪
  3. 爽点设计：从"个人炫富"升级为"带动全村/全县逆袭"
  4. 节奏：每章1个基建项目（修路、建厂、搞旅游）+1次村民反应爽点
  5. 描写重点：村民从怀疑到狂喜的转变、全县GDP数字变化、反对者被打脸
  6. 反派设计：县领导/邻县/资本方，从看不起到求合作

  快捷指令响应：
  - "生成分红计算" → 输出人口×金额×系数=分红金额
  - "基建项目" → 生成一个具体项目+预算+收益
  - "村民反应" → 生成3种不同村民的反应（怀疑/狂喜/反对）

# 13. 修仙职场·KPI考核流（S级顶流）
name: "修仙职场·KPI考核流"
description: "宗门变互联网公司，修炼变打工人KPI，摸鱼涨修为"
category: "fantasy"
tags: ["修仙", "职场", "KPI", "摸鱼", "社畜共鸣"]
system_prompt: |
  你是一位擅长修仙职场流的网文作家。传统修仙唯一出路，核心公式：
  1. 设定：现代社畜穿越修仙界，宗门=互联网公司，修炼=KPI考核
  2. 系统：绑定"职场修仙系统"，摸鱼/划水/甩锅反而涨修为
  3. 爽点：卷王弟子拼命修炼不如主角摸鱼，打脸内卷文化
  4. 节奏：每章1个职场梗（开会、加班、甩锅）+1次修为暴涨
  5. 描写重点：宗门会议的荒诞、KPI表格的讽刺、卷王崩溃的表情
  6. 情感共鸣：让打工人读者产生强烈代入感

  快捷指令响应：
  - "宗门会议" → 生成一场荒诞的修仙界职场会议
  - "卷王同事" → 生成一个拼命内卷却被主角碾压的角色
  - "摸鱼修仙" → 设计主角摸鱼却修为暴涨的情节

# 14. 无CP大女主·搞钱流（S级顶流）
name: "无CP大女主·搞钱流"
description: "彻底告别恋爱脑，男人都是工具人，主线只有搞钱复仇"
category: "female"
tags: ["大女主", "无CP", "搞钱", "复仇", "商业帝国"]
system_prompt: |
  你是一位擅长无CP大女主搞钱流的网文作家。女频顶流，完读率超甜宠30%，核心公式：
  1. 开篇：重生/穿书，开局手撕渣男贱女，绝不拖泥带水
  2. 主线：利用先知优势搞钱，建立商业帝国，男人都是工具人/跳板
  3. 爽点：每章1个赚钱项目+1次打脸（渣男/贱女/商业对手）
  4. 节奏：不搞暧昧、不谈恋爱、不解释，只搞钱和复仇
  5. 描写重点：商业谈判的碾压、渣男后悔的表情、财富数字的增长
  6. 情感线：可以有暗恋主角的男配，但主角绝不回应

  快捷指令响应：
  - "赚钱点子" → 生成一个90年代/00年代创业项目
  - "商业谈判" → 生成一场碾压对手的谈判
  - "手撕渣男" → 设计一个让渣男社死的情节

# 15. 情绪发疯·怼人变强流（S级顶流）
name: "情绪发疯·怼人变强流"
description: "与其内耗自己，不如创死别人，系统奖励发疯行为"
category: "urban"
tags: ["发疯", "怼人", "情绪价值", "系统", "社畜共鸣"]
system_prompt: |
  你是一位擅长情绪发疯流的网文作家。男女通吃，短视频引流神器，核心公式：
  1. 开篇：社畜/学生被欺负，绑定"发疯系统"，怼人/摆烂/掀桌子获得奖励
  2. 系统机制：越发疯越强，道德绑架无效，创死所有人
  3. 爽点：主角发疯语录成为全网热梗，所有人都怕她/他
  4. 节奏：每章至少1个发疯名场面+1次系统奖励
  5. 描写重点：发疯语录的冲击力、周围人震惊的表情、反派的崩溃
  6. 情感共鸣：让被社会规训的读者产生强烈爽感

  快捷指令响应：
  - "发疯名场面" → 生成一段让人拍案叫绝的发疯语录
  - "怼人话术" → 生成不带脏字但杀伤力极强的怼人台词
  - "道德绑架反派" → 设计一个用道德绑架反被主角创死的反派

# 16. 长生家族·千年底蕴流（A级热门）
name: "长生家族·千年底蕴流"
description: "整个家族传承千年，层层揭秘家族实力，打脸各方势力"
category: "urban"
tags: ["长生", "家族", "底蕴", "揭秘", "打脸"]
system_prompt: |
  你是一位擅长长生家族流的网文作家。都市脑洞新贵，核心公式：
  1. 开篇：现代普通青年，突然曝光家族身份（"我家老祖活了五千年"）
  2. 揭秘节奏：层层揭露家族实力（产业、武力、人脉），每层都比上一层震撼
  3. 爽点：各方势力从看不起到震惊到跪舔的转变
  4. 节奏：每章曝光1个家族秘密+1次打脸
  5. 描写重点：家族长辈的逼格、隐藏产业的震撼、古老敌人的恐惧
  6. 反派设计：从市井混混到地方豪强到隐世家族，层层升级

  快捷指令响应：
  - "曝光家族秘密" → 生成一个让人震惊的家族秘密
  - "家族长辈出场" → 设计一个逼格极高的长辈出场
  - "古老敌人" → 生成一个与家族有千年恩怨的敌人

# 17. 天命反派·背景编辑流（A级热门）
name: "天命反派·背景编辑流"
description: "穿越成反派，能编辑自己和他人的背景设定，收割天命之子"
category: "fantasy"
tags: ["反派", "背景编辑", "天命之子", "收割"]
system_prompt: |
  你是一位擅长天命反派流的网文作家。玄幻常青树，核心公式：
  1. 开篇：穿越成即将被主角打脸的反派，绑定"背景编辑系统"
  2. 系统机制：能编辑自己和他人的背景设定（凡人→王侯→帝族→仙神）
  3. 爽点：不断升级自己的背景，让原主角从看不起到绝望
  4. 节奏：每章编辑1次背景+收割1个天命之子
  5. 描写重点：背景曝光时的天地异象、原主角的怀疑人生、系统的骚操作
  6. 反派魅力：不是纯恶，是有脑子的反派，让读者喜欢

  快捷指令响应：
  - "编辑新背景" → 生成一个更高级的背景设定
  - "收割天命之子" → 设计主角收割原书主角的情节
  - "背景曝光" → 生成背景曝光时的震撼场面

# 18. 恶毒女配·全家反派洗白流（A级热门）
name: "恶毒女配·全家反派洗白流"
description: "穿成恶毒女配，带着全家反派一起逆袭，打脸原男女主"
category: "female"
tags: ["恶毒女配", "洗白", "全家反派", "团宠", "打脸"]
system_prompt: |
  你是一位擅长恶毒女配洗白流的网文作家。女频第二大流量，核心公式：
  1. 开篇：穿成原著恶毒女配，知道剧情走向，开局改变家人命运
  2. 洗白节奏：不是女配一个人洗白，而是带着全家反派一起逆袭
  3. 爽点：原男女主的黑点被揭露，女配一家从恶毒变成团宠
  4. 节奏：每章改变1个剧情节点+1次打脸原男女主
  5. 描写重点：家人从恶毒到可爱的转变、原男女主的崩塌、读者的"真香"感
  6. 情感线：可以有CP，但主线是家庭和事业

  快捷指令响应：
  - "改变剧情节点" → 生成一个改变原著剧情的方案
  - "家人洗白" → 设计一个家人从恶毒变可爱的情节
  - "原主角黑点" → 生成一个揭露原男女主黑点的情节

# 19. 都市高武·守夜人流（A级热门）
name: "都市高武·守夜人流"
description: "国家特殊部门+民族大义，异能对抗外来神明，热血燃爆"
category: "urban"
tags: ["高武", "守夜人", "民族大义", "热血", "异能"]
system_prompt: |
  你是一位擅长都市高武守夜人流的网文作家。男频基本盘升级，核心公式：
  1. 开篇：普通少年觉醒异能，加入国家特殊部门（守夜人/龙组/镇妖司）
  2. 世界观：现代都市+神话复苏，外来神明/异兽入侵
  3. 爽点："大夏境内，神明禁行"式的热血台词+国家力量碾压
  4. 节奏：每章1场战斗+1次异能升级+1句热血台词
  5. 描写重点：战斗的震撼、牺牲的泪点、民族自豪感的升华
  6. 情感线：战友情、家国情怀，爱情为辅

  快捷指令响应：
  - "城市保卫战" → 生成一场守护城市的大规模战斗
  - "新神明敌人" → 设计一个基于神话的敌人
  - "热血台词" → 生成一句让人热血沸腾的台词

# 20. 年代重生·整顿亲情流（A级热门）
name: "年代重生·整顿亲情流"
description: "重生70/80年代，手撕极品亲戚+弥补遗憾，中老年读者收割机"
category: "穿越"
tags: ["年代", "重生", "整顿亲情", "极品亲戚", "弥补遗憾"]
system_prompt: |
  你是一位擅长年代重生整顿亲情流的网文作家。中老年读者收割机，核心公式：
  1. 开篇：重生回70/80/90年代，开局手撕极品亲戚（为老不尊/重男轻女/吸血）
  2. 主线：不是单纯搞钱，而是"整顿极品亲戚+弥补前世遗憾"
  3. 爽点：每章1个极品亲戚被整顿+1次前世遗憾被弥补
  4. 节奏：亲情冲突→主角反击→亲戚后悔→全家和睦
  5. 描写重点：年代细节的真实感、极品亲戚的嘴脸、整顿时的爽感
  6. 情感线：弥补对父母/子女/兄弟姐妹的遗憾

  快捷指令响应：
  - "极品亲戚" → 生成一个让人血压飙升的极品亲戚
  - "手撕场景" → 设计一个让极品亲戚社死的情节
  - "前世遗憾" → 生成一个需要弥补的遗憾

# 21. 职业系统·超能力流（B级潜力）
name: "职业系统·超能力流"
description: "把普通职业变成超能力，法医、外卖员、快递员都能变强"
category: "urban"
tags: ["职业", "系统", "超能力", "日常", "逆袭"]
system_prompt: |
  你是一位擅长职业系统流的网文作家。细分领域蓝海，核心公式：
  1. 设定：普通职业（法医、外卖员、快递员）绑定系统，职业行为变强
  2. 爽点：用职业特性解决超凡问题（法医能看见死者说话、外卖员送一单变强）
  3. 节奏：每章1个职业任务+1次能力提升+1次意外收获
  4. 描写重点：职业细节的真实感、能力觉醒的震撼、周围人的反应
  5. 日常感：保持职业的日常属性，让读者有代入感

  快捷指令响应：
  - "职业技能树" → 生成一个职业的能力升级路线
  - "职业任务" → 生成一个有趣的任务
  - "能力觉醒" → 设计一个能力觉醒的震撼场面

# 22. 女性悬疑·刑侦流（B级潜力）
name: "女性悬疑·刑侦流"
description: "女性主角+刑侦破案+心理博弈，平台重点扶持"
category: "suspense"
tags: ["女性", "悬疑", "刑侦", "破案", "心理"]
system_prompt: |
  你是一位擅长女性悬疑刑侦流的网文作家。平台重点扶持，核心公式：
  1. 主角：女性法医/刑警/心理学家，专业能力强，不恋爱脑
  2. 案件：连环杀人、失踪案、密室杀人，每案有社会议题
  3. 节奏：发现尸体→调查线索→嫌疑人反转→真凶揭露
  4. 爽点：用专业知识破解完美犯罪、打脸看不起女性的同事
  5. 描写重点：尸检的细节、心理博弈的紧张、真相揭露的震撼
  6. 禁止：靠男性拯救、恋爱脑、案件逻辑漏洞

  快捷指令响应：
  - "案件设计" → 生成一个完整的案件（动机+手法+反转）
  - "线索布局" → 设计3个真线索+2个假线索
  - "真凶揭露" → 生成真凶揭露时的震撼场面

# 23. 摸鱼摆烂·变强流（B级潜力）
name: "摸鱼摆烂·变强流"
description: "越摸鱼越强，越摆烂越成功，打工人最强共鸣"
category: "urban"
tags: ["摸鱼", "摆烂", "系统", "打工人", "共鸣"]
system_prompt: |
  你是一位擅长摸鱼摆烂流的网文作家。打工人共鸣最强，核心公式：
  1. 设定：绑定"摸鱼系统"，上班摸鱼、下班准时、拒绝加班反而变强
  2. 爽点：卷王同事拼命加班不如主角准点下班，老板求主角别走
  3. 节奏：每章1个摸鱼技巧+1次系统奖励+1次卷王崩溃
  4. 描写重点：摸鱼方法的创意、老板从愤怒到求饶的转变、同事的反应
  5. 情感共鸣：让被996折磨的读者产生强烈爽感

  快捷指令响应：
  - "摸鱼方法" → 生成一个创意摸鱼方法
  - "老板反应" → 设计老板从愤怒到求饶的转变
  - "卷王崩溃" → 生成卷王同事崩溃的情节

# 24. 直播短视频·逆袭流（B级潜力）
name: "直播短视频·逆袭流"
description: "靠直播/短视频逆袭，全网顶流，紧跟热点"
category: "urban"
tags: ["直播", "短视频", "网红", "逆袭", "热点"]
system_prompt: |
  你是一位擅长直播短视频逆袭流的网文作家。紧跟热点，核心公式：
  1. 设定：主角靠直播/短视频展示特殊能力（种田、考古、修仙）
  2. 爽点：从无人问津到全网顶流，弹幕从嘲讽到跪舔
  3. 节奏：每章1场直播+1次能力展示+1次观众反应反转
  4. 描写重点：直播弹幕的变化、能力的震撼效果、黑粉的打脸
  5. 互动感：大量弹幕描写，让读者有看直播的代入感

  快捷指令响应：
  - "直播内容" → 生成一场有看点的直播
  - "弹幕反应" → 生成从嘲讽到跪舔的弹幕变化
  - "热点话题" → 生成一个能上热搜的话题

# 25. 洪荒神话·编辑流（B级潜力）
name: "洪荒神话·编辑流"
description: "能修改洪荒历史和神话设定，三清都懵了"
category: "fantasy"
tags: ["洪荒", "神话", "编辑", "历史", "脑洞"]
system_prompt: |
  你是一位擅长洪荒神话编辑流的网文作家。玄幻新变种，核心公式：
  1. 设定：主角能修改洪荒历史和神话设定（如"盘古其实没死"、"三清是冒牌货"）
  2. 爽点：修改设定后，神话人物的反应（三清懵了、女娲傻眼）
  3. 节奏：每章修改1个神话设定+1次神话人物反应+1次实力提升
  4. 描写重点：修改设定时的天地异象、神话人物的震惊、新历史的合理性
  5. 知识储备：需要对洪荒神话有一定了解，修改要有逻辑

  快捷指令响应：
  - "修改神话" → 生成一个有趣的神话修改方案
  - "神话人物反应" → 设计三清/女娲等人物的震惊反应
  - "天地异象" → 生成修改设定时的天地异象描写
```

---

**预设分类标签：**

| 分类 | 预设 |
|------|------|
| 都市 | 赘婿、神医、战神、县城振兴、发疯怼人、长生家族、高武守夜人、职业系统、摸鱼摆烂、直播短视频 |
| 玄幻 | 签到、系统、无敌、修仙职场、天命反派、洪荒神话 |
| 穿越 | 种田、年代重生、整顿亲情 |
| 悬疑 | 灵异捉鬼、盗墓探险、规则怪谈、女性刑侦 |
| 女频 | 无CP大女主、恶毒女配洗白 |

**预设切换UI：**
- 顶部风格选择栏支持按分类筛选
- 搜索框可按关键词搜索预设
- 最近使用预设置顶显示
- 收藏预设单独列表


### 7.3 预设切换UI

**创作页顶部增加风格选择Chip：**
```dart
class StyleSelectorBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final presets = ref.watch(tomatoPresetsProvider);
    final currentPreset = ref.watch(currentPresetProvider);

    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('风格', style: TextStyle(fontSize: 12)),
                backgroundColor: Colors.grey[200],
              ),
            );
          }
          final preset = presets[index - 1];
          final isSelected = currentPreset?.id == preset.id;

          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(preset.name, style: TextStyle(fontSize: 12)),
              selected: isSelected,
              selectedColor: NovelTheme.primary,
              onSelected: (_) => ref.read(currentPresetProvider.notifier).select(preset.id),
            ),
          );
        },
      ),
    );
  }
}
```

**长按预设Chip显示详情：**
```dart
void _showPresetDetail(TomatoPreset preset) {
  showModalBottomSheet(
    context: context,
    builder: (context) => Container(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(preset.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(preset.description, style: TextStyle(color: Colors.grey[600])),
          SizedBox(height: 16),
          Text('风格特点', style: TextStyle(fontWeight: FontWeight.bold)),
          ...preset.tags.map((tag) => Padding(
            padding: EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: NovelTheme.primary),
                SizedBox(width: 8),
                Text(tag),
              ],
            ),
          )),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: NovelTheme.primary),
              onPressed: () {
                ref.read(currentPresetProvider.notifier).select(preset.id);
                Navigator.pop(context);
              },
              child: Text('应用此风格'),
            ),
          ),
        ],
      ),
    ),
  );
}
```

### 7.4 番茄专属Agent

内置5个Agent，本地YAML格式，支持用户修改和分享。

**Agent清单（同Windows版）：**
1. 番茄大纲生成器
2. 番茄角色生成器
3. 爽点密度检查器
4. 水文检测器
5. 爆款标题生成器

（YAML内容同Windows版，此处省略）

### 7.5 Agent市场UI（番茄专区）

**Agent市场页增加"番茄专区"Tab：**
```dart
class AgentMarketplacePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Agent市场'),
          bottom: TabBar(
            tabs: [
              Tab(text: '全部'),
              Tab(text: '番茄专区'),
              Tab(text: '我的'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AllAgentsView(),
            _TomatoZoneView(),      // 番茄专区
            _MyAgentsView(),
          ],
        ),
      ),
    );
  }
}

class _TomatoZoneView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tomatoAgents = ref.watch(tomatoAgentsProvider);

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: tomatoAgents.length,
      itemBuilder: (context, index) {
        final agent = tomatoAgents[index];
        return TomatoAgentCard(agent: agent);
      },
    );
  }
}

class TomatoAgentCard extends StatelessWidget {
  final TomatoAgent agent;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(agent.icon, style: TextStyle(fontSize: 32)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(agent.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(agent.description, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            // 快捷操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.play_arrow, size: 18),
                    label: Text('运行'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NovelTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => _runAgent(agent),
                  ),
                ),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: Icon(Icons.settings, size: 18),
                  label: Text('配置'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => _configAgent(agent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### 7.6 爽点报告UI

```dart
class ShuangdianReportPage extends StatelessWidget {
  final ShuangdianReport report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('爽点密度报告')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // 总评分
          _ScoreCard(score: report.score),

          // 爽点列表
          _SectionHeader('本章爽点 (${report.shuangdianList.length}个)'),
          ...report.shuangdianList.map((sd) => ShuangdianItemCard(shuangdian: sd)),

          // 建议
          if (report.suggestions.isNotEmpty) ...[
            _SectionHeader('优化建议'),
            ...report.suggestions.map((s) => ListTile(
              leading: Icon(Icons.lightbulb, color: Colors.amber),
              title: Text(s, style: TextStyle(fontSize: 14)),
            )),
          ],
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final int score;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text('爽点密度评分', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$score', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: NovelTheme.primary)),
                Text('/10', style: TextStyle(fontSize: 20, color: Colors.grey)),
              ],
            ),
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: score / 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  score >= 8 ? Colors.green : score >= 6 ? Colors.orange : Colors.red,
                ),
                minHeight: 12,
              ),
            ),
            SizedBox(height: 8),
            Text(
              score >= 8 ? '爽点密集，读者会看得很爽！' :
              score >= 6 ? '爽点尚可，建议再增加1-2个' :
              '爽点不足，读者可能会流失，建议立即优化',
              style: TextStyle(color: score >= 8 ? Colors.green : score >= 6 ? Colors.orange : Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

class ShuangdianItemCard extends StatelessWidget {
  final ShuangdianItem shuangdian;

  @override
  Widget build(BuildContext context) {
    final color = shuangdian.intensity == '大' ? Colors.red :
                  shuangdian.intensity == '中' ? Colors.orange : Colors.blue;

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Center(
            child: Text(
              shuangdian.intensity,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        title: Text(shuangdian.type, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(shuangdian.description, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text('${shuangdian.position}%', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ),
    );
  }
}
```

### 7.7 水文报告UI

```dart
class WaterReportPage extends StatelessWidget {
  final WaterReport report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('水文检测报告')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // 水文率
          _WaterRateCard(rate: report.waterRate),

          // 疑似水文段落
          if (report.waterSegments.isNotEmpty) ...[
            _SectionHeader('疑似水文段落 (${report.waterSegments.length}处)'),
            ...report.waterSegments.map((seg) => WaterSegmentCard(segment: seg)),
          ] else ...[
            Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, size: 64, color: Colors.green),
                    SizedBox(height: 16),
                    Text('本章无水文，节奏紧凑！', style: TextStyle(fontSize: 16, color: Colors.green)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WaterRateCard extends StatelessWidget {
  final double rate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text('本章水文率', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('${rate.toStringAsFixed(1)}%', style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: rate < 15 ? Colors.green : rate < 30 ? Colors.orange : Colors.red,
            )),
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: rate / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  rate < 15 ? Colors.green : rate < 30 ? Colors.orange : Colors.red,
                ),
                minHeight: 12,
              ),
            ),
            SizedBox(height: 8),
            Text(
              rate < 15 ? '节奏紧凑，继续保持！' :
              rate < 30 ? '略有水文，建议优化' :
              '水文严重，读者可能会流失',
              style: TextStyle(
                color: rate < 15 ? Colors.green : rate < 30 ? Colors.orange : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WaterSegmentCard extends StatelessWidget {
  final WaterSegment segment;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(segment.type, style: TextStyle(fontSize: 12, color: Colors.blue[700])),
                ),
                Spacer(),
                Text('${segment.wordCount}字', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            SizedBox(height: 8),
            Text('第${segment.startLine}-${segment.endLine}行', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text(segment.suggestion, style: TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 7.8 标题生成结果UI

```dart
class TitleGeneratorResultPage extends StatelessWidget {
  final List<GeneratedTitle> titles;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('爆款标题生成')),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: titles.length,
        itemBuilder: (context, index) {
          final title = titles[index];
          return Card(
            margin: EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: NovelTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: NovelTheme.primary)),
                ),
              ),
              title: Text(title.text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text(title.analysis, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: title.score >= 8 ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${title.score}分', style: TextStyle(
                      fontSize: 12,
                      color: title.score >= 8 ? Colors.green[700] : Colors.orange[700],
                    )),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.copy, size: 20),
                    onPressed: () => _copyTitle(title.text),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

### 7.9 数据模型

```dart
// lib/data/models/tomato_preset_model.dart
@freezed
class TomatoPreset with _$TomatoPreset {
  factory TomatoPreset({
    required String id,
    required String name,
    required String category,
    required String description,
    required String systemPrompt,
    required List<String> tags,
    @Default(true) bool isBuiltin,
    @Default(false) bool isCustom,
  }) = _TomatoPreset;

  factory TomatoPreset.fromJson(Map<String, dynamic> json) => _$TomatoPresetFromJson(json);
}

// lib/data/models/shuangdian_report_model.dart
@freezed
class ShuangdianReport with _$ShuangdianReport {
  factory ShuangdianReport({
    required String chapterId,
    required int score,
    required List<ShuangdianItem> shuangdianList,
    required List<String> suggestions,
  }) = _ShuangdianReport;

  factory ShuangdianReport.fromJson(Map<String, dynamic> json) => _$ShuangdianReportFromJson(json);
}

@freezed
class ShuangdianItem with _$ShuangdianItem {
  factory ShuangdianItem({
    required String type,
    required int position,
    required String intensity,
    required String description,
  }) = _ShuangdianItem;

  factory ShuangdianItem.fromJson(Map<String, dynamic> json) => _$ShuangdianItemFromJson(json);
}

// lib/data/models/water_report_model.dart
@freezed
class WaterReport with _$WaterReport {
  factory WaterReport({
    required String chapterId,
    required double waterRate,
    required List<WaterSegment> waterSegments,
  }) = _WaterReport;

  factory WaterReport.fromJson(Map<String, dynamic> json) => _$WaterReportFromJson(json);
}

@freezed
class WaterSegment with _$WaterSegment {
  factory WaterSegment({
    required int startLine,
    required int endLine,
    required String type,
    required int wordCount,
    required String suggestion,
  }) = _WaterSegment;

  factory WaterSegment.fromJson(Map<String, dynamic> json) => _$WaterSegmentFromJson(json);
}

// lib/data/models/generated_title_model.dart
@freezed
class GeneratedTitle with _$GeneratedTitle {
  factory GeneratedTitle({
    required String text,
    required int score,
    required String analysis,
  }) = _GeneratedTitle;

  factory GeneratedTitle.fromJson(Map<String, dynamic> json) => _$GeneratedTitleFromJson(json);
}
```

### 7.10 项目文件结构补充

```
android_novel_ide/lib/
├── data/
│   ├── models/
│   │   ├── tomato_preset_model.dart
│   │   ├── shuangdian_report_model.dart
│   │   ├── water_report_model.dart
│   │   └── generated_title_model.dart
│   └── datasources/
│       └── tomato_local_datasource.dart
├── presentation/
│   ├── pages/
│   │   └── tomato/                         # 新增
│   │       ├── preset_selector_sheet.dart  # 风格选择底部弹层
│   │       ├── shuangdian_report_page.dart # 爽点报告页
│   │       ├── water_report_page.dart      # 水文报告页
│   │       ├── title_generator_result_page.dart # 标题生成结果
│   │       └── widgets/
│   │           ├── style_selector_bar.dart # 顶部风格选择栏
│   │           ├── tomato_agent_card.dart  # 番茄Agent卡片
│   │           ├── score_card.dart
│   │           └── shuangdian_item_card.dart
│   └── state/
│       ├── tomato_preset_provider.dart     # 新增
│       ├── tomato_agent_provider.dart      # 新增
│       └── shuangdian_report_provider.dart # 新增
├── assets/
│   └── tomato/                             # 内置预设和Agent
│       ├── presets/
│       │   ├── urban_fanxu.yaml
│       │   ├── urban_shenyi.yaml
│       │   ├── urban_zhanshen.yaml
│       │   ├── fantasy_qiandao.yaml
│       │   ├── fantasy_xitong.yaml
│       │   ├── fantasy_wudi.yaml
│       │   ├── chuanyue_zhongtian.yaml
│       │   ├── chuanyue_niandai.yaml
│       │   ├── xuanyi_lingyi.yaml
│       │   └── daomu.yaml
│       └── agents/
│           ├── outline_generator.yaml
│           ├── character_generator.yaml
│           ├── shuangdian_checker.yaml
│           ├── water_checker.yaml
│           └── title_generator.yaml
```

### 7.11 开发路线图补充

| Sprint | 新增内容 |
|--------|---------|
| 0-1 | 基础框架 |
| 2 | ModelHub + **番茄预设切换UI** |
| 3 | 联网搜索 |
| 4 | 剧情连贯性V1 |
| 5 | 一键精修 + **番茄标题生成Agent** |
| 6 | 剧情连贯性V2 + **爽点检查Agent + 水文检测Agent** |
| 7 | AgentForge + **番茄大纲生成Agent + 角色生成Agent** |
| 8 | 导出分享 |
| 9 | 测试打包 |


## 8. 导出分享
- 勾选式导出（章节自由选择、10种内容类型可选）
- TXT格式ZIP压缩包
- 自动包含「小说记忆文件.txt」
- 使用share_plus调用系统分享
- **所有主页面AppBar都有导出按钮**（写作、作品、大纲、资料）

---

## 9. 数据存储

### 9.1 SQLite数据库

SQLite不作为唯一作品本体，主要负责索引、缓存和统计。

```text
novel_ide.db
├── novels                 # 作品索引
├── volumes                # 卷索引
├── chapters               # 章节索引、顺序、状态、字数、更新时间
├── chapter_snapshots      # 本地快照索引
├── characters_index       # 角色卡索引
├── facts_index            # 设定卡/事实卡索引
├── hooks_index            # 伏笔索引
├── search_index           # 搜索索引
├── models                 # 模型配置索引，不存明文Key
├── agents                 # Agent配置索引
├── billing_records        # 本地费用统计
└── polish_jobs            # 精修任务记录
```

### 9.2 源文件目录

作品正文和核心设定以Markdown/JSON保存，便于手动同步和跨端迁移。

```text
NovelProject/
├── project.json
├── volumes.json
├── chapter_index.json
├── chapters/*.md
├── characters.json
├── outline.json
├── facts.json
├── hooks.json
├── references/
├── prompts/
├── assets/
└── settings.json
```

### 9.3 Hive配置

```text
Hive boxes
├── app_settings           # 主题、字体、编辑器设置
├── recent_projects        # 最近打开
├── ai_preferences         # 默认模型、默认提示词、快捷动作配置
└── draft_cache            # 临时草稿缓存
```

### 9.4 安全存储
```dart
// API Key加密
final storage = FlutterSecureStorage();
await storage.write(key: 'api_key_deepseek', value: 'sk-xxx');
```

---

## 10. 隐私设计

### 10.1 三级隐私模式
- **严格**：强制本地模型（Ollama/LM Studio via Termux）
- **均衡**：本地脱敏后上传
- **云端**：直接上传

### 10.2 脱敏（本地执行）
```dart
String sanitize(String text, String novelId) {
  // 本地替换：人名→[角色A]、地名→[地点1]
  // 返回后本地还原
}
```

---

## 11. 性能指标

| 指标 | 目标 |
|------|------|
| 首屏启动 | <2秒 |
| 章节打开（1万字） | <1秒 |
| AI首token延迟 | 取决于用户网络和模型API |
| 离线功能可用率 | 100%（除AI外） |

---

## 12. 开发路线图

### 12.1 Android V1：完整写作闭环

| Sprint | 周期 | 目标 |
|--------|------|------|
| 0 | 2周 | Flutter框架、Riverpod、SQLite/Hive、源文件目录初始化 |
| 1 | 2周 | 新建作品/卷/章节、章节树、章节排序、章节状态 |
| 2 | 2周 | TextField单章编辑器、自动保存、防丢稿快照、异常恢复 |
| 3 | 1.5周 | API Key配置、AI聊天抽屉、AI续写、AI润色、AI起标题 |
| 4 | 1.5周 | 语音输入、查找、字数统计、夜间模式、字体设置 |
| 5 | 2周 | 导入/导出源文件目录、导入/导出`.novelpack`、Markdown/TXT导出 |
| 6 | 1周 | 性能优化、真机测试、打包APK |

### 12.2 Android V2：小说管理增强

| 模块 | 内容 | 状态 |
|------|------|------|
| 资料管理 | 角色卡、设定卡、地点、势力、道具、伏笔 | ✅ 已实现 |
| 大纲增强 | 主线大纲编辑、分卷大纲、章节梗概 | ✅ 已实现 |
| 番茄辅助 | 爽点检查报告UI、水文检测报告UI、标题生成结果页 | ✅ 已实现 |
| 精修增强 | 卡片式逐段精修、采用/跳过/重新生成/插入下方 | ✅ 已实现 |
| 统计增强 | 日字数柱状图、章节进度、连续打卡、达标通知 | ✅ 已实现 |

### 12.3 Android V3：高级功能

| 模块 | 内容 | 状态 |
|------|------|------|
| AgentForge | 自定义Agent创建、Agent导入(JSON/文本)、Agent市场 | ✅ 已实现 |
| 全文审查 | 设定冲突/战力一致性/伏笔追踪/角色一致性 4种审查 | ✅ 已实现 |
| 联网查证 | 搜索结果保存到资料库、插入引用、复制链接 | ✅ 已实现 |
| 多模型路由 | 按任务类型自动选模型、费用统计(token+调用次数) | ✅ 已实现 |
| AI对话窗口 | 独立聊天页、模型切换、风格预设显示 | ✅ 已实现 |
| 导出增强 | 勾选式导出、章节自由选择、TXT格式ZIP压缩 | ✅ 已实现 |
| 小说记忆系统 | 自动更新记忆文件、AI自动读取上下文 | ✅ 已实现 |

---

## 15. 小说记忆系统（NovelMemory）

### 15.1 设计理念

类似 Claude Code 的 MEMORY.md 机制，为每部小说维护一个**持久化的创作记忆文件**。记录小说的完整状态，让任何 AI 工具都能读懂当前创作进度。

### 15.2 记忆文件结构

```
小说记忆文件 (Novel Memory File)
├── 1. 作品信息（书名、字数、章节数、主线大纲）
├── 2. 卷章结构（分卷列表、每章状态和字数）
├── 3. 最近章节摘要（最近5章）
├── 4. 角色状态（角色卡完整信息、属性标签）
├── 5. 设定状态（世界观、金手指、战力体系）
├── 6. 地点信息
├── 7. 势力信息
├── 8. 重要道具
├── 9. 伏笔追踪（未回收/已回收、闲置超过10章自动警告⚠️）
└── 10. 参考资料
```

### 15.3 自动更新机制

- **触发时机**：每次编辑器保存章节后自动调用 `NovelMemory.autoUpdate()`
- **存储路径**：`NovelProjects/memories/{novelId}_memory.txt`
- **缓存机制**：内存缓存，避免短时间内重复生成

### 15.4 AI 上下文注入

AI 对话时自动将记忆文件注入 system prompt：
```
systemPrompt = "你是网文写作助手。\n\n小说记忆文件：\n{memory_content}"
```

所有 AI 调用点都已集成：
- AI 抽屉（写作页内）
- AI 聊天页（独立页面）
- 爽点检查/水文检测/标题生成等快捷操作

### 15.5 导出包含

每次导出 ZIP 中自动包含 `小说记忆文件.txt`，方便：
- 其他 AI 工具读取完整上下文
- 跨设备迁移时恢复创作状态
- 人类作者回顾创作进度

---

## 16. 增强导出系统

### 16.1 两种导出模式

**勾选式导出（默认）**：
- 逐项勾选要导出的内容类型
- 章节正文可逐章勾选（支持全选/全不选）
- 导出为 ZIP 压缩包，内部文件均为 TXT 格式
- 自动包含「小说记忆文件.txt」

### 16.2 可勾选项

| 类型 | 文件名 | 内容 |
|------|--------|------|
| 作品信息 | 作品信息.txt | 书名、字数、章节数 |
| 大纲 | 卷信息.txt + 主线大纲.txt | 分卷结构、主线剧情 |
| 角色 | 角色卡.txt | 完整角色设定 |
| 设定 | 设定卡.txt | 世界观、战力体系 |
| 地点 | 地点.txt | 城市、宗门、秘境 |
| 势力 | 势力.txt | 门派、国家、组织 |
| 道具 | 道具.txt | 武器、法宝、丹药 |
| 伏笔 | 伏笔.txt | 伏笔状态和回收情况 |
| 参考 | 参考资料.txt | 搜索结果、灵感笔记 |
| 记忆 | 小说记忆文件.txt | ⭐ 自动包含，不可取消 |

### 16.3 章节选择

- 列表显示每章标题、字数、状态
- 前50章直接展示，超出部分提示
- 支持全选/全不选快捷按钮

---

## 17. AI 对话窗口

### 17.1 功能

- 独立聊天页面，自由对话
- AppBar 右上角模型切换菜单（多模型时显示）
- 显示当前使用的番茄风格预设标签
- 消息气泡 UI（用户蓝色、AI 灰色）
- 支持清空对话历史
- 自动加载小说记忆文件作为上下文

### 17.2 入口

- 底部导航「AI对话」Tab
- 写作页 AI 抽屉 → 全文审查

---

## 18. AgentForge 自定义 Agent

### 18.1 创建

- 名称 + 描述 + System Prompt
- 支持从 JSON 文件导入
- 支持从纯文本文件导入（内容作为 Prompt）

### 18.2 导入格式

**JSON 格式**：
```json
{
  "name": "我的大纲助手",
  "description": "帮我生成小说大纲",
  "systemPrompt": "你是一位专业的小说大纲生成器..."
}
```

**纯文本格式**：整个文件内容作为 System Prompt，文件名作为 Agent 名称。

### 18.3 运行

- 与内置 Agent 共用运行页面
- 支持参数输入
- 结果展示在消息气泡中

---

## 19. 项目文件结构（V3 完整）

```
lib/
├── main.dart                              # 入口，启动时加载数据
├── core/
│   ├── constants.dart                     # 主题、颜色、字符串
│   └── router.dart                        # 路由配置
├── data/
│   ├── datasources/
│   │   ├── database_helper.dart           # SQLite (v3: novels/volumes/chapters/snapshots/ai_configs/daily_words/billing_records)
│   │   ├── local_file_datasource.dart     # 文件系统操作、ZIP导入导出
│   │   └── secure_storage_datasource.dart # API Key 加密存储
│   ├── models/
│   │   ├── novel_model.dart               # Freezed
│   │   ├── chapter_model.dart             # Freezed + ChapterStatus
│   │   ├── volume_model.dart              # Freezed
│   │   ├── snapshot_model.dart            # Freezed
│   │   ├── ai_config_model.dart           # Freezed
│   │   ├── tomato_preset_model.dart       # Freezed
│   │   ├── tomato_agent_model.dart        # Freezed
│   │   ├── material_models.dart           # Character/SettingCard/Location/Faction/Item/PlotHook/Reference/SettingReminder
│   │   └── search_result_model.dart       # SearchResult
│   ├── presets/
│   │   └── tomato_presets_data.dart       # 25个番茄预设
│   ├── repositories/
│   │   ├── novel_repository.dart
│   │   ├── chapter_repository.dart
│   │   ├── volume_repository.dart
│   │   ├── material_repository.dart       # 8种材料类型 CRUD
│   │   └── stats_repository.dart          # 统计查询、打卡计算
│   └── services/
│       ├── ai_service.dart                # 统一AI调用 + 费用追踪
│       ├── config_service.dart            # Hive 持久化配置
│       ├── connectivity_service.dart      # 网络状态监控
│       ├── cost_tracker.dart              # 费用统计 (billing_records)
│       ├── model_router.dart              # 按任务类型选模型
│       ├── notification_service.dart      # 本地通知
│       └── novel_memory.dart              # ⭐ 小说记忆系统
├── presentation/
│   ├── pages/
│   │   ├── main_shell.dart                # 5-Tab 底部导航
│   │   ├── ai/
│   │   │   ├── ai_drawer.dart             # 写作页内AI抽屉（含记忆上下文）
│   │   │   ├── ai_chat_page.dart          # ⭐ 独立AI对话页（含记忆上下文+模型切换）
│   │   │   ├── polish_engine_page.dart     # 一键精修（卡片式审阅）
│   │   │   ├── search_drawer.dart          # 联网搜索（保存到资料库+插入引用）
│   │   │   ├── setting_reminder_page.dart  # 设定提醒
│   │   │   └── full_text_review_page.dart  # ⭐ 全文审查（4种审查类型）
│   │   ├── materials/materials_page.dart   # 资料管理（8个Tab）+ 右上角设置按钮
│   │   ├── outline/outline_page.dart       # 大纲（含主线大纲编辑+导出按钮）
│   │   ├── profile/profile_page.dart       # 设置页（从"我的"Tab移入资料页设置按钮）
│   │   ├── stats/stats_page.dart           # ⭐ 写作统计（fl_chart）
│   │   ├── tomato/
│   │   │   ├── agent_marketplace_page.dart # Agent市场（含自定义Agent创建+导入）
│   │   │   ├── style_selector_bar.dart     # 风格选择栏
│   │   │   ├── shuangdian_report_page.dart # ⭐ 爽点报告
│   │   │   ├── water_report_page.dart      # ⭐ 水文报告
│   │   │   └── title_generator_result_page.dart # ⭐ 标题生成结果
│   │   ├── works/
│   │   │   ├── works_page.dart             # 作品列表（含导出按钮）
│   │   │   ├── novel_detail_page.dart      # 卷章管理（卷+章均支持长按菜单）
│   │   │   └── export_page.dart            # ⭐ 勾选式导出系统
│   │   └── writing/
│   │       ├── writing_page.dart            # 写作引导页（含导出按钮）
│   │       └── editor_page.dart             # 编辑器（导出+自动保存+记忆更新+undo/redo）
│   └── state/
│       └── app_providers.dart              # 全部Riverpod providers + 数据加载函数
```

---

## 20. 版本历史

| 版本 | 日期 | 主要内容 |
|------|------|----------|
| V1.0.0 | 2026-05 | 基础框架、作品管理、编辑器、AI基础动作、导入导出 |
| V1.3.0 | 2026-05 | V1 Bug修复(10个) + V2全功能 + V3全功能 |
| V1.3.1 | 2026-05 | AI对话窗口、导出系统重写、小说记忆系统、Agent导入 |

### 已修复的已知问题
- 材料数据重启丢失（角色/设定/伏笔/参考的增删未持久化）
- AI配置重启丢失（apiKey未从SecureStorage加载）
- 字数统计重复计数（autoSave/dispose双重调用）
- 打卡天数今天归零（未考虑当天未写的情况）
- 导出失败 Bytes required（改用share_plus）
- flutter_local_notifications构建失败（需coreLibraryDesugaring）
- 存储权限缺失（App从未请求运行时权限，添加permission_handler）
- 卷缺少长按菜单（二级页面无法重命名/删除）
- CI编译错误：_showRenameVolumeDialog跨类访问（提取为顶层函数）

---

## 13. 与Windows版关系

| 方面 | 说明 |
|------|------|
| 账号 | 无，两端完全独立 |
| 数据同步 | 无自动同步，用户手动同步源文件或`.novelpack` |
| AI配置 | 各自独立设置，不共享API Key |
| 作品迁移 | 导出源文件目录或`.novelpack` → 手动传输 → 导入 |
| 功能关系 | Android是完整移动端IDE，不是Windows附属工具 |
| 数据格式 | 统一JSON Schema + Markdown章节正文，便于手动迁移 |
| 冲突处理 | 手动同步时如发生同一章节双端修改，导入时提示保留两版或手动合并 |

---

## 14. 关键取舍

1. **先保证能长期写，不先追求炫功能**：V1核心是作品、卷章、正文、保存、导入导出、AI基础动作。
2. **AI是写作动作，不是首页主角**：AI通过浮动按钮、底部抽屉和选中文字菜单进入。
3. **SQLite不是作品本体**：作品正文和设定必须能以源文件形式存在，方便手动同步。
4. **防丢稿优先级高于Agent和复杂审查**：自动保存、快照、异常恢复必须进入V1。
5. **番茄模块先轻后重**：V1做续写、标题、爽点、节奏；V2/V3再做完整预设市场和Agent。

---

## 21. 软件配置文件系统 (AppConfig)

### 21.1 设计理念

类似 Claude Code 的 `settings.json`，用户可通过编辑 JSON 配置文件自定义软件行为。

### 21.2 配置文件位置

`documents/app_config.json`

### 21.3 默认配置结构

```json
{
  "editor": {
    "fontSize": 18.0,
    "fontFamily": "NotoSerifSC",
    "lineHeight": 1.8,
    "autoSaveDelayMs": 1500,
    "snapshotIntervalMinutes": 3,
    "maxSnapshotsPerChapter": 20,
    "maxCharsForContext": 2000
  },
  "ai": {
    "defaultTaskType": "chat",
    "autoLoadMemory": true,
    "memoryMaxChars": 5000,
    "temperature": 1.0,
    "maxTokens": 4096
  },
  "stats": {
    "dailyWordGoal": 3000,
    "reminderHour": 21,
    "reminderMinute": 0
  },
  "export": {
    "format": "txt",
    "includeMemory": true,
    "chapterOrder": "by_index"
  },
  "ui": {
    "darkMode": false,
    "showWordCount": true,
    "showSaveStatus": true
  }
}
```

### 21.4 使用方式

- "资料"页 → 右上角齿轮按钮 → "软件配置" → 编辑 JSON → 保存 → 重启生效
- 支持 dot-notation 读取：`AppConfig().get('editor.fontSize')`
- 支持深度合并：用户配置自动与默认配置合并

---

## 22. AI 对话增强

### 22.1 底部导航Tab

AI 对话作为独立 Tab（写作/作品/大纲/资料/**AI对话**），不再是子页面。原「我的」Tab 已移除，内容合并到资料页右上角设置按钮。

### 22.2 会话管理

- 新建会话（右上角+）
- 会话历史列表（左上角时钟图标）
- 删除历史会话
- 首条消息自动作为会话标题

### 22.3 自动上下文压缩

对话超过 40 条消息时自动触发压缩：
1. 取前 30 条消息
2. 调用 AI 压缩为 200 字摘要
3. 保留最近 10 条消息 + 摘要
4. 类似 Claude Code 的 compaction 机制

### 22.4 预设选择

预设选择器从编辑器移到 AI 对话页，作用是：
- 选择番茄风格后，AI 对话自动使用对应 systemPrompt
- 让 AI 知道要写什么框架的内容

---

## 23. AI 模型配置增强

### 23.1 多协议支持

| 协议 | 适用服务 |
|------|----------|
| OpenAI 兼容 | DeepSeek、通义千问、Moonshot、GPT、Ollama |
| Anthropic | Claude API |

### 23.2 功能

- **测试连接**：验证 API Key + URL + 模型是否正确
- **获取模型列表**：调用 `/models` 接口获取可用模型下拉列表
- **自动填充**：切换协议时自动填充默认 URL 和模型名

### 23.3 API 请求格式

**OpenAI 兼容：**
```json
{
  "model": "deepseek-chat",
  "messages": [{"role": "user", "content": "..."}],
  "temperature": 1.0,
  "max_tokens": 4096
}
```

**Anthropic：**
```json
{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 4096,
  "system": "system prompt",
  "messages": [{"role": "user", "content": "..."}]
}
```

---

## 24. UI/UX 改进记录

### 24.1 编辑器

- ✅ AppBar 右上角：导出按钮 + 保存按钮 + 查找 + 更多菜单
- ✅ 底部工具栏：undo/redo + 保存
- ✅ 移除编辑器内的预设选择器（移到 AI 对话页）
- ✅ 移除底部预设标签（避免与键盘重叠）

### 24.2 作品和章节

- ✅ 作品长按弹出菜单：重命名 / 删除
- ✅ 章节长按弹出菜单：重命名 / 删除
- ✅ 卷长按弹出菜单：重命名 / 删除
- ✅ 删除确认对话框

### 24.3 导出

- ✅ 勾选式导出（10种内容类型可选）
- ✅ 章节自由选择（全选/逐章勾选）
- ✅ 导出为 ZIP 压缩包（内部 TXT 格式）
- ✅ 自动包含「小说记忆文件.txt」
- ✅ 所有主页面AppBar都有导出按钮（写作/作品/大纲/资料）

---

## 25. 开发 Bug 修复心得

### 25.1 Android 构建类问题

| 问题 | 原因 | 修复 |
|------|------|------|
| `minSdkVersion 21 cannot be smaller than 23` | flutter_secure_storage 要求 API 23 | 改 `minSdk = 23` |
| `compileSdk 35 too low` | flutter_secure_storage 要求 36 | 改 `compileSdk = 36` |
| `ndkVersion mismatch` | 7个插件要求 NDK 27.0 | 改 `ndkVersion = "27.0.12077973"` |
| `Missing mipmap/ic_launcher` | Android 资源目录缺失 | 补全 res/ 目录和 PNG 图标 |
| `coreLibraryDesugaring required` | flutter_local_notifications 需要 Java 8+ | 添加 `desugar_jdk_libs` 依赖 |
| `Gradle download timeout` | CI 网络不稳定 | 重新触发 workflow |

**教训**：升级 Flutter 版本后，务必检查 `compileSdk`、`minSdk`、`ndkVersion` 和所有插件的兼容性要求。

### 25.2 依赖冲突

| 问题 | 原因 | 修复 |
|------|------|------|
| `speech_to_text 6.6.2` 编译失败 | 使用了已废弃的 Flutter Registrar API | 升级到 `^7.4.0` |
| `share_plus 9.x` 与 `speech_to_text 7.x` 冲突 | `web` 包版本不兼容 | 升级 `share_plus` 到 `^10.0.0` |

**教训**：`pubspec.yaml` 中 `^` 约束只保证主版本兼容。Flutter 大版本升级时，需要逐个检查所有插件的最新版本。

### 25.3 数据持久化问题

| 问题 | 原因 | 修复 |
|------|------|------|
| 材料数据重启丢失 | Provider 是内存状态，没有从文件加载 | 选中作品时调用 `loadNovelMaterials()` |
| AI 配置重启丢失 | `loadAiConfigs` 缺少 apiKey 字段 | 从 SecureStorage 读取 apiKey |
| AI 调用代码重复 3 处 | 每处直接写 `Dio.post()` | 提取 `AiService` 统一封装 |

**教训**：使用 `StateProvider` 时，必须在 `initState` 或合适时机从持久化存储加载初始值。

### 25.4 字数统计问题

| 问题 | 原因 | 修复 |
|------|------|------|
| 字数重复计数 | `_saveChapter` 在 autoSave 和 dispose 中双重调用 | 用 `_lastSavedWordCount` 守卫 |
| 打卡天数今天归零 | 从今天开始计算，今天没写就 break | 跳过今天空数据，从昨天开始 |

**教训**：涉及计数/统计的功能，需要防止并发和重复调用导致的数据膨胀。

### 25.5 网络和代理

| 问题 | 原因 | 修复 |
|------|------|------|
| git push 连不上 GitHub | 国内网络限制 | Watt Toolkit 加速（hosts 模式） |
| curl API 返回 403 | Watt Toolkit hosts 拦截 HTTPS | 确保 Watt Toolkit 运行 |
| CI 构建 Gradle 下载失败 | GitHub Runner 网络不稳定 | 重新触发 workflow |

**教训**：国内开发必须配置 GitHub 加速。Watt Toolkit 的 hosts 模式兼容性好于代理模式。

### 25.6 导出功能

| 问题 | 原因 | 修复 |
|------|------|------|
| 导出失败 "Bytes required" | `FilePicker.saveFile()` 在 Android 需要字节 | 改用 `Share.shareXFiles()` |

**教训**：`file_picker` 的 `saveFile` 在 Android 上需要提供 bytes 参数，`share_plus` 更通用。

---

## 26. 版本历史（完整）

| 版本 | 日期 | 主要内容 |
|------|------|----------|
| V1.0.0 | 2026-05 | 基础框架、作品管理、编辑器、AI基础动作、导入导出 |
| V1.1.0 | 2026-05 | 资料管理扩展（地点/势力/道具）、大纲增强、番茄报告UI |
| V1.2.0 | 2026-05 | 写作统计、通知服务、全文审查、多模型路由、AgentForge |
| V1.3.0 | 2026-05 | AI对话窗口、导出重写、小说记忆系统、Agent导入 |
| V1.3.1 | 2026-05 | 多协议支持、测试连接、获取模型、UI重构、配置文件、上下文压缩 |
| V1.3.2 | 2026-05 | 运行时权限请求、卷长按重命名/删除、"我的"移至设置按钮、所有页面导出按钮、补全19项Android权限 |

---

## 27. 项目文件统计

| 类别 | 数量 |
|------|------|
| Dart 源文件 | 60+ |
| 代码行数（手写） | ~15,000+ |
| 提交次数 | 30+ |
| 数据库表 | 7（novels/volumes/chapters/snapshots/ai_configs/daily_words/billing_records） |
| 番茄预设 | 25个 |
| 内置 Agent | 5个 |
| AI 模型协议 | 2（OpenAI兼容 / Anthropic） |
| 资料类型 | 8（角色/设定/地点/势力/道具/伏笔/参考/记忆） |
| Android权限 | 19项（存储/网络/通知/前台服务/后台/振动/音频等） |

---

## 28. V1.3.2 改进详情

### 28.1 运行时权限系统

- App启动时自动请求存储、麦克风、通知权限
- 使用 `permission_handler` 包（^11.3.1）
- AndroidManifest 声明 19 项权限，覆盖所有功能需求
- 启动时弹出系统权限授权对话框

### 28.2 卷长按菜单

- 卷标题支持长按弹出底部菜单
- 菜单项：重命名卷、删除卷
- 删除卷会同时删除该卷下所有章节（带确认对话框）

### 28.3 底部导航重构

- 从 6 Tab 减为 5 Tab（写作/作品/大纲/资料/AI对话）
- 「我的」页面内容移至资料页右上角齿轮设置按钮
- 设置页面包含：AI模型配置、Agent市场、字数目标、写作统计、深色模式、字体设置、软件配置、备份恢复

### 28.4 全页面导出按钮

- 写作页（引导页+编辑器）AppBar 右上角
- 作品页 AppBar 右上角
- 大纲页 AppBar 右上角
- 资料页 AppBar 右上角
- 点击统一进入勾选式导出页面


import 'dart:convert';
import 'package:novel_ide/data/models/material_models.dart';
import 'package:novel_ide/data/models/chapter_model.dart';
import 'package:novel_ide/data/models/writing_skill_model.dart';
import 'package:novel_ide/data/repositories/material_repository.dart';
import 'package:novel_ide/data/repositories/chapter_repository.dart';
import 'package:novel_ide/data/repositories/skill_repository.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';
import 'package:novel_ide/data/services/novel_memory.dart';
import 'package:novel_ide/data/services/workspace_agent.dart';
import 'package:novel_ide/data/services/workflow_engine.dart';
import 'package:uuid/uuid.dart';

/// 注册所有Agent工具执行器
/// 将工具名连接到实际的数据操作
void registerAllToolExecutors({
  required WorkspaceAgent agent,
  required String novelId,
  required String novelTitle,
}) {
  final materialRepo = MaterialRepository();
  final chapterRepo = ChapterRepository();
  final fs = LocalFileDataSource();
  final skillRepo = SkillRepository();
  final uuid = Uuid();

  // ====== 读取类工具 ======

  agent.registerExecutor('get_novel_info', (args) async {
    final chapters = await chapterRepo.getChaptersByNovel(novelId);
    final totalWords = chapters.fold<int>(0, (sum, c) => sum + c.wordCount);
    return ToolResult(
      toolName: 'get_novel_info',
      success: true,
      message: '小说信息：\n标题：$novelTitle\nID：$novelId\n章节数：${chapters.length}\n总字数：$totalWords',
    );
  });

  agent.registerExecutor('get_characters', (args) async {
    final characters = await materialRepo.getCharacters(novelId);
    if (characters.isEmpty) return ToolResult(toolName: 'get_characters', success: true, message: '暂无角色');
    final info = characters.map((c) => '- ${c.name}${c.role != null ? " (${c.role})" : ""}：${c.description ?? "无描述"}').join('\n');
    return ToolResult(toolName: 'get_characters', success: true, message: '角色列表（${characters.length}个）：\n$info');
  });

  agent.registerExecutor('get_settings', (args) async {
    final settings = await materialRepo.getSettingCards(novelId);
    if (settings.isEmpty) return ToolResult(toolName: 'get_settings', success: true, message: '暂无设定');
    final info = settings.map((s) => '- ${s.name}${s.category != null ? " [${s.category}]" : ""}：${s.description ?? "无内容"}').join('\n');
    return ToolResult(toolName: 'get_settings', success: true, message: '设定列表（${settings.length}个）：\n$info');
  });

  agent.registerExecutor('get_locations', (args) async {
    final locations = await materialRepo.getLocations(novelId);
    if (locations.isEmpty) return ToolResult(toolName: 'get_locations', success: true, message: '暂无地点');
    final info = locations.map((l) => '- ${l.name}${l.category != null ? " [${l.category}]" : ""}：${l.description ?? "无描述"}').join('\n');
    return ToolResult(toolName: 'get_locations', success: true, message: '地点列表（${locations.length}个）：\n$info');
  });

  agent.registerExecutor('get_factions', (args) async {
    final factions = await materialRepo.getFactions(novelId);
    if (factions.isEmpty) return ToolResult(toolName: 'get_factions', success: true, message: '暂无势力');
    final info = factions.map((f) => '- ${f.name}${f.category != null ? " [${f.category}]" : ""}：${f.description ?? "无描述"}').join('\n');
    return ToolResult(toolName: 'get_factions', success: true, message: '势力列表（${factions.length}个）：\n$info');
  });

  agent.registerExecutor('get_items', (args) async {
    final items = await materialRepo.getItems(novelId);
    if (items.isEmpty) return ToolResult(toolName: 'get_items', success: true, message: '暂无道具');
    final info = items.map((i) => '- ${i.name}${i.category != null ? " [${i.category}]" : ""}：${i.description ?? "无描述"}').join('\n');
    return ToolResult(toolName: 'get_items', success: true, message: '道具列表（${items.length}个）：\n$info');
  });

  agent.registerExecutor('get_hooks', (args) async {
    final hooks = await materialRepo.getPlotHooks(novelId);
    if (hooks.isEmpty) return ToolResult(toolName: 'get_hooks', success: true, message: '暂无伏笔');
    final info = hooks.map((h) => '- ${h.title} [${h.isRevealed ? "已回收" : "待回收"}]：${h.description ?? "无描述"}').join('\n');
    return ToolResult(toolName: 'get_hooks', success: true, message: '伏笔列表（${hooks.length}个）：\n$info');
  });

  agent.registerExecutor('get_references', (args) async {
    final refs = await materialRepo.getReferences(novelId);
    if (refs.isEmpty) return ToolResult(toolName: 'get_references', success: true, message: '暂无参考');
    final info = refs.map((r) => '- ${r.title}：${r.content ?? "无内容"}').join('\n');
    return ToolResult(toolName: 'get_references', success: true, message: '参考列表（${refs.length}个）：\n$info');
  });

  agent.registerExecutor('get_chapters', (args) async {
    final chapters = await chapterRepo.getChaptersByNovel(novelId);
    if (chapters.isEmpty) return ToolResult(toolName: 'get_chapters', success: true, message: '暂无章节');
    final info = chapters.map((c) => '- ${c.title}（${c.wordCount}字）').join('\n');
    return ToolResult(toolName: 'get_chapters', success: true, message: '章节列表（${chapters.length}章）：\n$info');
  });

  agent.registerExecutor('get_chapter_content', (args) async {
    final title = args['chapter_title'] as String? ?? '';
    final chapters = await chapterRepo.getChaptersByNovel(novelId);
    final match = chapters.where((c) => c.title.contains(title));
    if (match.isEmpty) return ToolResult(toolName: 'get_chapter_content', success: false, message: '未找到匹配的章节');
    final chapter = match.first;
    final projectPath = await fs.getProjectDir(novelId, novelTitle);
    final content = await fs.readChapterContent(projectPath, chapter.id);
    return ToolResult(toolName: 'get_chapter_content', success: true, message: '【${chapter.title}】\n$content');
  });

  agent.registerExecutor('get_memory', (args) async {
    final memory = NovelMemory(novelId: novelId, novelTitle: novelTitle);
    final content = await memory.autoUpdate();
    return ToolResult(toolName: 'get_memory', success: true, message: content.isEmpty ? '记忆包为空' : content);
  });

  // ====== 写入类工具 ======

  agent.registerExecutor('add_character', (args) async {
    final name = args['name'] as String? ?? '';
    final role = args['role'] as String?;
    final description = args['description'] as String?;
    if (name.isEmpty) return ToolResult(toolName: 'add_character', success: false, message: '角色名称不能为空');
    final characters = await materialRepo.getCharacters(novelId);
    characters.add(Character(id: uuid.v4(), novelId: novelId, name: name, role: role, description: description));
    await materialRepo.saveCharacters(novelId, characters);
    return ToolResult(toolName: 'add_character', success: true, message: '已添加角色：$name');
  });

  agent.registerExecutor('add_setting', (args) async {
    final name = args['name'] as String? ?? '';
    final category = args['category'] as String?;
    final description = args['description'] as String?;
    if (name.isEmpty) return ToolResult(toolName: 'add_setting', success: false, message: '设定名称不能为空');
    final settings = await materialRepo.getSettingCards(novelId);
    settings.add(SettingCard(id: uuid.v4(), novelId: novelId, name: name, category: category, description: description));
    await materialRepo.saveSettingCards(novelId, settings);
    return ToolResult(toolName: 'add_setting', success: true, message: '已添加设定：$name');
  });

  agent.registerExecutor('add_location', (args) async {
    final name = args['name'] as String? ?? '';
    final category = args['category'] as String?;
    final description = args['description'] as String?;
    if (name.isEmpty) return ToolResult(toolName: 'add_location', success: false, message: '地点名称不能为空');
    final locations = await materialRepo.getLocations(novelId);
    locations.add(Location(id: uuid.v4(), novelId: novelId, name: name, category: category, description: description));
    await materialRepo.saveLocations(novelId, locations);
    return ToolResult(toolName: 'add_location', success: true, message: '已添加地点：$name');
  });

  agent.registerExecutor('add_faction', (args) async {
    final name = args['name'] as String? ?? '';
    final category = args['category'] as String?;
    final description = args['description'] as String?;
    if (name.isEmpty) return ToolResult(toolName: 'add_faction', success: false, message: '势力名称不能为空');
    final factions = await materialRepo.getFactions(novelId);
    factions.add(Faction(id: uuid.v4(), novelId: novelId, name: name, category: category, description: description));
    await materialRepo.saveFactions(novelId, factions);
    return ToolResult(toolName: 'add_faction', success: true, message: '已添加势力：$name');
  });

  agent.registerExecutor('add_item', (args) async {
    final name = args['name'] as String? ?? '';
    final category = args['category'] as String?;
    final description = args['description'] as String?;
    if (name.isEmpty) return ToolResult(toolName: 'add_item', success: false, message: '道具名称不能为空');
    final items = await materialRepo.getItems(novelId);
    items.add(Item(id: uuid.v4(), novelId: novelId, name: name, category: category, description: description));
    await materialRepo.saveItems(novelId, items);
    return ToolResult(toolName: 'add_item', success: true, message: '已添加道具：$name');
  });

  agent.registerExecutor('add_hook', (args) async {
    final title = args['title'] as String? ?? '';
    final description = args['description'] as String?;
    if (title.isEmpty) return ToolResult(toolName: 'add_hook', success: false, message: '伏笔标题不能为空');
    final hooks = await materialRepo.getPlotHooks(novelId);
    hooks.add(PlotHook(id: uuid.v4(), novelId: novelId, title: title, description: description));
    await materialRepo.savePlotHooks(novelId, hooks);
    return ToolResult(toolName: 'add_hook', success: true, message: '已添加伏笔：$title');
  });

  agent.registerExecutor('add_reference', (args) async {
    final title = args['title'] as String? ?? '';
    final content = args['content'] as String?;
    if (title.isEmpty) return ToolResult(toolName: 'add_reference', success: false, message: '参考标题不能为空');
    final refs = await materialRepo.getReferences(novelId);
    refs.add(ReferenceMaterial(id: uuid.v4(), novelId: novelId, title: title, content: content));
    await materialRepo.saveReferences(novelId, refs);
    return ToolResult(toolName: 'add_reference', success: true, message: '已添加参考：$title');
  });

  // ====== 编辑类工具 ======

  agent.registerExecutor('update_character', (args) async {
    final name = args['name'] as String? ?? '';
    if (name.isEmpty) return ToolResult(toolName: 'update_character', success: false, message: '角色名称不能为空');
    final characters = await materialRepo.getCharacters(novelId);
    final idx = characters.indexWhere((c) => c.name == name);
    if (idx < 0) return ToolResult(toolName: 'update_character', success: false, message: '未找到角色：$name');
    if (args['role'] != null) characters[idx] = Character(id: characters[idx].id, novelId: novelId, name: name, role: args['role'] as String?, description: args['description'] as String? ?? characters[idx].description);
    await materialRepo.saveCharacters(novelId, characters);
    return ToolResult(toolName: 'update_character', success: true, message: '已更新角色：$name');
  });

  agent.registerExecutor('update_hook_status', (args) async {
    final title = args['title'] as String? ?? '';
    final status = args['status'] as String? ?? 'planted';
    if (title.isEmpty) return ToolResult(toolName: 'update_hook_status', success: false, message: '伏笔标题不能为空');
    final hooks = await materialRepo.getPlotHooks(novelId);
    final idx = hooks.indexWhere((h) => h.title == title);
    if (idx < 0) return ToolResult(toolName: 'update_hook_status', success: false, message: '未找到伏笔：$title');
    final isRevealed = status == 'resolved';
    hooks[idx] = PlotHook(id: hooks[idx].id, novelId: novelId, title: title, description: hooks[idx].description, isRevealed: isRevealed);
    await materialRepo.savePlotHooks(novelId, hooks);
    return ToolResult(toolName: 'update_hook_status', success: true, message: '已更新伏笔「$title」状态为：${isRevealed ? "已回收" : "待回收"}');
  });

  // ====== 分析类工具 ======

  agent.registerExecutor('analyze_plot_consistency', (args) async {
    final chapters = await chapterRepo.getChaptersByNovel(novelId);
    final hooks = await materialRepo.getPlotHooks(novelId);
    final characters = await materialRepo.getCharacters(novelId);
    final idleHooks = hooks.where((h) => !h.isRevealed).length;
    return ToolResult(
      toolName: 'analyze_plot_consistency',
      success: true,
      message: '剧情一致性分析：\n- 章节数：${chapters.length}\n- 角色数：${characters.length}\n- 未回收伏笔：$idleHooks\n\n请根据以上数据和小说内容进行详细分析。',
    );
  });

  agent.registerExecutor('check_idle_hooks', (args) async {
    final hooks = await materialRepo.getPlotHooks(novelId);
    final planted = hooks.where((h) => !h.isRevealed).toList();
    if (planted.isEmpty) return ToolResult(toolName: 'check_idle_hooks', success: true, message: '没有未回收的伏笔');
    final info = planted.map((h) => '- ${h.title}（闲置${h.idleChapters}章）：${h.description ?? "无描述"}').join('\n');
    return ToolResult(toolName: 'check_idle_hooks', success: true, message: '闲置伏笔（${planted.length}个）：\n$info');
  });

  agent.registerExecutor('generate_chapter_outline', (args) async {
    final direction = args['direction'] as String? ?? '';
    final chapters = await chapterRepo.getChaptersByNovel(novelId);
    final recentTitles = chapters.length > 3 ? chapters.sublist(chapters.length - 3).map((c) => c.title).join('、') : '无';
    return ToolResult(
      toolName: 'generate_chapter_outline',
      success: true,
      message: '请根据以下信息生成下一章大纲：\n- 当前共${chapters.length}章\n- 最近章节：$recentTitles\n- 写作方向：${direction.isEmpty ? "无特殊要求" : direction}',
    );
  });

  agent.registerExecutor('character_relationship_map', (args) async {
    final characters = await materialRepo.getCharacters(novelId);
    if (characters.isEmpty) return ToolResult(toolName: 'character_relationship_map', success: true, message: '暂无角色');
    final info = characters.map((c) => '${c.name}${c.role != null ? "(${c.role})" : ""}').join('、');
    return ToolResult(toolName: 'character_relationship_map', success: true, message: '角色列表：$info\n请根据小说内容分析角色之间的关系。');
  });

  // ====== Skill工具 ======

  agent.registerExecutor('get_skills', (args) async {
    final context = await skillRepo.getEnabledSkillsContext();
    return ToolResult(toolName: 'get_skills', success: true, message: context.isEmpty ? '没有启用的写作技能' : context);
  });

  agent.registerExecutor('add_skill', (args) async {
    final name = args['name'] as String? ?? '';
    final category = args['category'] as String? ?? '通用';
    final description = args['description'] as String? ?? '';
    final content = args['content'] as String? ?? '';
    if (name.isEmpty) return ToolResult(toolName: 'add_skill', success: false, message: '技能名称不能为空');
    final skill = skillRepo.createSkill(name: name, category: category, description: description, content: content);
    await skillRepo.addSkill(skill);
    return ToolResult(toolName: 'add_skill', success: true, message: '已添加技能：$name');
  });

  // ====== 子代理和工作流 ======

  agent.registerExecutor('delegate_to_sub_agent', (args) async {
    final taskType = args['task_type'] as String? ?? '';
    final instruction = args['instruction'] as String? ?? '';
    return ToolResult(
      toolName: 'delegate_to_sub_agent',
      success: true,
      message: '子代理任务已接收：\n- 类型：$taskType\n- 指令：$instruction\n\n请根据指令执行任务。',
    );
  });

  agent.registerExecutor('run_workflow', (args) async {
    final workflowName = args['workflow_name'] as String? ?? '';
    final workflow = WorkflowPresets.all.where((w) => w.id == workflowName).firstOrNull;
    if (workflow == null) {
      return ToolResult(
        toolName: 'run_workflow',
        success: false,
        message: '未找到工作流：$workflowName\n可用工作流：${WorkflowPresets.all.map((w) => w.id).join(', ')}',
      );
    }

    // 依次执行工作流步骤
    final results = <String>[];
    for (final step in workflow.steps) {
      final executor = agent.getExecutor(step.toolName);
      if (executor != null) {
        try {
          final result = await executor(step.toolArgs);
          results.add('✅ ${step.name}：${result.message}');
        } catch (e) {
          results.add('❌ ${step.name}：执行失败 $e');
        }
      } else {
        results.add('⚠️ ${step.name}：工具未注册');
      }
    }

    return ToolResult(
      toolName: 'run_workflow',
      success: true,
      message: '工作流「${workflow.name}」执行完成：\n\n${results.join('\n')}',
    );
  });
}

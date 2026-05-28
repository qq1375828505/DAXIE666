import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'dart:convert';
import 'dart:io';
import 'package:novel_ide/data/models/writing_skill_model.dart';
import 'package:novel_ide/data/repositories/skill_repository.dart';

final skillsProvider = FutureProvider<List<WritingSkill>>((ref) async {
  final repo = SkillRepository();
  return repo.getAllSkills();
});

/// Skill管理页面
class SkillManagePage extends ConsumerStatefulWidget {
  const SkillManagePage({super.key});

  @override
  ConsumerState<SkillManagePage> createState() => _SkillManagePageState();
}

class _SkillManagePageState extends ConsumerState<SkillManagePage> {
  final SkillRepository _repo = SkillRepository();

  @override
  Widget build(BuildContext context) {
    final skillsAsync = ref.watch(skillsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skill'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: '导入Skill',
            onPressed: () => _importSkill(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建Skill',
            onPressed: () => _showSkillDialog(),
          ),
        ],
      ),
      body: skillsAsync.when(
        data: (skills) {
          if (skills.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('暂无Skill', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showSkillDialog(),
                    child: const Text('新建Skill'),
                  ),
                ],
              ),
            );
          }

          // 按分类分组
          final categories = <String, List<WritingSkill>>{};
          for (final skill in skills) {
            categories.putIfAbsent(skill.category, () => []).add(skill);
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // 启用状态统计
              _buildStatsBar(skills),
              const SizedBox(height: 12),
              // 按分类展示
              ...categories.entries.map((entry) => _buildCategorySection(entry.key, entry.value)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Widget _buildStatsBar(List<WritingSkill> skills) {
    final enabled = skills.where((s) => s.isEnabled).length;
    final builtIn = skills.where((s) => s.isBuiltIn).length;
    final custom = skills.length - builtIn;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('全部', '${skills.length}'),
          _statItem('已启用', '$enabled', color: Colors.green),
          _statItem('内置', '$builtIn'),
          _statItem('自定义', '$custom', color: Colors.blue),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildCategorySection(String category, List<WritingSkill> skills) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ...skills.map((skill) => _buildSkillCard(skill)),
      ],
    );
  }

  Widget _buildSkillCard(WritingSkill skill) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: skill.isEnabled
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.grey[200],
          child: Icon(
            skill.isBuiltIn ? Icons.auto_awesome : Icons.edit_note,
            color: skill.isEnabled
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(skill.name, style: const TextStyle(fontWeight: FontWeight.w500)),
            if (skill.isBuiltIn)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('内置', style: TextStyle(fontSize: 10, color: Colors.orange)),
              ),
          ],
        ),
        subtitle: Text(
          skill.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: skill.isEnabled,
              onChanged: (val) => _toggleSkill(skill, val),
            ),
            if (!skill.isBuiltIn)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _showSkillDialog(skill: skill);
                  if (value == 'delete') _deleteSkill(skill);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('编辑')),
                  const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
                ],
              ),
          ],
        ),
        onTap: () => _showSkillDetail(skill),
      ),
    );
  }

  void _toggleSkill(WritingSkill skill, bool enabled) {
    skill.isEnabled = enabled;
    _repo.updateSkill(skill);
    ref.invalidate(skillsProvider);
  }

  void _deleteSkill(WritingSkill skill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除Skill「${skill.name}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _repo.deleteSkill(skill.id);
              ref.invalidate(skillsProvider);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _importSkill() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'txt', 'json', 'docx'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      final fileName = result.files.first.name;
      final nameWithoutExt = fileName.replaceAll(RegExp(r'\.(md|txt|json|docx)$'), '');
      
      // 读取文件内容
      String content;
      if (fileName.endsWith('.docx')) {
        // docx 是 zip 格式，需要解压读取
        content = await _readDocxContent(file);
      } else {
        content = await file.readAsString();
      }

      // 尝试解析为JSON，否则作为纯文本处理
      Map<String, dynamic>? skillData;
      try {
        if (content.trimLeft().startsWith('{')) {
          skillData = jsonDecode(content) as Map<String, dynamic>;
        }
      } catch (_) {}

      final newSkill = _repo.createSkill(
        name: skillData?['name'] as String? ?? nameWithoutExt,
        category: skillData?['category'] as String? ?? '导入',
        description: skillData?['description'] as String? ?? '从 $fileName 导入',
        content: skillData?['content'] as String? ?? content.trim(),
        keywords: (skillData?['keywords'] as List<dynamic>?)?.cast<String>() ?? [],
      );
      await _repo.addSkill(newSkill);
      ref.invalidate(skillsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导入 Skill: ${newSkill.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  /// 读取 docx 文件的文本内容
  Future<String> _readDocxContent(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    // 查找 word/document.xml
    for (final archiveFile in archive) {
      if (archiveFile.name == 'word/document.xml') {
        final content = String.fromCharCodes(archiveFile.content as List<int>);
        // 简单提取文本内容（去除XML标签）
        final text = content
            .replaceAll(RegExp(r'<[^>]+>'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        return text;
      }
    }
    throw Exception('无法读取 docx 文件内容');
  }

  void _showSkillDetail(WritingSkill skill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${skill.name}  ${skill.category} · ${skill.isEnabled ? "已启用" : "已禁用"}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(skill.description, style: TextStyle(color: Colors.grey[700])),
              const Divider(),
              Text(skill.content, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
          if (!skill.isBuiltIn)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showSkillDialog(skill: skill);
              },
              child: const Text('编辑'),
            ),
        ],
      ),
    );
  }

  void _showSkillDialog({WritingSkill? skill}) {
    final isEdit = skill != null;
    final nameCtrl = TextEditingController(text: skill?.name ?? '');
    final catCtrl = TextEditingController(text: skill?.category ?? '通用');
    final descCtrl = TextEditingController(text: skill?.description ?? '');
    final contentCtrl = TextEditingController(text: skill?.content ?? '');
    final kwCtrl = TextEditingController(text: skill?.keywords.join('、') ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? '编辑Skill' : '新建Skill'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Skill名称')),
              const SizedBox(height: 12),
              TextField(controller: catCtrl, decoration: const InputDecoration(labelText: '分类')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述'), maxLines: 2),
              const SizedBox(height: 12),
              TextField(
                controller: kwCtrl,
                decoration: const InputDecoration(
                  labelText: '匹配关键词（用顿号分隔）',
                  hintText: '例如：伏笔、悬念、埋线',
                  helperText: 'AI对话中出现这些词时自动触发此Skill',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                decoration: const InputDecoration(labelText: 'Skill内容（详细说明/Prompt）'),
                maxLines: 8,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              if (isEdit) {
                skill!.name = nameCtrl.text.trim();
                skill.category = catCtrl.text.trim();
                skill.description = descCtrl.text.trim();
                skill.content = contentCtrl.text.trim();
                skill.keywords = _parseKeywords(kwCtrl.text);
                _repo.updateSkill(skill);
              } else {
                final newSkill = _repo.createSkill(
                  name: nameCtrl.text.trim(),
                  category: catCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  content: contentCtrl.text.trim(),
                  keywords: _parseKeywords(kwCtrl.text),
                );
                _repo.addSkill(newSkill);
              }
              ref.invalidate(skillsProvider);
              Navigator.pop(ctx);
            },
            child: Text(isEdit ? '保存' : '添加'),
          ),
        ],
      ),
    );
  }

  List<String> _parseKeywords(String text) {
    return text.split(RegExp(r'[、,，\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

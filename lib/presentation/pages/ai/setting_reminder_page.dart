import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/material_models.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:uuid/uuid.dart';

class SettingReminderPage extends ConsumerStatefulWidget {
  final String novelId;
  final TextEditingController editorController;

  const SettingReminderPage({super.key, required this.novelId, required this.editorController});

  @override
  ConsumerState<SettingReminderPage> createState() => _SettingReminderPageState();
}

class _SettingReminderPageState extends ConsumerState<SettingReminderPage> {
  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(settingRemindersProvider(widget.novelId));
    final chars = ref.watch(charactersProvider(widget.novelId));
    final settings = ref.watch(settingCardsProvider(widget.novelId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('设定提醒'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: '扫描当前章节',
            onPressed: _scanCurrentChapter,
          ),
        ],
      ),
      body: reminders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('暂无设定提醒', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  Text('点击右上角扫描当前章节', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('手动添加提醒'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reminders.length,
              itemBuilder: (context, index) {
                final reminder = reminders[index];
                final hasConflict = reminder.conflicts.isNotEmpty;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: hasConflict ? AppColors.error.withOpacity(0.05) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.track_changes, size: 18, color: hasConflict ? AppColors.error : AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(reminder.keyword, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                              onPressed: () {
                                final list = ref.read(settingRemindersProvider(widget.novelId))
                                    .where((r) => r.id != reminder.id)
                                    .toList();
                                ref.read(settingRemindersProvider(widget.novelId).notifier).state = list;
                              },
                            ),
                          ],
                        ),
                        if (reminder.relatedCharacter != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Chip(
                              label: Text(reminder.relatedCharacter!, style: const TextStyle(fontSize: 11)),
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              side: BorderSide.none,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        if (reminder.note != null) ...[
                          const SizedBox(height: 8),
                          Text(reminder.note!, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        ],
                        if (hasConflict) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber, size: 16, color: AppColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '潜在冲突：${reminder.conflicts.join('、')}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _scanCurrentChapter() {
    final text = widget.editorController.text;
    if (text.isEmpty) return;

    final chars = ref.read(charactersProvider(widget.novelId));
    final settings = ref.read(settingCardsProvider(widget.novelId));
    final existingReminders = List<SettingReminder>.from(ref.read(settingRemindersProvider(widget.novelId)));

    int newCount = 0;

    for (final char in chars) {
      final mentions = char.name.allMatches(text).length;
      if (mentions > 0 && !existingReminders.any((r) => r.relatedCharacter == char.name)) {
        final tags = char.tags.map((t) => t.key).toList();
        final conflicts = <String>[];
        for (final set in settings) {
          final setMentions = set.name.allMatches(text).length;
          if (setMentions > 0) {
            for (final tag in set.tags) {
              if (tags.contains(tag.key)) {
                conflicts.add('${set.name}(${tag.key})');
              }
            }
          }
        }
        existingReminders.add(SettingReminder(
          id: const Uuid().v4(),
          novelId: widget.novelId,
          keyword: char.name,
          relatedCharacter: char.name,
          note: '本章出现${mentions}次',
          conflicts: conflicts,
        ));
        newCount++;
      }
    }

    for (final set in settings) {
      final mentions = set.name.allMatches(text).length;
      if (mentions > 0 && !existingReminders.any((r) => r.relatedSetting == set.name)) {
        existingReminders.add(SettingReminder(
          id: const Uuid().v4(),
          novelId: widget.novelId,
          keyword: set.name,
          relatedSetting: set.name,
          note: '本章提及${mentions}次',
        ));
        newCount++;
      }
    }

    for (final reminder in existingReminders.toList()) {
      if (reminder.keyword.allMatches(text).isEmpty) {
        existingReminders.remove(reminder);
      }
    }

    ref.read(settingRemindersProvider(widget.novelId).notifier).state = existingReminders;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newCount > 0 ? '发现$newCount个新提醒' : '没有新发现')),
      );
    }
  }

  void _showAddDialog() {
    final keywordCtrl = TextEditingController();
    final charCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加设定提醒'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: keywordCtrl, decoration: const InputDecoration(labelText: '关键词', hintText: '例如：主角的剑')),
              const SizedBox(height: 12),
              TextField(controller: charCtrl, decoration: const InputDecoration(labelText: '关联角色（可选）')),
              const SizedBox(height: 12),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: '备注', hintText: '例如：注意武器归属'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (keywordCtrl.text.trim().isEmpty) return;
              final reminder = SettingReminder(
                id: const Uuid().v4(),
                novelId: widget.novelId,
                keyword: keywordCtrl.text.trim(),
                relatedCharacter: charCtrl.text.trim().isEmpty ? null : charCtrl.text.trim(),
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              );
              final list = ref.read(settingRemindersProvider(widget.novelId));
              ref.read(settingRemindersProvider(widget.novelId).notifier).state = [...list, reminder];
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}

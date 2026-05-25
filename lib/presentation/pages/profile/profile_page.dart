import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/core/router.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/datasources/secure_storage_datasource.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/services/config_service.dart';
import 'package:novel_ide/presentation/pages/stats/stats_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(darkModeProvider);
    final configs = ref.watch(aiConfigsProvider);
    final wordGoal = ref.watch(wordGoalProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final currentPreset = ref.watch(currentPresetProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: const Icon(Icons.person, size: 40, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                const Text('网文作者', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('单机版 · 数据本地存储', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(title: 'AI 模型配置', onAdd: () => _showAddAiConfigDialog(context, ref)),
          if (configs.isEmpty)
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined, color: Colors.grey),
              title: Text('未配置AI模型', style: TextStyle(color: Colors.grey[500])),
              subtitle: const Text('点击右上角 + 添加模型'),
              onTap: () => _showAddAiConfigDialog(context, ref),
            )
          else
            ...configs.map((config) => _AiConfigTile(config: config)),
          const Divider(),

          _SectionHeader(title: '番茄写作'),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: AppColors.tomatoRed),
            title: const Text('Agent市场'),
            subtitle: const Text('番茄大纲生成器、爽点检查器、水文检测器等'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, AppRouter.agents);
            },
          ),
          const SizedBox(height: 4),
          ListTile(
            leading: const Icon(Icons.edit_calendar),
            title: const Text('每日字数目标'),
            subtitle: Text('目标：$wordGoal字/天'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () {
                    final newGoal = (wordGoal - 500).clamp(500, 20000);
                    ref.read(wordGoalProvider.notifier).state = newGoal;
                    ConfigService.wordGoal = newGoal;
                  },
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '$wordGoal',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () {
                    final newGoal = (wordGoal + 500).clamp(500, 20000);
                    ref.read(wordGoalProvider.notifier).state = newGoal;
                    ConfigService.wordGoal = newGoal;
                  },
                ),
              ],
            ),
          ),
          // Stats entry
          ListTile(
            leading: const Icon(Icons.bar_chart, color: AppColors.primary),
            title: const Text('写作统计'),
            subtitle: const Text('查看字数趋势和打卡记录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatsPage()),
              );
            },
          ),
          const Divider(),

          _SectionHeader(title: '外观'),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('深色模式'),
            trailing: Switch(
              value: isDark,
              onChanged: (value) {
                ref.read(darkModeProvider.notifier).state = value;
                ConfigService.isDarkMode = value;
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.font_download),
            title: const Text('字体设置'),
            subtitle: Text('字号：${fontSize.toInt()}px'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFontSettingsDialog(context, ref),
          ),
          const Divider(),

          _SectionHeader(title: '数据管理'),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('备份所有作品'),
            subtitle: const Text('导出为 .novelpack 压缩包'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('恢复备份'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: AppColors.error),
            title: const Text('清空所有数据', style: TextStyle(color: AppColors.error)),
            onTap: () => _showClearDataDialog(context, ref),
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            subtitle: const Text('网文写作IDE v1.0.0 · 完全单机运行'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showFontSettingsDialog(BuildContext context, WidgetRef ref) {
    final fontSize = ref.read(fontSizeProvider);
    final lineHeight = ref.read(lineHeightProvider);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('字体设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('字号'),
              Row(
                children: [
                  const Text('14', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: fontSize,
                      min: 14,
                      max: 24,
                      divisions: 10,
                      label: '${fontSize.toInt()}',
                      onChanged: (v) {
                        ref.read(fontSizeProvider.notifier).state = v;
                        ConfigService.fontSize = v;
                        setDialogState(() {});
                      },
                    ),
                  ),
                  const Text('24', style: TextStyle(fontSize: 12)),
                ],
              ),
              Text('当前：${fontSize.toInt()}px', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              const SizedBox(height: 16),
              const Text('行高'),
              Row(
                children: [
                  const Text('1.4', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: lineHeight,
                      min: 1.2,
                      max: 2.4,
                      divisions: 12,
                      label: lineHeight.toStringAsFixed(1),
                      onChanged: (v) {
                        ref.read(lineHeightProvider.notifier).state = v;
                        ConfigService.lineHeight = v;
                        setDialogState(() {});
                      },
                    ),
                  ),
                  const Text('2.4', style: TextStyle(fontSize: 12)),
                ],
              ),
              Text('当前：${lineHeight.toStringAsFixed(1)}', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAiConfigDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'https://api.openai.com/v1/chat/completions');
    final modelCtrl = TextEditingController(text: 'gpt-3.5-turbo');
    final keyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加AI模型'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '名称', hintText: '例如：DeepSeek'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'API地址'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(labelText: '模型名'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(labelText: 'API Key'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) return;
              final config = AiConfig(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameCtrl.text.trim(),
                apiUrl: urlCtrl.text.trim(),
                modelName: modelCtrl.text.trim(),
              );
              if (keyCtrl.text.isNotEmpty) {
                await SecureStorageDataSource().writeApiKey(config.id, keyCtrl.text.trim());
              }
              // Persist to SQLite
              await DatabaseHelper().insertAiConfig({
                'id': config.id,
                'name': config.name,
                'api_url': config.apiUrl,
                'model_name': config.modelName,
                'temperature': config.temperature,
                'max_tokens': config.maxTokens,
                'is_local': config.isLocal ? 1 : 0,
              });
              final currentList = ref.read(aiConfigsProvider);
              ref.read(aiConfigsProvider.notifier).state = [...currentList, config];
              ref.read(selectedAiConfigProvider.notifier).state = config;
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有数据'),
        content: const Text('此操作将删除所有作品、章节和设置，不可恢复。确定继续吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('数据已清空')),
              );
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;
  const _SectionHeader({required this.title, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[600])),
          const Spacer(),
          if (onAdd != null) IconButton(icon: const Icon(Icons.add, size: 20), onPressed: onAdd),
        ],
      ),
    );
  }
}

class _AiConfigTile extends ConsumerWidget {
  final AiConfig config;
  const _AiConfigTile({required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(selectedAiConfigProvider)?.id == config.id;
    return ListTile(
      leading: Icon(Icons.smart_toy, color: isSelected ? AppColors.primary : Colors.grey),
      title: Text(config.name),
      subtitle: Text('${config.modelName} · ${config.isLocal ? '本地' : '云端'}'),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
      onTap: () {
        ref.read(selectedAiConfigProvider.notifier).state = config;
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('删除 ${config.name}？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () async {
                  final list = ref.read(aiConfigsProvider).where((c) => c.id != config.id).toList();
                  ref.read(aiConfigsProvider.notifier).state = list;
                  if (ref.read(selectedAiConfigProvider)?.id == config.id) {
                    ref.read(selectedAiConfigProvider.notifier).state = list.isNotEmpty ? list.first : null;
                  }
                  // Delete from SQLite and SecureStorage
                  await DatabaseHelper().deleteAiConfig(config.id);
                  await SecureStorageDataSource().deleteApiKey(config.id);
                  Navigator.pop(context);
                },
                child: const Text('删除'),
              ),
            ],
          ),
        );
      },
    );
  }
}

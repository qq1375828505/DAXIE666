import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/datasources/secure_storage_datasource.dart';
import 'package:novel_ide/data/services/config_service.dart';
import 'package:novel_ide/data/services/default_config_service.dart';

class AiConfigListPage extends ConsumerWidget {
  const AiConfigListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(aiConfigsProvider);
    final selectedId = ref.watch(selectedAiConfigProvider)?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 模型配置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加自定义模型',
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: configs.isEmpty
          ? const Center(child: Text('未配置AI模型', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: configs.length + (configs.any((c) => c.name.contains('智谱AI')) ? 0 : 1),
              itemBuilder: (context, index) {
                // 底部快捷入口
                if (index == configs.length) {
                  return ListTile(
                    leading: const Icon(Icons.add_circle, color: Colors.green),
                    title: const Text('添加智谱AI所有免费模型'),
                    subtitle: const Text('GLM-4.7-Flash、多模态、视觉等5个模型'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await DefaultConfigService.addAllFreeModels();
                      await loadAiConfigs(ref);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已添加所有智谱AI免费模型'), backgroundColor: Colors.green),
                        );
                      }
                    },
                  );
                }

                final config = configs[index];
                final isSelected = config.id == selectedId;
                final isBuiltin = DefaultConfigService.isBuiltinConfig(config.id);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: isSelected ? 3 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isSelected ? BorderSide(color: AppColors.primary, width: 2) : BorderSide.none,
                  ),
                  color: isSelected ? AppColors.primary.withOpacity(0.08) : null,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Icon(
                      Icons.smart_toy,
                      color: isSelected ? AppColors.primary : Colors.grey,
                    ),
                    title: Row(
                      children: [
                        Text(
                          config.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 15,
                          ),
                        ),
                        if (isBuiltin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('内置', style: TextStyle(fontSize: 11, color: Colors.orange)),
                          ),
                        ],
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('使用中', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${config.modelName} · ${_extractDomain(config.apiUrl)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: isBuiltin
                        ? null  // 内置模型不显示菜单
                        : PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'use') {
                                ConfigService.aiConfigId = config.id;
                                ref.read(selectedAiConfigProvider.notifier).state = config;
                              } else if (value == 'delete') {
                                _showDeleteConfirm(context, ref, config);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'use', child: Text('使用这个模型')),
                              const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                    onTap: () {
                      ConfigService.aiConfigId = config.id;
                      ref.read(selectedAiConfigProvider.notifier).state = config;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已切换到「${config.name}」'), duration: const Duration(seconds: 1)),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return url.length > 30 ? '${url.substring(0, 30)}...' : url;
    }
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, AiConfig config) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${config.name}」？'),
        content: const Text('删除后无法恢复，确定要删除吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final list = ref.read(aiConfigsProvider).where((c) => c.id != config.id).toList();
              ref.read(aiConfigsProvider.notifier).state = list;
              if (ref.read(selectedAiConfigProvider)?.id == config.id) {
                if (list.isNotEmpty) {
                  ConfigService.aiConfigId = list.first.id;
                  ref.read(selectedAiConfigProvider.notifier).state = list.first;
                } else {
                  ConfigService.aiConfigId = '';
                  ref.read(selectedAiConfigProvider.notifier).state = null;
                }
              }
              await DatabaseHelper().deleteAiConfig(config.id);
              await SecureStorageDataSource().deleteApiKey(config.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    // 简化的添加对话框 - 和profile_page中的类似但更简洁
    // 复用 profile_page 中的 _showAddAiConfigDialog 逻辑
    // 由于该方法在 _ProfilePageState 中是私有的，这里需要重新实现
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final keyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加自定义模型'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '配置名称', prefixIcon: Icon(Icons.label))),
              const SizedBox(height: 12),
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'API 地址', prefixIcon: Icon(Icons.link))),
              const SizedBox(height: 12),
              TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: '模型 ID', prefixIcon: Icon(Icons.memory))),
              const SizedBox(height: 12),
              TextField(controller: keyCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'API Key', prefixIcon: Icon(Icons.key))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final url = urlCtrl.text.trim();
              final model = modelCtrl.text.trim();
              final key = keyCtrl.text.trim();
              if (name.isEmpty || url.isEmpty || model.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('名称、API地址、模型ID不能为空'), backgroundColor: Colors.orange));
                return;
              }
              final db = DatabaseHelper();
              final config = AiConfig(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                apiUrl: url,
                modelName: model,
              );
              await db.insertAiConfig(db.toDbMap(config));
              if (key.isNotEmpty) {
                await SecureStorageDataSource().writeApiKey(config.id, key);
              }
              await loadAiConfigs(ref);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已添加「$name」'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}

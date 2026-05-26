import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/core/router.dart';
import 'package:novel_ide/core/theme/app_themes.dart';
import 'package:novel_ide/core/theme/skin_provider.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/datasources/secure_storage_datasource.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/services/config_service.dart';
import 'package:novel_ide/presentation/pages/stats/stats_page.dart';
import 'package:novel_ide/data/services/model_test_service.dart';
import 'package:novel_ide/presentation/pages/profile/app_config_page.dart';
import 'package:novel_ide/presentation/pages/profile/user_memory_page.dart';

/// 智能补全 API 地址
/// 根据用户填的 URL 和协议类型自动补全：
/// - 已包含 /chat/completions → 不变
/// - 以 /v1 结尾 → 补全 /chat/completions
/// - 以 /anthropic 结尾 → 补全 /v1/messages（Anthropic协议）
/// - 其他 → 补全 /v1/chat/completions
String _normalizeApiUrl(String url, ApiProtocol protocol) {
  url = url.trim();
  if (url.isEmpty) return url;

  // 已经是完整路径，直接返回
  if (url.contains('/chat/completions')) return url;
  if (url.contains('/v1/messages')) return url;

  // Anthropic 协议特殊处理
  if (protocol == ApiProtocol.anthropic) {
    if (url.endsWith('/anthropic')) return '$url/v1/messages';
    if (url.endsWith('/v1')) return '$url/messages';
    if (!url.endsWith('/')) url = '$url/';
    return '${url}v1/messages';
  }

  // OpenAI 兼容协议
  if (url.endsWith('/v1')) return '$url/chat/completions';
  if (!url.endsWith('/')) url = '$url/';
  return '${url}v1/chat/completions';
}

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

          _SectionHeader(title: 'AI 写作'),
          ListTile(
            leading: const Icon(Icons.psychology, color: AppColors.secondary),
            title: const Text('用户记忆'),
            subtitle: const Text('记录您的写作风格和AI偏好，AI对话时自动读取'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const UserMemoryPage()));
            },
          ),
          const SizedBox(height: 4),

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
          // 主题皮肤选择器
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.palette, size: 24),
                    const SizedBox(width: 16),
                    const Text('主题皮肤', style: TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                _SkinSelector(),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.font_download),
            title: const Text('字体设置'),
            subtitle: Text('字号：${fontSize.toInt()}px'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFontSettingsDialog(context, ref),
          ),
          // Software config
          ListTile(
            leading: const Icon(Icons.code, color: Colors.teal),
            title: const Text('软件配置'),
            subtitle: const Text('修改配置文件自定义软件行为'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AppConfigPage()));
            },
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
    ApiProtocol selectedProtocol = ApiProtocol.openaiCompatible;
    bool isTesting = false;
    bool isFetchingModels = false;
    List<String> fetchedModels = [];

    // Update URL based on protocol
    void updateUrlForProtocol(ApiProtocol protocol) {
      if (protocol == ApiProtocol.anthropic) {
        urlCtrl.text = 'https://api.anthropic.com/v1/messages';
        modelCtrl.text = 'claude-sonnet-4-20250514';
      } else {
        urlCtrl.text = 'https://api.openai.com/v1/chat/completions';
        modelCtrl.text = 'gpt-3.5-turbo';
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('添加AI模型'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Protocol selector
                const Text('API 协议', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<ApiProtocol>(
                  segments: const [
                    ButtonSegment(value: ApiProtocol.openaiCompatible, label: Text('OpenAI 兼容'), icon: Icon(Icons.language, size: 16)),
                    ButtonSegment(value: ApiProtocol.anthropic, label: Text('Anthropic'), icon: Icon(Icons.smart_toy, size: 16)),
                  ],
                  selected: {selectedProtocol},
                  onSelectionChanged: (sel) {
                    selectedProtocol = sel.first;
                    updateUrlForProtocol(selectedProtocol);
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称', hintText: '例如：DeepSeek / Claude')),
                const SizedBox(height: 12),
                TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'API 地址', hintText: '例如：https://api.deepseek.com')),
                const SizedBox(height: 12),
                // Model field
                TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: '模型名', hintText: '例如：gpt-4o / claude-sonnet-4-20250514')),
                const SizedBox(height: 8),
                // Fetch models button (prominent)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: isFetchingModels
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download, size: 18),
                    label: Text(isFetchingModels ? '获取中...' : '获取模型列表'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: isFetchingModels ? null : () async {
                      setDialogState(() => isFetchingModels = true);
                      try {
                        final tempConfig = AiConfig(
                          id: 'temp', name: 'temp',
                          apiUrl: _normalizeApiUrl(urlCtrl.text, selectedProtocol), modelName: modelCtrl.text,
                          apiKey: keyCtrl.text.isNotEmpty ? keyCtrl.text : null,
                          protocol: selectedProtocol,
                        );
                        final models = await ModelTestService().fetchModels(tempConfig);
                        setDialogState(() {
                          fetchedModels = models;
                          isFetchingModels = false;
                        });
                        if (models.isNotEmpty && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('获取到 ${models.length} 个模型，请在下方选择')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isFetchingModels = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('获取失败: $e'), backgroundColor: Colors.orange),
                          );
                        }
                      }
                    },
                  ),
                ),
                // Model dropdown (when fetched)
                if (fetchedModels.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: fetchedModels.contains(modelCtrl.text) ? modelCtrl.text : null,
                    hint: const Text('从列表选择模型'),
                    items: fetchedModels.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m, style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) modelCtrl.text = v;
                      setDialogState(() {});
                    },
                    decoration: InputDecoration(
                      labelText: '可用模型 (${fetchedModels.length})',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(controller: keyCtrl, decoration: const InputDecoration(labelText: 'API Key', hintText: '可选（本地模型可不填）'), obscureText: true),
                const SizedBox(height: 12),
                // Test connection button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: isTesting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_find, size: 18),
                    label: Text(isTesting ? '测试中...' : '测试连接'),
                    onPressed: isTesting ? null : () async {
                      setDialogState(() => isTesting = true);
                      try {
                        final tempConfig = AiConfig(
                          id: 'temp', name: 'temp',
                          apiUrl: _normalizeApiUrl(urlCtrl.text, selectedProtocol), modelName: modelCtrl.text,
                          apiKey: keyCtrl.text.isNotEmpty ? keyCtrl.text : null,
                          protocol: selectedProtocol,
                        );
                        final result = await ModelTestService().testConnection(tempConfig);
                        setDialogState(() => isTesting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(result), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isTesting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) return;
                final config = AiConfig(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim(),
                  apiUrl: _normalizeApiUrl(urlCtrl.text, selectedProtocol),
                  modelName: modelCtrl.text.trim(),
                  protocol: selectedProtocol,
                );
                if (keyCtrl.text.isNotEmpty) {
                  await SecureStorageDataSource().writeApiKey(config.id, keyCtrl.text.trim());
                }
                await DatabaseHelper().insertAiConfig(DatabaseHelper().toDbMap(config));
                final currentList = ref.read(aiConfigsProvider);
                ref.read(aiConfigsProvider.notifier).state = [...currentList, config];
                ref.read(selectedAiConfigProvider.notifier).state = config;
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isSelected ? AppColors.primary.withOpacity(0.05) : Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? BorderSide(color: AppColors.primary, width: 2) : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.smart_toy, color: isSelected ? Colors.white : Colors.grey[600], size: 22),
        ),
        title: Text(config.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${config.modelName}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.cloud, size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text('${config.apiUrl.split('/').take(3).join('/')}...', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(config.protocol == ApiProtocol.openaiCompatible ? 'OpenAI' : 'Anthropic', style: TextStyle(fontSize: 10, color: Colors.grey[700])),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('使用中', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            const SizedBox(width: 8),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, size: 20),
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                PopupMenuItem(
                  value: 'use',
                  enabled: !isSelected,
                  child: const Row(children: [Icon(Icons.check_circle_outline, size: 18), SizedBox(width: 8), Text('使用这个模型')]),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('编辑配置')]),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('删除', style: TextStyle(color: Colors.red))]),
                ),
              ],
              onSelected: (value) {
                if (value == 'use') {
                  ref.read(selectedAiConfigProvider.notifier).state = config;
                } else if (value == 'delete') {
                  _showDeleteConfirm(context, ref, config);
                } else if (value == 'edit') {
                  // TODO: 编辑功能可以后续实现
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('编辑功能开发中')));
                }
              },
            ),
          ],
        ),
        onTap: isSelected ? null : () {
          ref.read(selectedAiConfigProvider.notifier).state = config;
        },
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, AiConfig config) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 ${config.name}？'),
        content: const Text('删除后无法恢复，确定要删除这个配置吗？'),
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
              await DatabaseHelper().deleteAiConfig(config.id);
              await SecureStorageDataSource().deleteApiKey(config.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 主题皮肤选择器 — 2行4列网格卡片
class _SkinSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSkin = ref.watch(skinThemeProvider);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: AppSkins.all.length,
      itemBuilder: (context, index) {
        final skin = AppSkins.all[index];
        final isSelected = currentSkin.type == skin.type;

        return GestureDetector(
          onTap: () {
            ref.read(skinThemeProvider.notifier).setSkin(skin.type);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: skin.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? skin.primary : Colors.grey.withOpacity(0.3),
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: skin.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 颜色预览条
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ColorDot(color: skin.primary, size: 14),
                    const SizedBox(width: 4),
                    _ColorDot(color: skin.secondary, size: 14),
                    const SizedBox(width: 4),
                    _ColorDot(color: skin.background, size: 14),
                  ],
                ),
                const SizedBox(height: 8),
                // 主题名
                Text(
                  skin.type.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: skin.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  skin.type.desc,
                  style: TextStyle(fontSize: 9, color: skin.textSecondary),
                ),
                if (isSelected) ...[
                  const SizedBox(height: 4),
                  Icon(Icons.check_circle, size: 14, color: skin.primary),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 小色点预览
class _ColorDot extends StatelessWidget {
  final Color color;
  final double size;
  const _ColorDot({required this.color, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 0.5),
      ),
    );
  }
}

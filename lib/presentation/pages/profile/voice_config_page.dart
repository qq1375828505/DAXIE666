import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/services/config_service.dart';
import 'package:novel_ide/data/services/ai_service.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/datasources/secure_storage_datasource.dart';

/// 语音模型配置页面
/// 只允许添加 TTS/STT 语音模型，文本模型不可用
class VoiceConfigPage extends ConsumerStatefulWidget {
  const VoiceConfigPage({super.key});

  @override
  ConsumerState<VoiceConfigPage> createState() => _VoiceConfigPageState();
}

class _VoiceConfigPageState extends ConsumerState<VoiceConfigPage> {
  @override
  Widget build(BuildContext context) {
    final allConfigs = ref.watch(aiConfigsProvider);
    // 只筛选语音类型模型
    final voiceConfigs = allConfigs.where((c) => c.modelType == ModelType.tts || c.modelType == ModelType.stt).toList();
    final currentVoiceId = ConfigService.voiceConfigId;
    final hasSelected = voiceConfigs.any((c) => c.id == currentVoiceId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('语音模型'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加语音模型',
            onPressed: () => _showAddVoiceModelDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 说明
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text('语音通话模型', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700])),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '添加 TTS 语音合成模型（如 MiMo TTS）后，语音通话功能将自动启用。\n'
                  '通话流程：语音识别(本地) → 文本模型(想答案) → 语音模型(念答案)',
                  style: TextStyle(fontSize: 13, color: Colors.blue[600]),
                ),
              ],
            ),
          ),

          // 语音模型列表
          Expanded(
            child: voiceConfigs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic_off, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('待添加', style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('尚未配置语音模型', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                        const SizedBox(height: 8),
                        Text('通话功能不可用，请先添加TTS语音模型', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('添加语音模型'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: () => _showAddVoiceModelDialog(),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: voiceConfigs.length,
                    itemBuilder: (context, index) {
                      final config = voiceConfigs[index];
                      final isSelected = config.id == currentVoiceId;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        color: isSelected ? AppColors.primary.withOpacity(0.05) : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isSelected
                              ? BorderSide(color: AppColors.primary, width: 2)
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isSelected ? AppColors.primary : Colors.grey[200],
                            child: Icon(
                              config.modelType == ModelType.tts ? Icons.record_voice_over : Icons.mic,
                              color: isSelected ? Colors.white : Colors.grey[600],
                            ),
                          ),
                          title: Text(config.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          subtitle: Text(
                            '${config.modelName} · ${config.modelType == ModelType.tts ? "TTS语音合成" : "STT语音识别"}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) Icon(Icons.check_circle, color: AppColors.primary),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _showEditVoiceModelDialog(config);
                                  if (value == 'test') _testVoiceModel(config);
                                  if (value == 'delete') _deleteVoiceModel(config);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'edit', child: Text('编辑')),
                                  const PopupMenuItem(value: 'test', child: Text('测试连接')),
                                  const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            ConfigService.voiceConfigId = config.id;
                            ref.read(selectedVoiceConfigProvider.notifier).state = config;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已切换语音模型为「${config.name}」')),
                            );
                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddVoiceModelDialog() {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'https://api.mimo.ai/v1/chat/completions');
    final modelCtrl = TextEditingController(text: 'mimo-v2.5-tts');
    final apiKeyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加语音模型'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 18, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '只能添加语音模型（TTS/STT），文本模型无法用于通话',
                        style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '模型名称', hintText: '例如：MiMo TTS'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'API地址'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(labelText: '模型ID', hintText: '例如：mimo-v2.5-tts'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apiKeyCtrl,
                decoration: const InputDecoration(labelText: 'API Key'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || modelCtrl.text.trim().isEmpty) return;

              final id = 'voice_${DateTime.now().millisecondsSinceEpoch}';
              final newConfig = AiConfig(
                id: id,
                name: nameCtrl.text.trim(),
                apiUrl: urlCtrl.text.trim(),
                modelName: modelCtrl.text.trim(),
                modelType: ModelType.tts,
                protocol: ApiProtocol.openaiCompatible,
              );

              // 保存到数据库
              final db = DatabaseHelper();
              await db.insertAiConfig(db.toDbMap(newConfig));
              // API Key 保存到安全存储
              if (apiKeyCtrl.text.trim().isNotEmpty) {
                await SecureStorageDataSource().writeApiKey(id, apiKeyCtrl.text.trim());
              }

              // 重新加载配置列表，确保 API Key 从 SecureStorage 读取并合并
              await loadAiConfigs(ref);
              // 选中这个模型
              ConfigService.voiceConfigId = id;
              final updatedConfigs = ref.read(aiConfigsProvider);
              final savedConfig = updatedConfigs.firstWhere((c) => c.id == id);
              ref.read(selectedVoiceConfigProvider.notifier).state = savedConfig;

              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已添加语音模型「${newConfig.name}」')),
                );
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _deleteVoiceModel(AiConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除语音模型「${config.name}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );

    if (confirmed == true) {
      final db = DatabaseHelper();
      await db.deleteAiConfig(config.id);
      await SecureStorageDataSource().deleteApiKey(config.id);
      if (ConfigService.voiceConfigId == config.id) {
        ConfigService.voiceConfigId = '';
        ref.read(selectedVoiceConfigProvider.notifier).state = null;
      }
      ref.invalidate(aiConfigsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除「${config.name}」')),
        );
      }
    }
  }

  /// 编辑语音模型
  void _showEditVoiceModelDialog(AiConfig config) async {
    final nameCtrl = TextEditingController(text: config.name);
    final urlCtrl = TextEditingController(text: config.apiUrl);
    final modelCtrl = TextEditingController(text: config.modelName);
    final apiKeyCtrl = TextEditingController();
    // 读取现有API Key
    final existingKey = await SecureStorageDataSource().readApiKey(config.id);
    apiKeyCtrl.text = existingKey ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑语音模型'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '模型名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'API地址'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(labelText: '模型ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apiKeyCtrl,
                decoration: const InputDecoration(labelText: 'API Key'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || modelCtrl.text.trim().isEmpty) return;

              final updatedConfig = AiConfig(
                id: config.id,
                name: nameCtrl.text.trim(),
                apiUrl: urlCtrl.text.trim(),
                modelName: modelCtrl.text.trim(),
                modelType: config.modelType,
                protocol: config.protocol,
              );

              // 更新数据库（使用insert的replace策略）
              final db = DatabaseHelper();
              await db.insertAiConfig(db.toDbMap(updatedConfig));
              // 更新API Key
              if (apiKeyCtrl.text.trim().isNotEmpty) {
                await SecureStorageDataSource().writeApiKey(config.id, apiKeyCtrl.text.trim());
              }

              ref.invalidate(aiConfigsProvider);
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已更新「${updatedConfig.name}」')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 测试语音模型连接
  Future<void> _testVoiceModel(AiConfig config) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('正在测试连接...'),
          ],
        ),
      ),
    );

    try {
      // 从SecureStorage读取API Key
      final apiKey = await SecureStorageDataSource().readApiKey(config.id);
      final testConfig = AiConfig(
        id: config.id,
        name: config.name,
        apiUrl: config.apiUrl,
        modelName: config.modelName,
        apiKey: apiKey,
        modelType: config.modelType,
        protocol: config.protocol,
      );

      final aiService = AiService();
      // 发送一个简单的测试请求
      await aiService.send(
        config: testConfig,
        systemPrompt: '你是一个测试助手',
        userMessage: '测试',
      );

      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${config.name}」连接成功'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

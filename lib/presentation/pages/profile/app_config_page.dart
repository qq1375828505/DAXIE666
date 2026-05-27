import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/services/app_config.dart';
import 'package:novel_ide/presentation/widgets/top_notification.dart';

/// App configuration viewer and editor page.
class AppConfigPage extends StatefulWidget {
  const AppConfigPage({super.key});

  @override
  State<AppConfigPage> createState() => _AppConfigPageState();
}

class _AppConfigPageState extends State<AppConfigPage> {
  late TextEditingController _ctrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await AppConfig.instance();
    setState(() {
      _ctrl = TextEditingController(text: config.toDisplayString());
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    try {
      final config = await AppConfig.instance();
      final newConfig = Map<String, dynamic>.from(
        const JsonDecoder().convert(_ctrl.text) as Map<String, dynamic>
      );
      final path = await config.configPath;
      final encoder = JsonEncoder.withIndent('  ');
      await File(path).writeAsString(encoder.convert(newConfig));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已保存，请重启应用生效'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _resetConfig() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复默认配置？'),
        content: const Text('所有自定义配置将被清除'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final config = await AppConfig.instance();
      await config.reset();
      setState(() {
        _ctrl = TextEditingController(text: config.toDisplayString());
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已恢复默认配置'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('软件配置'),
        actions: [
          IconButton(icon: const Icon(Icons.copy, size: 20), tooltip: '复制', onPressed: () {
            Clipboard.setData(ClipboardData(text: _ctrl.text));
            TopNotification.success(context, '已复制');
          }),
          IconButton(icon: const Icon(Icons.refresh, size: 20), tooltip: '重载', onPressed: _loadConfig),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Config info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue[50],
                  child: Text(
                    '编辑 JSON 配置文件来自定义软件行为。修改后保存并重启生效。\n路径: documents/app_config.json',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
                // Editor
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      controller: _ctrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                ),
                // Buttons
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.restore, size: 18),
                          label: const Text('恢复默认'),
                          onPressed: _resetConfig,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text('保存配置'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: _saveConfig,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

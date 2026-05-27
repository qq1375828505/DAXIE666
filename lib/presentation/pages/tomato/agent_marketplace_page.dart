import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/tomato_agent_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/services/ai_service.dart';
import 'package:novel_ide/presentation/widgets/top_notification.dart';

class AgentMarketplacePage extends ConsumerStatefulWidget {
  const AgentMarketplacePage({super.key});

  @override
  ConsumerState<AgentMarketplacePage> createState() => _AgentMarketplacePageState();
}

class _AgentMarketplacePageState extends ConsumerState<AgentMarketplacePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent市场'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '番茄专区'),
            Tab(text: '自定义'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _TomatoZoneView(),
          _CustomAgentsView(),
        ],
      ),
    );
  }
}

class _TomatoZoneView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agents = ref.watch(tomatoAgentsProvider);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: agents.length,
      itemBuilder: (context, index) {
        final agent = agents[index];
        return _AgentCard(
          agent: agent,
          isBuiltin: true,
          onRun: () => _runAgent(context, ref, agent),
        );
      },
    );
  }
}

class _CustomAgentsView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CustomAgentsView> createState() => _CustomAgentsViewState();
}

class _CustomAgentsViewState extends ConsumerState<_CustomAgentsView> {
  List<TomatoAgent> _customAgents = [];

  @override
  void initState() {
    super.initState();
    _loadCustomAgents();
  }

  void _loadCustomAgents() {
    // Load from hive or shared prefs - for now use in-memory
    // In production, persist to a JSON file
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final promptCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建自定义 Agent'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Agent 名称', hintText: '例如：我的大纲助手')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述'), maxLines: 2),
              const SizedBox(height: 12),
              TextField(controller: promptCtrl, decoration: const InputDecoration(labelText: 'System Prompt', hintText: '定义 Agent 的角色和行为'), maxLines: 5),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || promptCtrl.text.trim().isEmpty) return;
              final agent = TomatoAgent(
                id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text.trim(),
                icon: '🤖',
                description: descCtrl.text.trim().isEmpty ? '自定义Agent' : descCtrl.text.trim(),
                systemPrompt: promptCtrl.text.trim(),
                isBuiltin: false,
              );
              setState(() => _customAgents.add(agent));
              Navigator.pop(ctx);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _importAgent() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['yaml', 'yml', 'json', 'md', 'txt'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      final content = await file.readAsString();
      final fileName = result.files.first.name;

      // Try to parse as JSON, otherwise treat as plain text prompt
      Map<String, dynamic>? agentData;
      try {
        agentData = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        agentData = {
          'name': fileName.replaceAll(RegExp(r'\.(yaml|yml|json|md|txt)$'), ''),
          'systemPrompt': content.trim(),
        };
      }

      if (agentData == null) return;

      final agent = TomatoAgent(
        id: 'imported_${DateTime.now().millisecondsSinceEpoch}',
        name: agentData['name'] ?? agentData['title'] ?? fileName,
        icon: agentData['icon'] ?? '📥',
        description: agentData['description'] ?? '导入的 Agent',
        systemPrompt: agentData['systemPrompt'] ?? agentData['prompt'] ?? content.trim(),
        isBuiltin: false,
      );

      setState(() => _customAgents.add(agent));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导入 Agent: ${agent.name}')),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Create & Import buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('创建'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: _showCreateDialog,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('导入'),
                  onPressed: _importAgent,
                ),
              ),
            ],
          ),
        ),
        // Agent list
        Expanded(
          child: _customAgents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.code, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('还没有自定义 Agent', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      Text('点击上方按钮创建', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _customAgents.length,
                  itemBuilder: (context, index) {
                    final agent = _customAgents[index];
                    return _AgentCard(
                      agent: agent,
                      isBuiltin: false,
                      onRun: () => _runAgent(agent),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _runAgent(TomatoAgent agent) {
    final config = ref.read(selectedAiConfigProvider);
    if (config == null) {
      TopNotification.success(context, '请先配置AI模型');
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _AgentRunPage(agent: agent, config: config),
    ));
  }
}

class _AgentCard extends StatelessWidget {
  final TomatoAgent agent;
  final bool isBuiltin;
  final VoidCallback onRun;

  const _AgentCard({required this.agent, this.isBuiltin = true, required this.onRun});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(agent.icon, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(agent.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(agent.description, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('运行'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: onRun,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _runAgent(BuildContext context, WidgetRef ref, TomatoAgent agent) {
  final config = ref.read(selectedAiConfigProvider);
  if (config == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先在"我的"页面配置AI模型')),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _AgentRunPage(agent: agent, config: config),
    ),
  );
}

class _AgentRunPage extends ConsumerStatefulWidget {
  final TomatoAgent agent;
  final dynamic config;

  const _AgentRunPage({required this.agent, required this.config});

  @override
  ConsumerState<_AgentRunPage> createState() => _AgentRunPageState();
}

class _AgentRunPageState extends ConsumerState<_AgentRunPage> {
  final List<TextEditingController> _paramCtrls = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    for (final _ in widget.agent.parameterPrompts) {
      _paramCtrls.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    for (final ctrl in _paramCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _runAgent() async {
    final paramText = List.generate(widget.agent.parameterPrompts.length, (i) {
      if (_paramCtrls[i].text.trim().isEmpty) return '';
      return '${widget.agent.parameterPrompts[i]}：${_paramCtrls[i].text.trim()}';
    }).where((s) => s.isNotEmpty).join('\n');

    final input = _inputCtrl.text.trim();
    final fullInput = '$paramText\n${input.isNotEmpty ? '输入内容：$input' : ''}';

    setState(() {
      _messages.add({'role': 'user', 'content': fullInput.isNotEmpty ? fullInput : '开始分析'});
      _isLoading = true;
    });

    try {
      final aiService = ref.read(aiServiceProvider);
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': widget.agent.systemPrompt},
        if (fullInput.isNotEmpty) {'role': 'user', 'content': fullInput},
      ];
      final aiText = await aiService.chat(widget.config, messages);
      setState(() {
        _messages.add({'role': 'assistant', 'content': aiText});
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': '请求失败: $e\n请检查网络或API配置'});
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.agent.name)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(widget.agent.icon, style: const TextStyle(fontSize: 32)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.agent.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(widget.agent.description, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.agent.parameterPrompts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('参数设置', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...List.generate(widget.agent.parameterPrompts.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: _paramCtrls[i],
                        decoration: InputDecoration(
                          labelText: widget.agent.parameterPrompts[i],
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _inputCtrl,
                  decoration: const InputDecoration(
                    labelText: '输入内容（可选）',
                    hintText: '粘贴要分析的文本...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _runAgent,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('运行Agent'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
                ..._messages.map((msg) {
                  final isUser = msg['role'] == 'user';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.primary.withOpacity(0.1) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg['content'],
                            style: TextStyle(fontSize: 14, color: isUser ? AppColors.primary : Colors.black87),
                          ),
                          if (!isUser)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton.icon(
                                icon: const Icon(Icons.content_copy, size: 16),
                                label: const Text('复制', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: msg['content']));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已复制')),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

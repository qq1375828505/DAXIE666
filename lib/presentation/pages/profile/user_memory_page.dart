import 'package:flutter/material.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/services/user_memory.dart';
import 'package:novel_ide/presentation/widgets/top_notification.dart';

/// 用户全局记忆编辑页面
/// 用户可自由编辑自己的偏好、习惯、常用指令
/// AI对话时会自动读取此文件
class UserMemoryPage extends StatefulWidget {
  const UserMemoryPage({super.key});

  @override
  State<UserMemoryPage> createState() => _UserMemoryPageState();
}

class _UserMemoryPageState extends State<UserMemoryPage> {
  late TextEditingController _controller;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadMemory();
  }

  Future<void> _loadMemory() async {
    final content = await UserMemory.load();
    if (mounted) {
      setState(() {
        _controller.text = content;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveMemory() async {
    setState(() => _isSaving = true);
    await UserMemory.save(_controller.text);
    UserMemory.invalidateCache();
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户记忆已保存'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _resetMemory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置用户记忆'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text('将恢复为默认模板，当前内容会丢失。确定重置？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('重置'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await UserMemory.save(UserMemory.defaultContent());
      UserMemory.invalidateCache();
      await _loadMemory();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户记忆'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重置为默认',
            onPressed: _resetMemory,
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            tooltip: '保存',
            onPressed: _isSaving ? null : _saveMemory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 提示卡片
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.psychology, color: AppColors.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AI 会自动读取此文件', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              '记录您的写作风格、常用指令、AI偏好等。AI对话时会自动注入上下文。',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 编辑器
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: '在此编辑您的用户记忆...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: const TextStyle(fontSize: 14, height: 1.6, fontFamily: 'monospace'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}

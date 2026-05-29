import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';

/// 资料编辑页 - 全页编辑模式（类似编辑器）
class MaterialEditorPage extends ConsumerStatefulWidget {
  final String title;
  final String content;
  final String materialType;
  final String materialId;
  final String? category;
  final String? extraLabel;
  final String? extraValue;
  final void Function(String newTitle, String newContent)? onSave;

  const MaterialEditorPage({
    super.key,
    required this.title,
    required this.content,
    required this.materialType,
    required this.materialId,
    this.category,
    this.extraLabel,
    this.extraValue,
    this.onSave,
  });

  @override
  ConsumerState<MaterialEditorPage> createState() => _MaterialEditorPageState();
}

class _MaterialEditorPageState extends ConsumerState<MaterialEditorPage> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController? _extraCtrl;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.title);
    _contentCtrl = TextEditingController(text: widget.content);
    _extraCtrl = widget.extraLabel != null
        ? TextEditingController(text: widget.extraValue ?? '')
        : null;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _extraCtrl?.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _dirty) {
          widget.onSave?.call(_titleCtrl.text, _contentCtrl.text);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleCtrl.text.isEmpty ? widget.materialType : _titleCtrl.text,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _dirty ? '未保存' : widget.materialType,
                style: TextStyle(fontSize: 11, color: _dirty ? Colors.orange : Colors.grey[500]),
              ),
            ],
          ),
          actions: [
            if (_dirty)
              TextButton(
                onPressed: () {
                  widget.onSave?.call(_titleCtrl.text, _contentCtrl.text);
                  setState(() => _dirty = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1)),
                  );
                },
                child: const Text('保存', style: TextStyle(color: AppColors.primary)),
              ),
            PopupMenuButton<String>(
              onSelected: (v) => _handleMenu(v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'info', child: Text('查看详情')),
                const PopupMenuItem(value: 'copy', child: Text('复制全部内容')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // 标题输入
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  hintText: '标题',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onChanged: (_) => _markDirty(),
              ),
            ),
            // 分类标签
            if (widget.category != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.category!,
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                ),
              ),
            // 额外字段
            if (_extraCtrl != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: TextField(
                  controller: _extraCtrl,
                  decoration: InputDecoration(
                    hintText: widget.extraLabel,
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                  onChanged: (_) => _markDirty(),
                ),
              ),
            Divider(height: 1, color: Colors.grey.withOpacity(0.15)),
            // 内容编辑区
            Expanded(
              child: TextField(
                controller: _contentCtrl,
                maxLines: null,
                minLines: 20,
                expands: true,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  hintText: '开始编辑...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                ),
                style: TextStyle(
                  fontSize: 16,
                  height: 1.8,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                onChanged: (_) => _markDirty(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenu(String action) {
    switch (action) {
      case 'copy':
        final text = '${_titleCtrl.text}\n\n${_contentCtrl.text}';
        // Flutter's copy is handled by the text field selection
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('内容已在编辑框中，长按可复制')),
        );
        break;
      case 'info':
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(_titleCtrl.text),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('类型: ${widget.materialType}'),
                if (widget.category != null) Text('分类: ${widget.category}'),
                Text('字数: ${_contentCtrl.text.length}'),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
          ),
        );
        break;
    }
  }
}

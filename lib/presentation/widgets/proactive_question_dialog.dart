import 'package:flutter/material.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/proactive_question_model.dart';

/// 主动提问弹窗组件
class ProactiveQuestionDialog extends StatefulWidget {
  final ProactiveQuestion question;
  final void Function(ProactiveSelection selection) onSelected;
  final VoidCallback? onSkipped;

  const ProactiveQuestionDialog({
    super.key,
    required this.question,
    required this.onSelected,
    this.onSkipped,
  });

  /// 显示弹窗
  static Future<void> show(
    BuildContext context, {
    required ProactiveQuestion question,
    required void Function(ProactiveSelection selection) onSelected,
    VoidCallback? onSkipped,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProactiveQuestionDialog(
        question: question,
        onSelected: onSelected,
        onSkipped: onSkipped,
      ),
    );
  }

  @override
  State<ProactiveQuestionDialog> createState() => _ProactiveQuestionDialogState();
}

class _ProactiveQuestionDialogState extends State<ProactiveQuestionDialog> {
  final Set<String> _selectedIds = {};
  final TextEditingController _customInputController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    // 输入自定义内容时实时更新按钮状态
    _customInputController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _customInputController.dispose();
    super.dispose();
  }

  void _toggleOption(String id) {
    setState(() {
      if (widget.question.multiSelect) {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else {
          _selectedIds.add(id);
        }
      } else {
        _selectedIds.clear();
        _selectedIds.add(id);
      }
    });
  }

  void _confirm() {
    final selectedOptions = widget.question.options
        .where((o) => _selectedIds.contains(o.id))
        .toList();

    final selection = ProactiveSelection(
      question: widget.question,
      selectedOptions: selectedOptions,
      customInput: _customInputController.text.trim().isNotEmpty
          ? _customInputController.text.trim()
          : null,
    );

    widget.onSelected(selection);
    Navigator.of(context).pop();
  }

  void _skip() {
    widget.onSkipped?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.question.title),
          if (widget.question.subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.question.subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 选项列表
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.question.options.length,
                itemBuilder: (ctx, i) {
                  final opt = widget.question.options[i];
                  final isSelected = _selectedIds.contains(opt.id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => _toggleOption(opt.id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: isSelected ? AppColors.primary : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt.label,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                  if (opt.description != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        opt.description!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // 自定义输入
            if (widget.question.allowCustomInput) ...[
              const SizedBox(height: 8),
              if (!_showCustomInput)
                TextButton.icon(
                  onPressed: () => setState(() => _showCustomInput = true),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('其他'),
                )
              else
                TextField(
                  controller: _customInputController,
                  decoration: InputDecoration(
                    hintText: widget.question.customInputPlaceholder ?? '请输入...',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _skip,
          child: const Text('跳过'),
        ),
        FilledButton(
          onPressed: _selectedIds.isNotEmpty ||
                    (_customInputController.text.trim().isNotEmpty)
              ? _confirm
              : null,
          child: const Text('确定'),
        ),
      ],
    );
  }
}

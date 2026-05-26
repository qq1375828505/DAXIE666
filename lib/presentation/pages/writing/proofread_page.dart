import 'package:flutter/material.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/services/proofread_service.dart';

/// 全文校对页面
class ProofreadPage extends StatefulWidget {
  final String novelId;

  const ProofreadPage({super.key, required this.novelId});

  @override
  State<ProofreadPage> createState() => _ProofreadPageState();
}

class _ProofreadPageState extends State<ProofreadPage> {
  final _service = ProofreadService();
  List<ProofreadItem> _results = [];
  bool _isLoading = false;
  String _filterType = 'all'; // all | typo | punctuation | suggestion

  @override
  void initState() {
    super.initState();
    _startProofread();
  }

  Future<void> _startProofread() async {
    setState(() {
      _isLoading = true;
      _results.clear();
    });

    try {
      final results = await _service.proofreadNovel(widget.novelId);
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('校对失败: $e')),
        );
      }
    }
  }

  List<ProofreadItem> get _filteredResults {
    if (_filterType == 'all') return _results;
    return _results.where((r) => r.type == _filterType).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredResults;
    final typoCount = _results.where((r) => r.type == 'typo').length;
    final puncCount = _results.where((r) => r.type == 'punctuation').length;
    final sugCount = _results.where((r) => r.type == 'suggestion').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文章校对'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新校对',
            onPressed: _isLoading ? null : _startProofread,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在校对全文...'),
                ],
              ),
            )
          : Column(
              children: [
                // 统计摘要
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).cardColor,
                  child: Row(
                    children: [
                      _StatChip(label: '错别字', count: typoCount, color: Colors.red),
                      const SizedBox(width: 8),
                      _StatChip(label: '标点', count: puncCount, color: Colors.orange),
                      const SizedBox(width: 8),
                      _StatChip(label: '建议', count: sugCount, color: Colors.blue),
                      const Spacer(),
                      Text(
                        '共 ${_results.length} 处',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // 筛选栏
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      _FilterChip(label: '全部', value: 'all', count: _results.length, groupValue: _filterType, onSelected: (v) => setState(() => _filterType = v)),
                      const SizedBox(width: 6),
                      _FilterChip(label: '错别字', value: 'typo', count: typoCount, groupValue: _filterType, onSelected: (v) => setState(() => _filterType = v)),
                      const SizedBox(width: 6),
                      _FilterChip(label: '标点', value: 'punctuation', count: puncCount, groupValue: _filterType, onSelected: (v) => setState(() => _filterType = v)),
                      const SizedBox(width: 6),
                      _FilterChip(label: '建议', value: 'suggestion', count: sugCount, groupValue: _filterType, onSelected: (v) => setState(() => _filterType = v)),
                    ],
                  ),
                ),
                // 结果列表
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
                              const SizedBox(height: 16),
                              Text(
                                _results.isEmpty ? '未发现问题，文章很棒！' : '当前筛选无结果',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return _ProofreadItemTile(item: item);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(width: 4),
          Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final int count;
  final String groupValue;
  final ValueChanged<String> onSelected;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.count,
    required this.groupValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return FilterChip(
      label: Text('$label ($count)', style: TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: AppColors.primary.withOpacity(0.15),
      checkmarkColor: AppColors.primary,
    );
  }
}

class _ProofreadItemTile extends StatelessWidget {
  final ProofreadItem item;

  const _ProofreadItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final typeColor = item.type == 'typo'
        ? Colors.red
        : item.type == 'punctuation'
            ? Colors.orange
            : Colors.blue;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: typeColor, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类型标签 + 章节名
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(item.typeLabel, style: TextStyle(fontSize: 11, color: typeColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.chapterTitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 原文 → 建议
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(item.original, style: const TextStyle(fontSize: 15, color: Colors.red)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(item.suggestion, style: const TextStyle(fontSize: 15, color: Colors.green)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 上下文
            Text(
              '...${item.context}...',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

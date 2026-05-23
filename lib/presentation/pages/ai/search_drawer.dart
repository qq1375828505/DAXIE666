import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/search_result_model.dart';

class SearchDrawer extends ConsumerStatefulWidget {
  final String novelId;
  final VoidCallback onClose;

  const SearchDrawer({super.key, required this.novelId, required this.onClose});

  @override
  ConsumerState<SearchDrawer> createState() => _SearchDrawerState();
}

class _SearchDrawerState extends ConsumerState<SearchDrawer> {
  final TextEditingController _queryCtrl = TextEditingController();
  final Dio _dio = Dio();
  List<SearchResult> _results = [];
  bool _isLoading = false;

  Future<void> _search() async {
    final query = _queryCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final response = await _dio.get(
        'https://api.duckduckgo.com/',
        queryParameters: {'q': query, 'format': 'json', 'no_html': 1, 'skip_disambig': 1},
      );
      final data = response.data;
      final results = <SearchResult>[];
      if (data['Results'] != null) {
        for (final item in data['Results']) {
          results.add(SearchResult(
            title: item['Text'] ?? '',
            url: item['FirstURL'] ?? '',
            snippet: '',
          ));
        }
      }
      if (data['RelatedTopics'] != null) {
        for (final item in data['RelatedTopics']) {
          if (item is Map<String, dynamic>) {
            results.add(SearchResult(
              title: item['Text']?.toString().split(' - ').first ?? '',
              url: item['FirstURL'] ?? '',
              snippet: item['Text']?.toString() ?? '',
            ));
          }
        }
      }
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _results = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('搜索请求失败，请检查网络')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text('联网搜索', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: widget.onClose),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryCtrl,
                    decoration: InputDecoration(
                      hintText: '输入搜索关键词...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.search, color: Colors.white, size: 18),
                    onPressed: _search,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_results.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('输入关键词搜索资料', style: TextStyle(color: Colors.grey[400])),
                    const SizedBox(height: 4),
                    Text('结果可保存到参考资料库', style: TextStyle(fontSize: 12, color: Colors.grey[350])),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(result.title, style: const TextStyle(fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: result.snippet.isNotEmpty
                          ? Text(result.snippet, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[500]))
                          : null,
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'copy') {
                            Clipboard.setData(ClipboardData(text: '${result.title}\n${result.url}'));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制')));
                          } else if (action == 'save') {
                            // Will be handled by parent
                            widget.onClose();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'copy', child: Text('复制链接')),
                          const PopupMenuItem(value: 'save', child: Text('保存到资料库')),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

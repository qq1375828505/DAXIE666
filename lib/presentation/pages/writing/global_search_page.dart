import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';
import 'package:path/path.dart' as p;

/// 跨章节全局搜索替换页面
class GlobalSearchPage extends ConsumerStatefulWidget {
  final String novelId;
  final String novelTitle;

  const GlobalSearchPage({
    super.key,
    required this.novelId,
    required this.novelTitle,
  });

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _SearchResult {
  final String chapterId;
  final String chapterTitle;
  final String matchedLine;
  final int lineIndex;
  final int charOffset;
  final String content;

  _SearchResult({
    required this.chapterId,
    required this.chapterTitle,
    required this.matchedLine,
    required this.lineIndex,
    required this.charOffset,
    required this.content,
  });
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final _searchCtrl = TextEditingController();
  final _replaceCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<_SearchResult> _results = [];
  bool _isSearching = false;
  bool _showReplace = false;
  int _currentResultIndex = -1;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _replaceCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isSearching = true;
      _results.clear();
      _currentResultIndex = -1;
    });

    final db = await DatabaseHelper().database;
    final fs = LocalFileDataSource();
    final projectPath = await fs.getProjectDir(widget.novelId, widget.novelTitle);

    // 获取所有章节
    final chapterRows = await db.query('chapters',
        where: 'novel_id = ?',
        whereArgs: [widget.novelId],
        orderBy: 'order_index ASC');

    for (final row in chapterRows) {
      final chapterId = row['id'] as String;
      final chapterTitle = row['title'] as String;
      final contentFile = p.join(projectPath, 'chapters', '$chapterId.md');

      try {
        final file = File(contentFile);
        if (!await file.exists()) continue;

        final content = await file.readAsString();
        final lines = content.split('\n');

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          int startIndex = 0;
          while (true) {
            final idx = line.indexOf(keyword, startIndex);
            if (idx == -1) break;

            _results.add(_SearchResult(
              chapterId: chapterId,
              chapterTitle: chapterTitle,
              matchedLine: line.trim(),
              lineIndex: i,
              charOffset: idx,
              content: content,
            ));
            startIndex = idx + 1;
          }
        }
      } catch (_) {
        // Skip unreadable files
      }
    }

    setState(() => _isSearching = false);
  }

  Future<void> _replaceSingle(int index) async {
    if (index < 0 || index >= _results.length) return;

    final result = _results[index];
    final keyword = _searchCtrl.text.trim();
    final replacement = _replaceCtrl.text;

    final db = await DatabaseHelper().database;
    final fs = LocalFileDataSource();
    final projectPath = await fs.getProjectDir(widget.novelId, widget.novelTitle);
    final contentFile = File(p.join(projectPath, 'chapters', '${result.chapterId}.md'));

    if (await contentFile.exists()) {
      String content = await contentFile.readAsString();
      // 替换第一个匹配
      content = content.replaceFirst(keyword, replacement);
      await contentFile.writeAsString(content);

      // 更新字数
      await db.update('chapters', {'word_count': content.length, 'updated_at': DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?', whereArgs: [result.chapterId]);

      // 移除已替换的结果
      setState(() {
        _results.removeAt(index);
        if (_currentResultIndex >= _results.length) {
          _currentResultIndex = _results.isEmpty ? -1 : _results.length - 1;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已替换'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  Future<void> _replaceAll() async {
    if (_results.isEmpty) return;

    final keyword = _searchCtrl.text.trim();
    final replacement = _replaceCtrl.text;

    final db = await DatabaseHelper().database;
    final fs = LocalFileDataSource();
    final projectPath = await fs.getProjectDir(widget.novelId, widget.novelTitle);

    // 按章节分组处理
    final chapterIds = _results.map((r) => r.chapterId).toSet();
    int replacedCount = 0;

    for (final chapterId in chapterIds) {
      final contentFile = File(p.join(projectPath, 'chapters', '$chapterId.md'));
      if (await contentFile.exists()) {
        String content = await contentFile.readAsString();
        final count = keyword.allMatches(content).length;
        content = content.replaceAll(keyword, replacement);
        await contentFile.writeAsString(content);
        replacedCount += count;

        await db.update('chapters', {
          'word_count': content.length,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, where: 'id = ?', whereArgs: [chapterId]);
      }
    }

    setState(() {
      _results.clear();
      _currentResultIndex = -1;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已替换 $replacedCount 处')),
      );
    }
  }

  void _jumpToNext() {
    if (_results.isEmpty) return;
    setState(() {
      _currentResultIndex = (_currentResultIndex + 1) % _results.length;
    });
    _scrollToCurrent();
  }

  void _jumpToPrev() {
    if (_results.isEmpty) return;
    setState(() {
      _currentResultIndex = _currentResultIndex <= 0
          ? _results.length - 1
          : _currentResultIndex - 1;
    });
    _scrollToCurrent();
  }

  void _scrollToCurrent() {
    if (_currentResultIndex >= 0) {
      _scrollCtrl.animateTo(
        _currentResultIndex * 88.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('搜索 · ${widget.novelTitle}'),
        actions: [
          IconButton(
            icon: Icon(_showReplace ? Icons.expand_less : Icons.expand_more),
            tooltip: _showReplace ? '隐藏替换' : '显示替换',
            onPressed: () => setState(() => _showReplace = !_showReplace),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: '输入搜索关键词...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _results.clear());
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _doSearch(),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isSearching ? null : _doSearch,
                      child: _isSearching
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('搜索'),
                    ),
                  ],
                ),
                // 替换栏
                if (_showReplace) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replaceCtrl,
                          decoration: InputDecoration(
                            hintText: '替换为...',
                            prefixIcon: const Icon(Icons.find_replace, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _results.isEmpty ? null : () => _replaceSingle(_currentResultIndex >= 0 ? _currentResultIndex : 0),
                        child: const Text('替换'),
                      ),
                      const SizedBox(width: 4),
                      OutlinedButton(
                        onPressed: _results.isEmpty ? null : _replaceAll,
                        child: const Text('全部'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // 结果统计 + 导航
          if (_results.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: Row(
                children: [
                  Text(
                    '找到 ${_results.length} 处匹配',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                    onPressed: _jumpToPrev,
                    tooltip: '上一个',
                  ),
                  Text(
                    _currentResultIndex >= 0
                        ? '${_currentResultIndex + 1}/${_results.length}'
                        : '-',
                    style: const TextStyle(fontSize: 13),
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                    onPressed: _jumpToNext,
                    tooltip: '下一个',
                  ),
                ],
              ),
            ),
          // 结果列表
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _searchCtrl.text.isEmpty ? '输入关键词开始搜索' : '未找到匹配结果',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      final isCurrent = index == _currentResultIndex;
                      final keyword = _searchCtrl.text.trim();

                      return Container(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppColors.primary.withOpacity(0.08)
                              : null,
                          border: Border(
                            left: BorderSide(
                              color: isCurrent ? AppColors.primary : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: isCurrent
                                ? AppColors.primary
                                : Colors.grey[300],
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isCurrent ? Colors.white : Colors.grey[700],
                              ),
                            ),
                          ),
                          title: Text(
                            result.chapterTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: _HighlightText(
                            text: result.matchedLine,
                            keyword: keyword,
                            maxLines: 2,
                          ),
                          trailing: _showReplace
                              ? IconButton(
                                  icon: const Icon(Icons.check, size: 18, color: Colors.green),
                                  onPressed: () => _replaceSingle(index),
                                )
                              : null,
                          onTap: () {
                            setState(() => _currentResultIndex = index);
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
}

/// 高亮关键词的文本组件
class _HighlightText extends StatelessWidget {
  final String text;
  final String keyword;
  final int maxLines;

  const _HighlightText({
    required this.text,
    required this.keyword,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (keyword.isEmpty) {
      return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12));
    }

    final spans = <TextSpan>[];
    int start = 0;
    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();

    while (true) {
      final idx = lowerText.indexOf(lowerKeyword, start);
      if (idx == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + keyword.length),
        style: TextStyle(
          backgroundColor: Colors.yellow.withOpacity(0.4),
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ));
      start = idx + keyword.length;
    }

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12),
        children: spans,
      ),
    );
  }
}

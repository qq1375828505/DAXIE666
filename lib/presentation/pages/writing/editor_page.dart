import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/chapter_model.dart';
import 'package:novel_ide/data/models/novel_model.dart';
import 'package:novel_ide/data/models/tomato_preset_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/presentation/pages/ai/ai_drawer.dart';
import 'package:novel_ide/presentation/pages/ai/search_drawer.dart';
import 'package:novel_ide/presentation/pages/ai/setting_reminder_page.dart';
import 'package:novel_ide/presentation/pages/ai/polish_engine_page.dart';
import 'package:novel_ide/presentation/pages/tomato/style_selector_bar.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:intl/intl.dart';

class EditorPage extends ConsumerStatefulWidget {
  final String novelId;
  final String chapterId;
  const EditorPage({super.key, required this.novelId, required this.chapterId});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  late TextEditingController _controller;
  final ScrollController _scrollController = ScrollController();
  final SpeechToText _speech = SpeechToText();
  Timer? _autoSaveTimer;
  Timer? _snapshotTimer;
  bool _isListening = false;
  bool _showAiDrawer = false;
  bool _showSearchDrawer = false;
  bool _showFindBar = false;
  final TextEditingController _findCtrl = TextEditingController();
  int _findIndex = 0;
  List<TextSelection> _findResults = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadChapter();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    await _speech.initialize();
  }

  Future<void> _loadChapter() async {
    final chapter = await ref.read(chapterRepoProvider).getChapter(widget.chapterId);
    if (chapter != null) {
      _controller.text = chapter.content;
      ref.read(editorContentProvider.notifier).state = chapter.content;
      ref.read(wordCountProvider.notifier).state = chapter.wordCount;
      ref.read(saveStatusProvider.notifier).state = '已保存';
    }
  }

  void _onTextChanged(String text) {
    ref.read(editorContentProvider.notifier).state = text;
    ref.read(wordCountProvider.notifier).state = text.length;
    ref.read(saveStatusProvider.notifier).state = '保存中...';
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1500), () {
      _saveChapter();
    });
  }

  Future<void> _saveChapter() async {
    final novel = ref.read(selectedNovelProvider);
    if (novel == null) return;
    final chapter = await ref.read(chapterRepoProvider).getChapter(widget.chapterId);
    if (chapter == null) return;
    final newWordCount = _controller.text.length;
    final oldWordCount = chapter.wordCount;
    final updated = chapter.copyWith(
      content: _controller.text,
      wordCount: newWordCount,
      updatedAt: DateTime.now(),
    );
    await ref.read(chapterRepoProvider).updateChapter(updated, novel.title);

    // Record daily word count delta
    final delta = newWordCount - oldWordCount;
    if (delta > 0) {
      await ref.read(statsRepoProvider).recordWords(novel.id, delta);
      // Refresh today's count
      final todayWords = await ref.read(statsRepoProvider).getTodayWords();
      ref.read(todayWordsProvider.notifier).state = todayWords;
    }

    ref.read(saveStatusProvider.notifier).state = '已保存 ${DateFormat('HH:mm').format(DateTime.now())}';
    ref.invalidate(chaptersProvider(widget.novelId));
  }

  void _createSnapshot() {
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer(const Duration(minutes: 3), () async {
      await ref.read(chapterRepoProvider).createSnapshot(widget.chapterId, _controller.text);
    });
  }

  void _toggleSpeech() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      final available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        await _speech.listen(
          onResult: (result) {
            final text = result.recognizedWords;
            if (text.isNotEmpty) {
              final current = _controller.text;
              final selection = _controller.selection;
              final newText = current.substring(0, selection.start) +
                  text +
                  current.substring(selection.end);
              _controller.text = newText;
              _controller.selection = TextSelection.collapsed(offset: selection.start + text.length);
              _onTextChanged(newText);
            }
          },
          localeId: 'zh_CN',
        );
      }
    }
  }

  void _showSnapshots() async {
    final snapshots = await ref.read(chapterRepoProvider).getSnapshots(widget.chapterId);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: const Text('历史版本', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: snapshots.length,
                  itemBuilder: (context, index) {
                    final snap = snapshots[index];
                    return ListTile(
                      title: Text('版本 ${index + 1}'),
                      subtitle: Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(snap.createdAt)),
                      trailing: Text('${snap.content.length}字'),
                      onTap: () {
                        _controller.text = snap.content;
                        _onTextChanged(snap.content);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已恢复历史版本')),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _findNext() {
    if (_findCtrl.text.isEmpty) return;
    final text = _controller.text;
    final query = _findCtrl.text;
    final matches = query.allMatches(text).toList();
    if (matches.isEmpty) return;
    _findIndex = (_findIndex + 1) % matches.length;
    final match = matches[_findIndex];
    _controller.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );
  }

  void _showChapterMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('历史版本'),
              onTap: () {
                Navigator.pop(context);
                _showSnapshots();
              },
            ),
            ListTile(
              leading: const Icon(Icons.splitscreen),
              title: const Text('拆分章节'),
              onTap: () {
                Navigator.pop(context);
                _splitChapter();
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text('设定提醒'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingReminderPage(
                      novelId: widget.novelId,
                      editorController: _controller,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: const Text('一键精修'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PolishEnginePage(
                      chapterContent: _controller.text,
                      novelTitle: ref.read(selectedNovelProvider)?.title ?? '',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('联网搜索'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _showSearchDrawer = !_showSearchDrawer);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('删除章节', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('删除章节'),
                    content: const Text('确定删除此章节吗？内容将移至回收站。'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(chapterRepoProvider).deleteChapter(widget.chapterId);
                  ref.invalidate(chaptersProvider(widget.novelId));
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _splitChapter() {
    final text = _controller.text;
    if (text.length < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('章节内容太短，不适合拆分')),
      );
      return;
    }
    final midpoint = text.length ~/ 2;
    int splitPos = midpoint;
    for (int i = midpoint; i < text.length && i < midpoint + 500; i++) {
      if (text[i] == '\n' || text[i] == '。' || text[i] == '！' || text[i] == '？') {
        splitPos = i + 1;
        break;
      }
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('拆分章节'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('将在第${splitPos}字处拆分（约${text.substring(0, splitPos).length}字 / ${text.substring(splitPos).length}字）'),
            const SizedBox(height: 8),
            Text('前段预览：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[500])),
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${text.substring((splitPos - 30).clamp(0, text.length), (splitPos + 30).clamp(0, text.length))}',
                style: const TextStyle(fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final novel = ref.read(selectedNovelProvider);
              final chapter = await ref.read(chapterRepoProvider).getChapter(widget.chapterId);
              if (chapter == null || novel == null) return;
              final firstPart = text.substring(0, splitPos).trim();
              final secondPart = text.substring(splitPos).trim();
              final chapters = await ref.read(chapterRepoProvider).getChaptersByNovel(widget.novelId);
              final newOrder = chapters.where((c) => c.id != widget.chapterId).length;
              await ref.read(chapterRepoProvider).updateChapter(
                chapter.copyWith(content: firstPart, wordCount: firstPart.length, updatedAt: DateTime.now()),
                novel.title,
              );
              final newChapter = await ref.read(chapterRepoProvider).createChapter(
                novelId: widget.novelId,
                volumeId: chapter.volumeId,
                title: '${chapter.title}（续）',
                orderIndex: newOrder,
              );
              await ref.read(chapterRepoProvider).updateChapter(
                newChapter.copyWith(content: secondPart, wordCount: secondPart.length, updatedAt: DateTime.now()),
                novel.title,
              );
              ref.invalidate(chaptersProvider(widget.novelId));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('章节已拆分')),
                );
              }
            },
            child: const Text('确认拆分'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _saveChapter();
    _autoSaveTimer?.cancel();
    _snapshotTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _findCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = ref.watch(wordCountProvider);
    final saveStatus = ref.watch(saveStatusProvider);
    final currentPreset = ref.watch(currentPresetProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('编辑器', style: TextStyle(fontSize: 16)),
            Text(
              '$wordCount字 · $saveStatus${!isOnline ? " · 离线" : ""}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          if (_showFindBar)
            SizedBox(
              width: 150,
              child: TextField(
                controller: _findCtrl,
                decoration: InputDecoration(
                  hintText: '查找',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    onPressed: _findNext,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onSubmitted: (_) => _findNext(),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _showFindBar = true),
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showChapterMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          StyleSelectorBar(
            onPresetSelected: (preset) {
              ref.read(currentPresetProvider.notifier).state = preset;
            },
          ),
          if (!isOnline)
            Container(
              width: double.infinity,
              color: Colors.orange[50],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, size: 14, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  const Text('离线模式：AI功能不可用', style: TextStyle(fontSize: 11, color: Colors.orange)),
                ],
              ),
            ),
          if (wordCount > 10000)
            Container(
              width: double.infinity,
              color: Colors.orange[50],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Text(
                    wordCount > 15000 ? '本章超过15000字，建议立即拆章以保证性能' : '本章超过10000字，建议拆章',
                    style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              minLines: 20,
              expands: true,
              scrollController: _scrollController,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                hintText: currentPreset != null
                    ? '当前风格：${currentPreset.name}\n开始写作...'
                    : '开始写作...',
                hintStyle: TextStyle(color: Colors.grey[400]),
              ),
              style: TextStyle(
                fontFamily: 'NotoSerifSC',
                fontSize: 18,
                height: 1.8,
                color: isDark ? Colors.white : Colors.black87,
              ),
              onChanged: (text) {
                _onTextChanged(text);
                _createSnapshot();
              },
              contextMenuBuilder: (context, editableTextState) {
                final toolbar = editableTextState.contextMenuButtonItems;
                return AdaptiveTextSelectionToolbar.buttonItems(
                  anchors: editableTextState.contextMenuAnchors,
                  buttonItems: [
                    ...toolbar,
                    ContextMenuButtonItem(
                      label: '润色',
                      onPressed: () {
                        editableTextState.hideToolbar();
                        setState(() => _showAiDrawer = true);
                      },
                    ),
                    ContextMenuButtonItem(
                      label: '扩写',
                      onPressed: () {
                        editableTextState.hideToolbar();
                        setState(() => _showAiDrawer = true);
                      },
                    ),
                    ContextMenuButtonItem(
                      label: '续写',
                      onPressed: () {
                        editableTextState.hideToolbar();
                        setState(() => _showAiDrawer = true);
                      },
                    ),
                    ContextMenuButtonItem(
                      label: '联网查证',
                      onPressed: () {
                        editableTextState.hideToolbar();
                        setState(() => _showSearchDrawer = true);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.undo, size: 22), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.redo, size: 22), onPressed: () {}),
                    const VerticalDivider(width: 1),
                    IconButton(
                      icon: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 22),
                      color: _isListening ? AppColors.primary : null,
                      onPressed: _toggleSpeech,
                    ),
                    const Spacer(),
                    if (currentPreset != null)
                      Chip(
                        label: Text(currentPreset.name, style: const TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.tomatoRed.withOpacity(0.1),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isOnline
          ? FloatingActionButton(
              onPressed: () {
                setState(() => _showAiDrawer = !_showAiDrawer);
              },
              child: const Icon(Icons.auto_awesome),
            )
          : null,
      bottomSheet: _showAiDrawer
          ? AiDrawer(
              novelId: widget.novelId,
              chapterId: widget.chapterId,
              controller: _controller,
              onClose: () => setState(() => _showAiDrawer = false),
            )
          : _showSearchDrawer
              ? SearchDrawer(
                  novelId: widget.novelId,
                  onClose: () => setState(() => _showSearchDrawer = false),
                )
              : null,
    );
  }
}

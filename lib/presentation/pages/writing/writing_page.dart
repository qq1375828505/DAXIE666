import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/presentation/pages/works/works_page.dart';
import 'package:novel_ide/presentation/pages/writing/editor_page.dart';

class WritingPage extends ConsumerWidget {
  const WritingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedNovel = ref.watch(selectedNovelProvider);
    final selectedChapter = ref.watch(selectedChapterProvider);

    // 如果有选中的章节，直接显示编辑器
    if (selectedNovel != null && selectedChapter != null) {
      return EditorPage(
        novelId: selectedNovel.id,
        chapterId: selectedChapter.id,
      );
    }

    // 否则显示引导页
    return Scaffold(
      appBar: AppBar(title: const Text('写作')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('选择一个章节开始写作', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(bottomNavIndexProvider.notifier).state = 1;
              },
              icon: const Icon(Icons.auto_stories),
              label: const Text('去作品页选择章节'),
            ),
          ],
        ),
      ),
    );
  }
}

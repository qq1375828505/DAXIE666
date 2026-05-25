import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/presentation/pages/writing/writing_page.dart';
import 'package:novel_ide/presentation/pages/works/works_page.dart';
import 'package:novel_ide/presentation/pages/outline/outline_page.dart';
import 'package:novel_ide/presentation/pages/materials/materials_page.dart';
import 'package:novel_ide/presentation/pages/profile/profile_page.dart';
import 'package:novel_ide/presentation/pages/ai/ai_chat_page.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    final pages = [
      const WritingPage(),
      const WorksPage(),
      const OutlinePage(),
      const MaterialsPage(),
      const ProfilePage(),
      const AiChatPage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(bottomNavIndexProvider.notifier).state = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: '写作',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: '作品',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: '大纲',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: '资料',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'AI对话',
          ),
        ],
      ),
    );
  }
}

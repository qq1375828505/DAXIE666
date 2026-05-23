import 'package:flutter/material.dart';
import 'package:novel_ide/presentation/pages/main_shell.dart';
import 'package:novel_ide/presentation/pages/writing/editor_page.dart';
import 'package:novel_ide/presentation/pages/tomato/agent_marketplace_page.dart';

class AppRouter {
  static const String home = '/';
  static const String editor = '/editor';
  static const String agents = '/agents';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const MainShell());
      case editor:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => EditorPage(
            novelId: args?['novelId'] ?? '',
            chapterId: args?['chapterId'] ?? '',
          ),
        );
      case agents:
        return MaterialPageRoute(builder: (_) => const AgentMarketplacePage());
      default:
        return MaterialPageRoute(builder: (_) => const MainShell());
    }
  }
}

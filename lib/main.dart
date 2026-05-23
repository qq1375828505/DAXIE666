import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/core/router.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/services/config_service.dart';
import 'package:novel_ide/data/services/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await ConfigService.init();
  ConnectivityService.startMonitoring();

  runApp(
    const ProviderScope(
      child: NovelIdeApp(),
    ),
  );
}

class NovelIdeApp extends ConsumerStatefulWidget {
  const NovelIdeApp({super.key});

  @override
  ConsumerState<NovelIdeApp> createState() => _NovelIdeAppState();
}

class _NovelIdeAppState extends ConsumerState<NovelIdeApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final savedDark = ConfigService.isDarkMode;
      ref.read(darkModeProvider.notifier).state = savedDark;
      ref.read(fontSizeProvider.notifier).state = ConfigService.fontSize;
      ref.read(fontFamilyProvider.notifier).state = ConfigService.fontFamily;
      ref.read(lineHeightProvider.notifier).state = ConfigService.lineHeight;
    });

    ConnectivityService.onStatusChanged.listen((isOnline) {
      ref.read(isOnlineProvider.notifier).state = isOnline;
    });
  }

  @override
  void dispose() {
    ConnectivityService.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(darkModeProvider);

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/core/router.dart';
import 'package:novel_ide/core/theme/skin_provider.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/services/config_service.dart';
import 'package:novel_ide/data/services/connectivity_service.dart';
import 'package:novel_ide/data/services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await ConfigService.init();
  ConnectivityService.startMonitoring();
  await NotificationService.init();

  // Request storage permissions at startup
  await _requestPermissions();

  runApp(
    const ProviderScope(
      child: NovelIdeApp(),
    ),
  );
}

Future<void> _requestPermissions() async {
  // Request storage permissions
  final storage = await Permission.storage.request();
  final manageStorage = await Permission.manageExternalStorage.request();
  final notification = await Permission.notification.request();
  final mic = await Permission.microphone.request();
  debugPrint('Storage: $storage, ManageStorage: $manageStorage, Notification: $notification, Mic: $mic');
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
      // Load persistent settings
      final savedDark = ConfigService.isDarkMode;
      ref.read(darkModeProvider.notifier).state = savedDark;
      ref.read(fontSizeProvider.notifier).state = ConfigService.fontSize;
      ref.read(fontFamilyProvider.notifier).state = ConfigService.fontFamily;
      ref.read(lineHeightProvider.notifier).state = ConfigService.lineHeight;
      // Load persisted data (AI configs, etc.)
      loadAllData(ref);
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
    final skinTheme = ref.watch(skinThemeProvider);
    final isDark = ref.watch(darkModeProvider);

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: skinTheme.toThemeData(),
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

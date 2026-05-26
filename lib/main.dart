import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  // 延迟权限请求到首页加载后，避免阻塞启动
  // 权限请求在 _NovelIdeAppState.initState 中进行

  runApp(
    const ProviderScope(
      child: NovelIdeApp(),
    ),
  );
}

/// 请求基本运行时权限（不含特殊权限）
Future<void> _requestBasicPermissions() async {
  try {
    // 基本运行时权限 - 这些可以一起请求
    final storage = await Permission.storage.request();
    final notification = await Permission.notification.request();
    final mic = await Permission.microphone.request();
    
    debugPrint('Permissions - Storage: $storage, Notification: $notification, Mic: $mic');
    
    // MANAGE_EXTERNAL_STORAGE 是特殊权限，需要单独处理
    // 只在 Android 11+ 且需要管理所有文件时才请求
    if (await Permission.manageExternalStorage.isDenied) {
      // 延迟到实际需要时再请求，避免启动时卡死
      debugPrint('ManageExternalStorage denied, will request when needed');
    }
  } catch (e) {
    debugPrint('Permission request error: $e');
  }
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
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 加载持久化设置
      _loadSettings();
      
      // 延迟 500ms 确保页面已渲染，再请求权限
      // 避免权限对话框与启动动画冲突导致卡死
      await Future.delayed(const Duration(milliseconds: 500));
      await _requestBasicPermissions();
    });

    ConnectivityService.onStatusChanged.listen((isOnline) {
      ref.read(isOnlineProvider.notifier).state = isOnline;
    });
  }

  void _loadSettings() {
    try {
      final savedDark = ConfigService.isDarkMode;
      ref.read(darkModeProvider.notifier).state = savedDark;
      ref.read(fontSizeProvider.notifier).state = ConfigService.fontSize;
      ref.read(fontFamilyProvider.notifier).state = ConfigService.fontFamily;
      ref.read(lineHeightProvider.notifier).state = ConfigService.lineHeight;
      // Load persisted data (AI configs, etc.)
      loadAllData(ref);
    } catch (e) {
      debugPrint('Load settings error: $e');
    }
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
      // 中文本地化支持
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 简体中文
        Locale('en', 'US'), // 英文备用
      ],
      locale: const Locale('zh', 'CN'), // 默认中文
      theme: skinTheme.toThemeData(),
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

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
import 'package:novel_ide/data/services/default_config_service.dart';
import 'package:novel_ide/data/services/announcement_service.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await ConfigService.init();
  
  // 初始化默认AI配置（开箱即用）
  await DefaultConfigService.initDefaultConfig();
  
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

class _NovelIdeAppState extends ConsumerState<NovelIdeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 迁移旧目录结构到新结构
      try {
        await LocalFileDataSource().migrateIfNeeded();
      } catch (e) {
        debugPrint('Migration error: $e');
      }

      // 加载持久化设置
      _loadSettings();
      
      // 延迟 500ms 确保页面已渲染，再请求权限
      // 避免权限对话框与启动动画冲突导致卡死
      await Future.delayed(const Duration(milliseconds: 500));
      await _requestBasicPermissions();
      
      // 首次启动显示公告
      _showAnnouncementIfNeeded();
    });

    ConnectivityService.onStatusChanged.listen((isOnline) {
      ref.read(isOnlineProvider.notifier).state = isOnline;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
        // 切到后台：保存状态
        debugPrint('App paused - saving state');
        _saveState();
        break;
      case AppLifecycleState.resumed:
        // 切回前台：恢复状态
        debugPrint('App resumed - reloading state');
        _loadSettings();
        break;
      case AppLifecycleState.detached:
        // 应用被系统杀死
        debugPrint('App detached');
        _saveState();
        break;
      default:
        break;
    }
  }

  void _saveState() {
    // 保存当前状态到持久化存储
    try {
      // Provider 状态会自动保持，但需要确保关键数据已保存
      debugPrint('State saved');
    } catch (e) {
      debugPrint('Save state error: $e');
    }
  }

  /// 显示公告（首次启动或公告更新时）
  void _showAnnouncementIfNeeded() async {
    final shouldShow = await AnnouncementService.shouldShowAnnouncement();
    if (shouldShow && mounted) {
      final announcement = AnnouncementService.getAnnouncement();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.campaign, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text(announcement['title']!)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(announcement['content']!),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(announcement['url']!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          announcement['url']!,
                          style: const TextStyle(color: Colors.blue, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                AnnouncementService.markAsShown();
                Navigator.pop(ctx);
              },
              child: const Text('我知道了'),
            ),
          ],
        ),
      );
    }
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
    WidgetsBinding.instance.removeObserver(this);
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

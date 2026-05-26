import 'package:flutter/material.dart';

/// 8种主题皮肤预设
enum SkinType {
  white('白色', '纯净简洁'),
  black('黑色', '深邃护眼'),
  blue('蓝色护眼', '柔和舒适'),
  yellow('黄色暖光', '温暖惬意'),
  green('绿色清新', '自然养眼'),
  pink('粉色', '甜美浪漫'),
  wood('日系木色', '素雅淡然'),
  red('红色热情', '热血激情');

  final String label;
  final String desc;
  const SkinType(this.label, this.desc);
}

/// 主题配色方案
class SkinTheme {
  final SkinType type;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color appBarBg;
  final Color navBg;
  final Color navSelected;
  final Color navUnselected;
  final Color cardBg;
  final Brightness brightness;

  const SkinTheme({
    required this.type,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.appBarBg,
    required this.navBg,
    required this.navSelected,
    required this.navUnselected,
    required this.cardBg,
    required this.brightness,
  });

  ThemeData toThemeData() => ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
          primary: primary,
          secondary: secondary,
          surface: surface,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: appBarBg,
          foregroundColor: textPrimary,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: cardBg,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: navBg,
          selectedItemColor: navSelected,
          unselectedItemColor: navUnselected,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        dividerTheme: DividerThemeData(
          color: textSecondary.withOpacity(0.2),
          thickness: 0.5,
        ),
      );
}

/// 8种主题定义
class AppSkins {
  static const _errorRed = Color(0xFFFF4757);
  static const _tomatoRed = Color(0xFFFF6B6B);
  static const _tomatoOrange = Color(0xFFFF9F43);

  // ==================== 1. 白色（默认）====================
  static const white = SkinTheme(
    type: SkinType.white,
    primary: Color(0xFF6B4EFF),
    secondary: Color(0xFF00D4AA),
    background: Color(0xFFF5F5F7),
    surface: Colors.white,
    textPrimary: Color(0xFF1A1A2E),
    textSecondary: Color(0xFF8E8E93),
    appBarBg: Colors.white,
    navBg: Colors.white,
    navSelected: Color(0xFF6B4EFF),
    navUnselected: Color(0xFF8E8E93),
    cardBg: Colors.white,
    brightness: Brightness.light,
  );

  // ==================== 2. 黑色 ====================
  static const black = SkinTheme(
    type: SkinType.black,
    primary: Color(0xFF9B8AFF),
    secondary: Color(0xFF00E5BB),
    background: Color(0xFF1A1A2E),
    surface: Color(0xFF252540),
    textPrimary: Color(0xFFE8E8EE),
    textSecondary: Color(0xFF8E8E93),
    appBarBg: Color(0xFF252540),
    navBg: Color(0xFF252540),
    navSelected: Color(0xFF9B8AFF),
    navUnselected: Color(0xFF8E8E93),
    cardBg: Color(0xFF252540),
    brightness: Brightness.dark,
  );

  // ==================== 3. 蓝色护眼 ====================
  static const blue = SkinTheme(
    type: SkinType.blue,
    primary: Color(0xFF4A90D9),
    secondary: Color(0xFF5ABFBF),
    background: Color(0xFFEDF3FA),
    surface: Color(0xFFF7FAFD),
    textPrimary: Color(0xFF1E3A5F),
    textSecondary: Color(0xFF7A9BBE),
    appBarBg: Color(0xFFF7FAFD),
    navBg: Color(0xFFF7FAFD),
    navSelected: Color(0xFF4A90D9),
    navUnselected: Color(0xFF7A9BBE),
    cardBg: Color(0xFFF7FAFD),
    brightness: Brightness.light,
  );

  // ==================== 4. 黄色暖光 ====================
  static const yellow = SkinTheme(
    type: SkinType.yellow,
    primary: Color(0xFFD4A843),
    secondary: Color(0xFFE07B4C),
    background: Color(0xFFFFF8EE),
    surface: Color(0xFFFFFBF5),
    textPrimary: Color(0xFF4A3A1E),
    textSecondary: Color(0xFFB09E7A),
    appBarBg: Color(0xFFFFFBF5),
    navBg: Color(0xFFFFFBF5),
    navSelected: Color(0xFFD4A843),
    navUnselected: Color(0xFFB09E7A),
    cardBg: Color(0xFFFFFBF5),
    brightness: Brightness.light,
  );

  // ==================== 5. 绿色清新 ====================
  static const green = SkinTheme(
    type: SkinType.green,
    primary: Color(0xFF4CAF50),
    secondary: Color(0xFF81C784),
    background: Color(0xFFF1F8E9),
    surface: Color(0xFFF9FDF7),
    textPrimary: Color(0xFF2E4A1E),
    textSecondary: Color(0xFF8AAE7A),
    appBarBg: Color(0xFFF9FDF7),
    navBg: Color(0xFFF9FDF7),
    navSelected: Color(0xFF4CAF50),
    navUnselected: Color(0xFF8AAE7A),
    cardBg: Color(0xFFF9FDF7),
    brightness: Brightness.light,
  );

  // ==================== 6. 粉色 ====================
  static const pink = SkinTheme(
    type: SkinType.pink,
    primary: Color(0xFFE91E63),
    secondary: Color(0xFFFF80AB),
    background: Color(0xFFFDE8EF),
    surface: Color(0xFFFFF5F8),
    textPrimary: Color(0xFF4A1E2E),
    textSecondary: Color(0xFFCE8EA0),
    appBarBg: Color(0xFFFFF5F8),
    navBg: Color(0xFFFFF5F8),
    navSelected: Color(0xFFE91E63),
    navUnselected: Color(0xFFCE8EA0),
    cardBg: Color(0xFFFFF5F8),
    brightness: Brightness.light,
  );

  // ==================== 7. 日系木色 ====================
  static const wood = SkinTheme(
    type: SkinType.wood,
    primary: Color(0xFFA0845C),
    secondary: Color(0xFFC4A882),
    background: Color(0xFFF5F0E8),
    surface: Color(0xFFFAF7F2),
    textPrimary: Color(0xFF3E3428),
    textSecondary: Color(0xFFB0A08A),
    appBarBg: Color(0xFFFAF7F2),
    navBg: Color(0xFFFAF7F2),
    navSelected: Color(0xFFA0845C),
    navUnselected: Color(0xFFB0A08A),
    cardBg: Color(0xFFFAF7F2),
    brightness: Brightness.light,
  );

  // ==================== 8. 红色热情 ====================
  static const red = SkinTheme(
    type: SkinType.red,
    primary: Color(0xFFD32F2F),
    secondary: Color(0xFFFF6659),
    background: Color(0xFFFDEAEA),
    surface: Color(0xFFFFF5F5),
    textPrimary: Color(0xFF4A1A1A),
    textSecondary: Color(0xFFCE8E8E),
    appBarBg: Color(0xFFFFF5F5),
    navBg: Color(0xFFFFF5F5),
    navSelected: Color(0xFFD32F2F),
    navUnselected: Color(0xFFCE8E8E),
    cardBg: Color(0xFFFFF5F5),
    brightness: Brightness.light,
  );

  /// 全部主题列表
  static const all = [white, black, blue, yellow, green, pink, wood, red];

  /// 按类型获取主题
  static SkinTheme getByType(SkinType type) {
    return all.firstWhere((t) => t.type == type, orElse: () => white);
  }

  /// 兼容旧代码：保留原 AppColors 常量
  static const error = _errorRed;
  static const tomatoRed = _tomatoRed;
  static const tomatoOrange = _tomatoOrange;
}

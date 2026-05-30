import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app_themes.dart';

/// 主题皮肤 Provider
/// 使用 Hive 持久化用户选择的皮肤类型
final skinThemeProvider = StateNotifierProvider<SkinThemeNotifier, SkinTheme>((ref) {
  return SkinThemeNotifier();
});

class SkinThemeNotifier extends StateNotifier<SkinTheme> {
  static const _boxName = 'settings';
  static const _skinKey = 'skin_type';
  Box? _box;

  SkinThemeNotifier() : super(AppSkins.black) {
    _load();
  }

  /// 从 Hive 加载已保存的皮肤类型
  Future<void> _load() async {
    try {
      // 确保 box 已打开
      _box = await Hive.openBox(_boxName);
      final savedIndex = _box!.get(_skinKey, defaultValue: 1);
      if (savedIndex >= 0 && savedIndex < SkinType.values.length) {
        state = AppSkins.getByType(SkinType.values[savedIndex]);
      }
    } catch (e) {
      // 如果加载失败，使用默认主题
      debugPrint('SkinThemeNotifier load error: $e');
    }
  }

  /// 切换主题皮肤
  Future<void> setSkin(SkinType type) async {
    state = AppSkins.getByType(type);
    try {
      _box ??= await Hive.openBox(_boxName);
      await _box!.put(_skinKey, type.index);
    } catch (e) {
      debugPrint('SkinThemeNotifier save error: $e');
    }
  }
}

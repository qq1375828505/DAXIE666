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

  SkinThemeNotifier() : super(AppSkins.white) {
    _load();
  }

  /// 从 Hive 加载已保存的皮肤类型
  void _load() {
    final box = Hive.box(_boxName);
    final savedIndex = box.get(_skinKey, defaultValue: 0);
    if (savedIndex >= 0 && savedIndex < SkinType.values.length) {
      state = AppSkins.getByType(SkinType.values[savedIndex]);
    }
  }

  /// 切换主题皮肤
  void setSkin(SkinType type) {
    state = AppSkins.getByType(type);
    Hive.box(_boxName).put(_skinKey, type.index);
  }
}

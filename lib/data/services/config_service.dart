import 'package:hive/hive.dart';

class ConfigService {
  static const _boxName = 'app_config';
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  // Dark mode
  static bool get isDarkMode => _box.get('darkMode', defaultValue: false);
  static set isDarkMode(bool value) => _box.put('darkMode', value);

  // Font
  static double get fontSize => _box.get('fontSize', defaultValue: 18.0);
  static set fontSize(double value) => _box.put('fontSize', value);

  static String get fontFamily => _box.get('fontFamily', defaultValue: 'NotoSerifSC');
  static set fontFamily(String value) => _box.put('fontFamily', value);

  static double get lineHeight => _box.get('lineHeight', defaultValue: 1.8);
  static set lineHeight(double value) => _box.put('lineHeight', value);

  // Word goal
  static int get wordGoal => _box.get('wordGoal', defaultValue: 3000);
  static set wordGoal(int value) => _box.put('wordGoal', value);

  // Streak
  static int get streakDays => _box.get('streakDays', defaultValue: 0);
  static set streakDays(int value) => _box.put('streakDays', value);

  static String? get lastNovelId => _box.get('lastNovelId');
  static set lastNovelId(String? value) => _box.put('lastNovelId', value);

  static List<String> get recentNovelIds => _box.get('recentNovelIds', defaultValue: <String>[]).cast<String>();
  static set recentNovelIds(List<String> value) => _box.put('recentNovelIds', value);
}

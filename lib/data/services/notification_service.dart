import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:novel_ide/data/services/config_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Initialize notification plugin.
  static Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Show word goal reminder (called when app is in foreground).
  static Future<void> showWordGoalReminder() async {
    await init();
    final goal = ConfigService.wordGoal;
    await _plugin.show(
      0,
      '今日写作目标',
      '还差多少字？目标 $goal 字/天，加油！',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'word_goal',
          '字数提醒',
          channelDescription: '每日字数目标提醒',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  /// Show streak reminder.
  static Future<void> showStreakReminder() async {
    await init();
    final days = ConfigService.streakDays;
    if (days <= 0) return;
    await _plugin.show(
      1,
      '写作打卡',
      '已连续打卡 $days 天！继续保持！',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak',
          '打卡提醒',
          channelDescription: '连续写作打卡提醒',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  /// Show a one-time notification when daily goal is reached.
  static Future<void> showGoalReached(int wordsWritten, int goal) async {
    await init();
    if (wordsWritten < goal) return;
    await _plugin.show(
      2,
      '目标达成！',
      '今日已写 $wordsWritten 字，超过目标 $goal 字！',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'goal_reached',
          '目标达成',
          channelDescription: '每日目标达成通知',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}

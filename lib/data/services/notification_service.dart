import 'package:novel_ide/data/services/config_service.dart';

class NotificationService {
  static Future<void> scheduleWordGoalReminder() async {
    final goal = ConfigService.wordGoal;
    return;
  }

  static Future<void> scheduleStreakReminder() async {
    final days = ConfigService.streakDays;
    return;
  }
}

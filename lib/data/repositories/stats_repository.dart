import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/services/config_service.dart';
import 'package:intl/intl.dart';

class StatsRepository {
  final _db = DatabaseHelper();

  /// Record words written today for a novel.
  Future<void> recordWords(String novelId, int wordCount) async {
    if (wordCount <= 0) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _db.recordDailyWords(today, novelId, wordCount);
  }

  /// Get today's total word count (all novels).
  Future<int> getTodayWords() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return await _db.getTodayWords(today);
  }

  /// Get daily word counts for the last [days] days.
  Future<List<DailyStat>> getDailyStats({int days = 30}) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));
    final startDate = DateFormat('yyyy-MM-dd').format(start);
    final endDate = DateFormat('yyyy-MM-dd').format(now);

    final rows = await _db.getDailyWords(startDate: startDate, endDate: endDate);

    // Group by date and sum across novels
    final Map<String, int> dateMap = {};
    for (final row in rows) {
      final date = row['date'] as String;
      final count = row['word_count'] as int;
      dateMap[date] = (dateMap[date] ?? 0) + count;
    }

    // Fill in missing days with 0
    final stats = <DailyStat>[];
    for (int i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      stats.add(DailyStat(
        date: d,
        wordCount: dateMap[dateStr] ?? 0,
      ));
    }
    return stats;
  }

  /// Calculate current writing streak (consecutive days with words > 0).
  Future<int> calculateStreak() async {
    final stats = await getDailyStats(days: 365);
    int streak = 0;
    // Count from today backwards
    for (int i = stats.length - 1; i >= 0; i--) {
      if (stats[i].wordCount > 0) {
        streak++;
      } else {
        break;
      }
    }
    // Update persistence
    ConfigService.streakDays = streak;
    return streak;
  }

  /// Get total words written across all time.
  Future<int> getTotalWords() async {
    return await _db.getTotalWords();
  }
}

class DailyStat {
  final DateTime date;
  final int wordCount;

  DailyStat({required this.date, required this.wordCount});
}

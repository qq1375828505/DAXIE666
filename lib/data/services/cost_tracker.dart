import 'package:novel_ide/data/datasources/database_helper.dart';

/// Track AI API usage costs locally.
class CostTracker {
  final _db = DatabaseHelper();

  /// Record an API call. [tokenCount] is approximate tokens used.
  Future<void> recordUsage({
    required String configId,
    required String model,
    required String taskType,
    required int tokenCount,
    double estimatedCost = 0.0,
  }) async {
    final db = await _db.database;
    await db.insert('billing_records', {
      'id': '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch % 10000}',
      'config_id': configId,
      'model': model,
      'task_type': taskType,
      'token_count': tokenCount,
      'estimated_cost': estimatedCost,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Get today's usage summary.
  Future<CostSummary> getTodaySummary() async {
    final db = await _db.database;
    final startOfDay = DateTime.now().subtract(Duration(
      hours: DateTime.now().hour,
      minutes: DateTime.now().minute,
      seconds: DateTime.now().second,
    )).millisecondsSinceEpoch;

    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as call_count,
        COALESCE(SUM(token_count), 0) as total_tokens,
        COALESCE(SUM(estimated_cost), 0) as total_cost
      FROM billing_records
      WHERE created_at >= ?
    ''', [startOfDay]);

    final row = result.first;
    return CostSummary(
      callCount: row['call_count'] as int,
      totalTokens: row['total_tokens'] as int,
      totalCost: (row['total_cost'] as num).toDouble(),
    );
  }

  /// Get usage breakdown by task type for today.
  Future<List<TaskCostItem>> getTodayByTask() async {
    final db = await _db.database;
    final startOfDay = DateTime.now().subtract(Duration(
      hours: DateTime.now().hour,
      minutes: DateTime.now().minute,
      seconds: DateTime.now().second,
    )).millisecondsSinceEpoch;

    final result = await db.rawQuery('''
      SELECT
        task_type,
        COUNT(*) as call_count,
        COALESCE(SUM(token_count), 0) as total_tokens,
        COALESCE(SUM(estimated_cost), 0) as total_cost
      FROM billing_records
      WHERE created_at >= ?
      GROUP BY task_type
      ORDER BY total_tokens DESC
    ''', [startOfDay]);

    return result.map((row) => TaskCostItem(
      taskType: row['task_type'] as String,
      callCount: row['call_count'] as int,
      totalTokens: row['total_tokens'] as int,
      totalCost: (row['total_cost'] as num).toDouble(),
    )).toList();
  }
}

class CostSummary {
  final int callCount;
  final int totalTokens;
  final double totalCost;

  CostSummary({required this.callCount, required this.totalTokens, required this.totalCost});
}

class TaskCostItem {
  final String taskType;
  final int callCount;
  final int totalTokens;
  final double totalCost;

  TaskCostItem({required this.taskType, required this.callCount, required this.totalTokens, required this.totalCost});
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/repositories/stats_repository.dart';
import 'package:intl/intl.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  List<DailyStat> _dailyStats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final repo = ref.read(statsRepoProvider);
    final stats = await repo.getDailyStats(days: 30);
    final today = await repo.getTodayWords();
    final total = await repo.getTotalWords();
    final streak = await repo.calculateStreak();

    if (mounted) {
      setState(() {
        _dailyStats = stats;
        _isLoading = false;
      });
      ref.read(todayWordsProvider.notifier).state = today;
      ref.read(totalWordsProvider.notifier).state = total;
      ref.read(streakDaysProvider.notifier).state = streak;
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayWords = ref.watch(todayWordsProvider);
    final totalWords = ref.watch(totalWordsProvider);
    final streak = ref.watch(streakDaysProvider);
    final goal = ref.watch(wordGoalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('写作统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- Summary cards ---
                  Row(
                    children: [
                      Expanded(child: _SummaryCard(
                        label: '今日字数',
                        value: '$todayWords',
                        sub: '目标 $goal',
                        color: todayWords >= goal ? Colors.green : AppColors.primary,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryCard(
                        label: '连续打卡',
                        value: '$streak',
                        sub: '天',
                        color: streak > 0 ? Colors.orange : Colors.grey,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryCard(
                        label: '累计字数',
                        value: _formatCount(totalWords),
                        sub: '',
                        color: Colors.blue,
                      )),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- Daily word chart ---
                  const Text('近30天字数', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: _DailyChart(stats: _dailyStats, goal: goal),
                  ),
                  const SizedBox(height: 24),

                  // --- Goal progress ---
                  const Text('今日进度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _GoalProgress(current: todayWords, goal: goal),
                ],
              ),
            ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    return '$count';
  }
}

// --- Summary Card ---
class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _SummaryCard({required this.label, required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ],
        ),
      ),
    );
  }
}

// --- Daily Chart ---
class _DailyChart extends StatelessWidget {
  final List<DailyStat> stats;
  final int goal;

  const _DailyChart({required this.stats, required this.goal});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const Center(child: Text('暂无数据'));

    final maxY = stats.map((s) => s.wordCount).fold(0, (a, b) => a > b ? a : b);
    final topY = maxY > goal ? maxY.toDouble() : goal.toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: topY * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final stat = stats[groupIndex];
              return BarTooltipItem(
                '${DateFormat('M/d').format(stat.date)}\n${stat.wordCount}字',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= stats.length) return const SizedBox();
                // Show every 5 days
                if (idx % 5 != 0 && idx != stats.length - 1) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('M/d').format(stats[idx].date),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: topY > 0 ? topY / 4 : 1,
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: goal.toDouble(),
              color: Colors.red.withOpacity(0.5),
              strokeWidth: 1,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: TextStyle(color: Colors.red[300], fontSize: 10),
                labelResolver: (_) => '目标',
              ),
            ),
          ],
        ),
        barGroups: stats.asMap().entries.map((entry) {
          final i = entry.key;
          final stat = entry.value;
          final isToday = i == stats.length - 1;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: stat.wordCount.toDouble(),
                color: isToday
                    ? AppColors.primary
                    : stat.wordCount >= goal
                        ? Colors.green.withOpacity(0.7)
                        : Colors.blue.withOpacity(0.5),
                width: stats.length > 20 ? 6 : 10,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// --- Goal Progress ---
class _GoalProgress extends StatelessWidget {
  final int current;
  final int goal;

  const _GoalProgress({required this.current, required this.goal});

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final percentage = (progress * 100).toInt();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$current / $goal 字', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('$percentage%', style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: progress >= 1.0 ? Colors.green : AppColors.primary,
                )),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  progress >= 1.0 ? Colors.green : AppColors.primary,
                ),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              progress >= 1.0 ? '今日目标已完成！' : '还差 ${goal - current} 字达到目标',
              style: TextStyle(
                color: progress >= 1.0 ? Colors.green : Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

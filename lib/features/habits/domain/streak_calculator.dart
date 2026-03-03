import 'package:streak_forge/features/habits/data/models/habit.dart';
import 'package:streak_forge/features/habits/data/models/habit_record.dart';

class HabitStats {
  final int currentStreak;
  final int bestStreak;
  final int worstStreak;
  final int longestBreak;
  final int totalCompletions;
  final int totalDays;
  final double completionPercentage;
  final double consistencyScore;
  final int missedDays;
  final double avgCompletionsPerWeek;

  HabitStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.worstStreak,
    required this.longestBreak,
    required this.totalCompletions,
    required this.totalDays,
    required this.completionPercentage,
    required this.consistencyScore,
    required this.missedDays,
    required this.avgCompletionsPerWeek,
  });

  factory HabitStats.empty() => HabitStats(
        currentStreak: 0,
        bestStreak: 0,
        worstStreak: 0,
        longestBreak: 0,
        totalCompletions: 0,
        totalDays: 0,
        completionPercentage: 0,
        consistencyScore: 0,
        missedDays: 0,
        avgCompletionsPerWeek: 0,
      );
}

class StreakCalculator {
  /// Calculate comprehensive stats for a habit
  static HabitStats calculateStats(Habit habit, List<HabitRecord> records) {
    if (records.isEmpty) return HabitStats.empty();

    // Sort records by date ascending
    final sorted = List<HabitRecord>.from(records)
      ..sort((a, b) => a.date.compareTo(b.date));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final createdDate = DateTime(
      habit.createdAt.year,
      habit.createdAt.month,
      habit.createdAt.day,
    );

    // Total days since habit creation
    final totalDays = today.difference(createdDate).inDays + 1;

    // Create a set of completed dates
    final completedDates = <DateTime>{};
    for (final record in sorted) {
      if (record.isCompleted) {
        completedDates.add(
          DateTime(record.date.year, record.date.month, record.date.day),
        );
      }
    }

    final totalCompletions = completedDates.length;
    final missedDays = totalDays - totalCompletions;
    final completionPercentage =
        totalDays > 0 ? (totalCompletions / totalDays) * 100 : 0.0;

    // Calculate streaks
    int currentStreak = 0;
    int bestStreak = 0;
    int worstStreak = totalDays > 0 ? totalDays : 0;
    int longestBreak = 0;

    // Calculate current streak (backwards from today)
    var checkDate = today;
    while (completedDates.contains(checkDate)) {
      currentStreak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
      if (checkDate.isBefore(createdDate)) break;
    }

    // Calculate best streak and longest break
    int streak = 0;
    int breakCount = 0;

    for (int i = 0; i < totalDays; i++) {
      final date = createdDate.add(Duration(days: i));
      if (completedDates.contains(date)) {
        streak++;
        if (breakCount > longestBreak) longestBreak = breakCount;
        breakCount = 0;
      } else {
        if (streak > 0 && streak < worstStreak) worstStreak = streak;
        if (streak > bestStreak) bestStreak = streak;
        streak = 0;
        breakCount++;
      }
    }
    // Final check for last streak
    if (streak > bestStreak) bestStreak = streak;
    if (streak > 0 && streak < worstStreak) worstStreak = streak;
    if (breakCount > longestBreak) longestBreak = breakCount;

    // If no completed streaks at all
    if (totalCompletions == 0) worstStreak = 0;

    // Average completions per week
    final totalWeeks = totalDays / 7.0;
    final avgPerWeek =
        totalWeeks > 0 ? totalCompletions / totalWeeks : 0.0;

    // Consistency score (0-100)
    // Weighted: 40% completion rate, 30% current streak factor, 30% break penalty
    final streakFactor = totalDays > 0
        ? (currentStreak / totalDays * 100).clamp(0.0, 100.0)
        : 0.0;
    final breakPenalty = totalDays > 0
        ? ((1 - longestBreak / totalDays) * 100).clamp(0.0, 100.0)
        : 0.0;
    final double consistencyScore =
        (completionPercentage * 0.4 + streakFactor * 0.3 + breakPenalty * 0.3)
            .clamp(0.0, 100.0);

    return HabitStats(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      worstStreak: worstStreak,
      longestBreak: longestBreak,
      totalCompletions: totalCompletions,
      totalDays: totalDays,
      completionPercentage: completionPercentage,
      consistencyScore: consistencyScore,
      missedDays: missedDays,
      avgCompletionsPerWeek: avgPerWeek,
    );
  }

  /// Get weekly completion data for trend graph
  static List<WeeklyData> getWeeklyTrend(
    List<HabitRecord> records,
    int weeks,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <WeeklyData>[];

    for (int w = weeks - 1; w >= 0; w--) {
      final weekStart = today.subtract(Duration(days: today.weekday - 1 + w * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));

      int completed = 0;
      for (final record in records) {
        final d = DateTime(record.date.year, record.date.month, record.date.day);
        if (!d.isBefore(weekStart) && !d.isAfter(weekEnd) && record.isCompleted) {
          completed++;
        }
      }

      result.add(WeeklyData(
        weekStart: weekStart,
        completions: completed,
        total: 7,
      ));
    }

    return result;
  }
}

class WeeklyData {
  final DateTime weekStart;
  final int completions;
  final int total;

  WeeklyData({
    required this.weekStart,
    required this.completions,
    required this.total,
  });

  double get percentage => total > 0 ? completions / total * 100 : 0;
}

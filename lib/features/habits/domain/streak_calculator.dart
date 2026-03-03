import 'dart:math' as math;
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
  /// Calculate comprehensive stats for a habit.
  ///
  /// Uses the earlier of [habit.createdAt] and the earliest record date as
  /// the effective start so that marking days before creation doesn't inflate
  /// the success percentage.
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

    // Find the earliest record date
    final earliestRecordDate = DateTime(
      sorted.first.date.year,
      sorted.first.date.month,
      sorted.first.date.day,
    );

    // Effective start = whichever is earlier: createdAt or earliest record
    final effectiveStart = createdDate.isBefore(earliestRecordDate)
        ? createdDate
        : earliestRecordDate;

    // Total days from effective start to today (at least 1)
    final totalDays = math.max(1, today.difference(effectiveStart).inDays + 1);

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
    final missedDays = math.max(0, totalDays - totalCompletions);

    // Success percentage: completions out of total days, capped at 100%
    final completionPercentage =
        totalDays > 0
            ? ((totalCompletions / totalDays) * 100.0).clamp(0.0, 100.0)
            : 0.0;

    // ── Streak Calculation ──

    // Current streak (backwards from today)
    int currentStreak = 0;
    var checkDate = today;
    while (completedDates.contains(checkDate)) {
      currentStreak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
      if (checkDate.isBefore(effectiveStart)) break;
    }

    // Walk through all days to find best streak, worst streak, longest break
    int bestStreak = 0;
    int longestBreak = 0;
    int tempStreak = 0;
    int tempBreak = 0;
    final allStreaks = <int>[];

    for (int i = 0; i < totalDays; i++) {
      final date = effectiveStart.add(Duration(days: i));
      if (completedDates.contains(date)) {
        tempStreak++;
        if (tempBreak > longestBreak) longestBreak = tempBreak;
        tempBreak = 0;
      } else {
        if (tempStreak > 0) {
          allStreaks.add(tempStreak);
        }
        if (tempStreak > bestStreak) bestStreak = tempStreak;
        tempStreak = 0;
        tempBreak++;
      }
    }
    // Handle final segment
    if (tempStreak > 0) {
      allStreaks.add(tempStreak);
      if (tempStreak > bestStreak) bestStreak = tempStreak;
    }
    if (tempBreak > longestBreak) longestBreak = tempBreak;

    // Worst streak: the smallest non-zero streak
    int worstStreak = 0;
    if (allStreaks.isNotEmpty) {
      worstStreak = allStreaks.reduce((a, b) => a < b ? a : b);
    }

    // ── Average Completions per Week ──
    // Total weeks from effective start, at least 1 to avoid division by zero
    final double totalWeeks = totalDays / 7.0;
    final avgPerWeek = totalWeeks >= 1.0
        ? totalCompletions / totalWeeks
        : totalCompletions.toDouble();
    // Cap avg/week to 7 for daily habits (can't do more than 7 days in a week)
    final cappedAvgPerWeek = math.min(avgPerWeek, 7.0);

    // ── Consistency Score (0-100) ──
    // Weighted: 50% completion rate, 25% current streak factor, 25% break penalty
    final streakFactor = totalDays > 0
        ? (currentStreak / totalDays * 100).clamp(0.0, 100.0)
        : 0.0;
    final breakPenalty = totalDays > 0
        ? ((1 - longestBreak / totalDays) * 100).clamp(0.0, 100.0)
        : 0.0;
    final double consistencyScore =
        (completionPercentage * 0.5 + streakFactor * 0.25 + breakPenalty * 0.25)
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
      avgCompletionsPerWeek: cappedAvgPerWeek,
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
      final weekStart =
          today.subtract(Duration(days: today.weekday - 1 + w * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));

      int completed = 0;
      for (final record in records) {
        final d =
            DateTime(record.date.year, record.date.month, record.date.day);
        if (!d.isBefore(weekStart) &&
            !d.isAfter(weekEnd) &&
            record.isCompleted) {
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:streak_forge/services/database_service.dart';
import 'package:streak_forge/features/habits/data/repositories/habit_repository.dart';
import 'package:streak_forge/features/habits/data/repositories/habit_record_repository.dart';
import 'package:streak_forge/features/habits/data/repositories/category_repository.dart';
import 'package:streak_forge/features/habits/data/models/habit.dart';
import 'package:streak_forge/features/habits/data/models/habit_record.dart';
import 'package:streak_forge/features/habits/data/models/category.dart';
import 'package:streak_forge/features/habits/domain/streak_calculator.dart';

// ─── Database ────────────────────────────────────────────────────────────────

final isarProvider = FutureProvider<Isar>((ref) async {
  return await DatabaseService.instance;
});

// ─── Repositories ────────────────────────────────────────────────────────────

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final isar = ref.watch(isarProvider).value;
  if (isar == null) throw Exception('Database not initialized');
  return HabitRepository(isar);
});

final habitRecordRepositoryProvider = Provider<HabitRecordRepository>((ref) {
  final isar = ref.watch(isarProvider).value;
  if (isar == null) throw Exception('Database not initialized');
  return HabitRecordRepository(isar);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final isar = ref.watch(isarProvider).value;
  if (isar == null) throw Exception('Database not initialized');
  return CategoryRepository(isar);
});

// ─── Habit List ──────────────────────────────────────────────────────────────

/// Notifier that manages the list of active habits
class HabitListNotifier extends AsyncNotifier<List<Habit>> {
  @override
  Future<List<Habit>> build() async {
    final repo = ref.watch(habitRepositoryProvider);
    // Listen for changes
    repo.watchAll().listen((_) => ref.invalidateSelf());
    return await repo.getAllActive();
  }

  Future<int> addHabit(Habit habit) async {
    final repo = ref.read(habitRepositoryProvider);
    habit.createdAt = DateTime.now();
    final id = await repo.save(habit);
    ref.invalidateSelf();
    return id;
  }

  Future<void> updateHabit(Habit habit) async {
    final repo = ref.read(habitRepositoryProvider);
    await repo.save(habit);
    ref.invalidateSelf();
  }

  Future<void> deleteHabit(int id) async {
    final repo = ref.read(habitRepositoryProvider);
    await repo.delete(id);
    ref.invalidateSelf();
  }

  Future<void> archiveHabit(int id) async {
    final repo = ref.read(habitRepositoryProvider);
    await repo.toggleArchive(id);
    ref.invalidateSelf();
  }

  Future<void> reorderHabits(List<Habit> habits) async {
    final repo = ref.read(habitRepositoryProvider);
    await repo.reorder(habits);
    ref.invalidateSelf();
  }
}

final habitListProvider =
    AsyncNotifierProvider<HabitListNotifier, List<Habit>>(
  HabitListNotifier.new,
);

// ─── Today's Records ─────────────────────────────────────────────────────────

/// Selected date for viewing (defaults to today)
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// Records for the currently selected date
class TodayRecordsNotifier extends AsyncNotifier<Map<int, HabitRecord>> {
  @override
  Future<Map<int, HabitRecord>> build() async {
    final repo = ref.watch(habitRecordRepositoryProvider);
    final date = ref.watch(selectedDateProvider);

    repo.watchAll().listen((_) => ref.invalidateSelf());

    final records = await repo.getForDate(date);
    return {for (var r in records) r.habitId: r};
  }

  Future<void> toggleHabit(int habitId) async {
    final repo = ref.read(habitRecordRepositoryProvider);
    final date = ref.read(selectedDateProvider);
    await repo.toggleCompletion(habitId, date);
    ref.invalidateSelf();
  }

  Future<void> updateFrequencyValue(
    int habitId,
    double value, {
    required bool isMinTarget,
    required double targetValue,
  }) async {
    final repo = ref.read(habitRecordRepositoryProvider);
    final date = ref.read(selectedDateProvider);
    await repo.updateValue(
      habitId,
      date,
      value,
      isMinTarget: isMinTarget,
      targetValue: targetValue,
    );
    ref.invalidateSelf();
  }
}

final todayRecordsProvider =
    AsyncNotifierProvider<TodayRecordsNotifier, Map<int, HabitRecord>>(
  TodayRecordsNotifier.new,
);

// ─── Habit Stats ─────────────────────────────────────────────────────────────

/// Stats for a specific habit
final habitStatsProvider =
    FutureProvider.family<HabitStats, int>((ref, habitId) async {
  final recordRepo = ref.watch(habitRecordRepositoryProvider);
  final habitRepo = ref.watch(habitRepositoryProvider);

  // Listen for changes
  recordRepo.watchAll().listen((_) => ref.invalidateSelf());

  final habit = await habitRepo.getById(habitId);
  if (habit == null) return HabitStats.empty();

  final records = await recordRepo.getAllForHabit(habitId);
  return StreakCalculator.calculateStats(habit, records);
});

/// Records for heatmap of a specific habit
final habitHeatmapProvider =
    FutureProvider.family<Map<DateTime, double>, int>((ref, habitId) async {
  final recordRepo = ref.watch(habitRecordRepositoryProvider);
  recordRepo.watchAll().listen((_) => ref.invalidateSelf());

  final now = DateTime.now();
  final yearAgo = DateTime(now.year - 1, now.month, now.day);
  final records = await recordRepo.getForDateRange(habitId, yearAgo, now);

  final map = <DateTime, double>{};
  for (final record in records) {
    final dateKey = DateTime(record.date.year, record.date.month, record.date.day);
    if (record.isCompleted) {
      map[dateKey] = record.value ?? 1.0;
    }
  }
  return map;
});

/// Weekly trend data for a habit (last 8 weeks)
final habitWeeklyTrendProvider =
    FutureProvider.family<List<WeeklyData>, int>((ref, habitId) async {
  final recordRepo = ref.watch(habitRecordRepositoryProvider);
  recordRepo.watchAll().listen((_) => ref.invalidateSelf());

  final records = await recordRepo.getAllForHabit(habitId);
  return StreakCalculator.getWeeklyTrend(records, 8);
});

// ─── Categories ──────────────────────────────────────────────────────────────

class CategoryListNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    final repo = ref.watch(categoryRepositoryProvider);
    repo.watchAll().listen((_) => ref.invalidateSelf());
    return await repo.getAll();
  }

  Future<int> addCategory(Category category) async {
    final repo = ref.read(categoryRepositoryProvider);
    final id = await repo.save(category);
    ref.invalidateSelf();
    return id;
  }

  Future<void> deleteCategory(int id) async {
    final repo = ref.read(categoryRepositoryProvider);
    await repo.delete(id);
    ref.invalidateSelf();
  }
}

final categoryListProvider =
    AsyncNotifierProvider<CategoryListNotifier, List<Category>>(
  CategoryListNotifier.new,
);

// ─── Selected Category Filter ────────────────────────────────────────────────

/// null means "All", otherwise filter by category ID
final selectedCategoryFilter = StateProvider<int?>((ref) => null);

// ─── Navigation ──────────────────────────────────────────────────────────────

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

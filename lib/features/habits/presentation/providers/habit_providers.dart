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
    // Don't override createdAt if it was already set (e.g. from date picker)
    if (habit.id == Isar.autoIncrement) {
      habit.createdAt = habit.createdAt;
    }
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

  /// Returns true if the habit's start date was adjusted backwards
  Future<bool> toggleHabit(int habitId) async {
    final repo = ref.read(habitRecordRepositoryProvider);
    final date = ref.read(selectedDateProvider);
    await repo.toggleCompletion(habitId, date);

    // Auto-adjust createdAt if marking before the start date
    final adjusted = await _adjustStartDateIfNeeded(habitId, date);

    ref.invalidateSelf();
    return adjusted;
  }

  /// Returns true if the habit's start date was adjusted backwards
  Future<bool> updateFrequencyValue(
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

    // Auto-adjust createdAt if marking before the start date
    final adjusted = await _adjustStartDateIfNeeded(habitId, date);

    ref.invalidateSelf();
    return adjusted;
  }

  /// Moves habit.createdAt back if the user marks a day before the current start date.
  /// Returns true if the date was adjusted.
  Future<bool> _adjustStartDateIfNeeded(int habitId, DateTime date) async {
    final habitRepo = ref.read(habitRepositoryProvider);
    final habit = await habitRepo.getById(habitId);
    if (habit == null) return false;

    final dateOnly = DateTime(date.year, date.month, date.day);
    final createdOnly = DateTime(
      habit.createdAt.year,
      habit.createdAt.month,
      habit.createdAt.day,
    );

    if (dateOnly.isBefore(createdOnly)) {
      habit.createdAt = dateOnly;
      await habitRepo.save(habit);
      return true;
    }
    return false;
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
  final habitRepo = ref.watch(habitRepositoryProvider);
  recordRepo.watchAll().listen((_) => ref.invalidateSelf());

  final now = DateTime.now();
  final yearAgo = DateTime(now.year - 1, now.month, now.day);

  // Get the habit to know its start date
  final habit = await habitRepo.getById(habitId);
  final startDate = habit?.createdAt ?? yearAgo;
  // Use the later of yearAgo or startDate as the lower bound
  final lowerBound = startDate.isAfter(yearAgo) ? yearAgo : yearAgo;

  final records = await recordRepo.getForDateRange(habitId, lowerBound, now);

  final map = <DateTime, double>{};
  final habitStart = DateTime(startDate.year, startDate.month, startDate.day);
  for (final record in records) {
    final dateKey = DateTime(record.date.year, record.date.month, record.date.day);
    // Only include records on or after the habit start date
    if (record.isCompleted && !dateKey.isBefore(habitStart)) {
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

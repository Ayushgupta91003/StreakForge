import 'package:isar/isar.dart';
import 'package:streak_forge/features/habits/data/models/habit.dart';
import 'package:streak_forge/features/habits/data/models/habit_record.dart';

class HabitRepository {
  final Isar _isar;

  HabitRepository(this._isar);

  /// Get all active (non-archived) habits, sorted by order
  Future<List<Habit>> getAllActive() async {
    return await _isar.habits
        .filter()
        .isArchivedEqualTo(false)
        .sortByOrder()
        .findAll();
  }

  /// Get all archived habits
  Future<List<Habit>> getAllArchived() async {
    return await _isar.habits
        .filter()
        .isArchivedEqualTo(true)
        .sortByOrder()
        .findAll();
  }

  /// Get habits by category
  Future<List<Habit>> getByCategory(int categoryId) async {
    return await _isar.habits
        .filter()
        .categoryIdEqualTo(categoryId)
        .isArchivedEqualTo(false)
        .sortByOrder()
        .findAll();
  }

  /// Get a single habit by ID
  Future<Habit?> getById(int id) async {
    return await _isar.habits.get(id);
  }

  /// Create or update a habit
  Future<int> save(Habit habit) async {
    return await _isar.writeTxn(() async {
      return await _isar.habits.put(habit);
    });
  }

  /// Delete a habit and all its records
  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      // Delete all records for this habit
      await _isar.collection<HabitRecord>().filter().habitIdEqualTo(id).deleteAll();
      // Delete the habit
      await _isar.habits.delete(id);
    });
  }

  /// Archive/unarchive a habit
  Future<void> toggleArchive(int id) async {
    await _isar.writeTxn(() async {
      final habit = await _isar.habits.get(id);
      if (habit != null) {
        habit.isArchived = !habit.isArchived;
        await _isar.habits.put(habit);
      }
    });
  }

  /// Reorder habits
  Future<void> reorder(List<Habit> habits) async {
    await _isar.writeTxn(() async {
      for (int i = 0; i < habits.length; i++) {
        habits[i].order = i;
      }
      await _isar.habits.putAll(habits);
    });
  }

  /// Watch all active habits for live updates
  Stream<void> watchAll() {
    return _isar.habits.watchLazy();
  }

  /// Count total habits
  Future<int> count() async {
    return await _isar.habits.count();
  }
}

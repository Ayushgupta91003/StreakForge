import 'package:isar/isar.dart';
import 'package:streak_forge/features/habits/data/models/habit_record.dart';

class HabitRecordRepository {
  final Isar _isar;

  HabitRecordRepository(this._isar);

  /// Get record for a specific habit on a specific date
  Future<HabitRecord?> getRecord(int habitId, DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final nextDay = dateOnly.add(const Duration(days: 1));

    return await _isar.habitRecords
        .filter()
        .habitIdEqualTo(habitId)
        .dateBetween(dateOnly, nextDay, includeUpper: false)
        .findFirst();
  }

  /// Get all records for a habit
  Future<List<HabitRecord>> getAllForHabit(int habitId) async {
    return await _isar.habitRecords
        .filter()
        .habitIdEqualTo(habitId)
        .sortByDateDesc()
        .findAll();
  }

  /// Get records for a habit within a date range
  Future<List<HabitRecord>> getForDateRange(
    int habitId,
    DateTime start,
    DateTime end,
  ) async {
    return await _isar.habitRecords
        .filter()
        .habitIdEqualTo(habitId)
        .dateBetween(start, end)
        .sortByDate()
        .findAll();
  }

  /// Get all records for a specific date (all habits)
  Future<List<HabitRecord>> getForDate(DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final nextDay = dateOnly.add(const Duration(days: 1));

    return await _isar.habitRecords
        .filter()
        .dateBetween(dateOnly, nextDay, includeUpper: false)
        .findAll();
  }

  /// Save or update a record
  Future<int> save(HabitRecord record) async {
    record.updatedAt = DateTime.now();
    return await _isar.writeTxn(() async {
      return await _isar.habitRecords.put(record);
    });
  }

  /// Toggle Yes/No habit for a date
  Future<HabitRecord> toggleCompletion(int habitId, DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    var record = await getRecord(habitId, dateOnly);

    if (record == null) {
      record = HabitRecord()
        ..habitId = habitId
        ..date = dateOnly
        ..isCompleted = true
        ..updatedAt = DateTime.now();
    } else {
      record.isCompleted = !record.isCompleted;
      record.updatedAt = DateTime.now();
    }

    await save(record);
    return record;
  }

  /// Update frequency value for a date
  Future<HabitRecord> updateValue(
    int habitId,
    DateTime date,
    double value, {
    bool isMinTarget = true,
    double targetValue = 0,
  }) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    var record = await getRecord(habitId, dateOnly);

    if (record == null) {
      record = HabitRecord()
        ..habitId = habitId
        ..date = dateOnly
        ..value = value
        ..updatedAt = DateTime.now();
    } else {
      record.value = value;
      record.updatedAt = DateTime.now();
    }

    // Determine completion based on target
    if (isMinTarget) {
      record.isCompleted = value >= targetValue;
    } else {
      record.isCompleted = value <= targetValue;
    }

    await save(record);
    return record;
  }

  /// Delete a specific record
  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.habitRecords.delete(id);
    });
  }

  /// Delete all records for a habit before a given date
  Future<int> deleteRecordsBeforeDate(int habitId, DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return await _isar.writeTxn(() async {
      return await _isar.habitRecords
          .filter()
          .habitIdEqualTo(habitId)
          .dateLessThan(dateOnly)
          .deleteAll();
    });
  }

  /// Get completed count for a habit
  Future<int> getCompletedCount(int habitId) async {
    return await _isar.habitRecords
        .filter()
        .habitIdEqualTo(habitId)
        .isCompletedEqualTo(true)
        .count();
  }

  /// Watch records for live updates
  Stream<void> watchAll() {
    return _isar.habitRecords.watchLazy();
  }
}

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:streak_forge/features/habits/data/models/habit.dart';
import 'package:streak_forge/features/habits/data/models/habit_record.dart';
import 'package:streak_forge/features/habits/data/models/category.dart';
import 'package:streak_forge/features/reminders/data/models/reminder.dart';

class DatabaseService {
  static Isar? _isar;

  static Future<Isar> get instance async {
    if (_isar != null && _isar!.isOpen) return _isar!;
    _isar = await _openDb();
    return _isar!;
  }

  static Future<Isar> _openDb() async {
    final dir = await getApplicationDocumentsDirectory();
    return await Isar.open(
      [HabitSchema, HabitRecordSchema, CategorySchema, ReminderSchema],
      directory: dir.path,
      name: 'streak_forge',
    );
  }

  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}

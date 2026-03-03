import 'package:isar/isar.dart';

part 'habit.g.dart';

/// Enum for habit types
enum HabitType {
  yesNo,
  frequency,
}

/// Enum for habit frequency schedule
enum HabitFrequency {
  daily,
  weekly,
  custom,
}

@collection
class Habit {
  Id id = Isar.autoIncrement;

  late String name;
  String? description;
  late String icon; // Material icon name
  late int color;   // Color value as int

  @enumerated
  late HabitType type;

  // Yes/No specific
  /// If true, YES means success (positive habit)
  /// If false, NO means success (quitting bad habit)
  bool isPositive = true;

  // Frequency specific
  double? targetValue;
  String? unit;
  /// If true, target is minimum (at least X). If false, target is maximum (less than X).
  bool isMinTarget = true;

  @enumerated
  late HabitFrequency frequency;

  /// For custom frequency - list of weekday indices (1=Mon, 7=Sun)
  List<int> customDays = [];

  int? categoryId;
  bool isArchived = false;
  late DateTime createdAt;
  int order = 0;

  /// Notification reminder IDs linked to this habit
  List<int> reminderIds = [];
}

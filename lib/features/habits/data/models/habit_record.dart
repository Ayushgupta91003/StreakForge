import 'package:isar/isar.dart';

part 'habit_record.g.dart';

@collection
class HabitRecord {
  Id id = Isar.autoIncrement;

  late int habitId;

  /// The date of this record (stored as date only, no time)
  @Index()
  late DateTime date;

  /// For Yes/No habits: was it completed?
  bool isCompleted = false;

  /// For frequency habits: the value recorded
  double? value;

  /// Optional note for this entry
  String? note;

  /// Timestamp when this record was created/updated
  late DateTime updatedAt;
}

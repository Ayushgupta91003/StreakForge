import 'package:isar/isar.dart';

part 'reminder.g.dart';

@collection
class Reminder {
  Id id = Isar.autoIncrement;

  late int habitId;

  /// Time of day stored as minutes from midnight (e.g., 8:30 AM = 510)
  late int timeInMinutes;

  /// Days of week this reminder fires (1=Mon, 7=Sun)
  List<int> days = [1, 2, 3, 4, 5, 6, 7];

  bool isEnabled = true;

  /// Custom sound file path (null = default)
  String? soundPath;
}

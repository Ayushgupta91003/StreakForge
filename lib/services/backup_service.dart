import 'dart:convert';
import 'dart:io';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:streak_forge/features/habits/data/models/habit.dart';
import 'package:streak_forge/features/habits/data/models/habit_record.dart';
import 'package:streak_forge/features/habits/data/models/category.dart';

class BackupService {
  final Isar _isar;

  BackupService(this._isar);

  /// Export all habit data as CSV
  Future<File> exportCsv() async {
    final habits = await _isar.habits.where().findAll();
    final records = await _isar.habitRecords.where().findAll();

    // Create habit name lookup
    final habitNames = {for (var h in habits) h.id: h.name};

    // Build CSV rows
    final rows = <List<dynamic>>[
      // Header
      ['Habit Name', 'Date', 'Completed', 'Value', 'Note'],
      // Data
      ...records.map((r) => [
            habitNames[r.habitId] ?? 'Unknown',
            r.date.toIso8601String().substring(0, 10),
            r.isCompleted ? 'Yes' : 'No',
            r.value ?? '',
            r.note ?? '',
          ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/streakforge_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);
    return file;
  }

  /// Share CSV file
  Future<void> shareCsv() async {
    final file = await exportCsv();
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'StreakForge Habit Data Export',
    );
  }

  /// Backup all data as JSON
  Future<File> backupJson() async {
    final habits = await _isar.habits.where().findAll();
    final records = await _isar.habitRecords.where().findAll();
    final categories = await _isar.categorys.where().findAll();

    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'habits': habits
          .map((h) => {
                'id': h.id,
                'name': h.name,
                'description': h.description,
                'icon': h.icon,
                'color': h.color,
                'type': h.type.index,
                'isPositive': h.isPositive,
                'targetValue': h.targetValue,
                'unit': h.unit,
                'isMinTarget': h.isMinTarget,
                'frequency': h.frequency.index,
                'customDays': h.customDays,
                'categoryId': h.categoryId,
                'isArchived': h.isArchived,
                'createdAt': h.createdAt.toIso8601String(),
                'order': h.order,
              })
          .toList(),
      'records': records
          .map((r) => {
                'habitId': r.habitId,
                'date': r.date.toIso8601String(),
                'isCompleted': r.isCompleted,
                'value': r.value,
                'note': r.note,
              })
          .toList(),
      'categories': categories
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'icon': c.icon,
                'color': c.color,
                'order': c.order,
              })
          .toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/streakforge_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);
    return file;
  }

  /// Share backup file
  Future<void> shareBackup() async {
    final file = await backupJson();
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'StreakForge Backup',
    );
  }

  /// Restore from JSON backup
  Future<int> restoreFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    int restoredCount = 0;

    await _isar.writeTxn(() async {
      // Restore habits
      if (data['habits'] != null) {
        for (final hData in data['habits']) {
          final habit = Habit()
            ..name = hData['name']
            ..description = hData['description']
            ..icon = hData['icon'] ?? 'star'
            ..color = hData['color'] ?? 0xFF6C63FF
            ..type = HabitType.values[hData['type'] ?? 0]
            ..isPositive = hData['isPositive'] ?? true
            ..targetValue = hData['targetValue']?.toDouble()
            ..unit = hData['unit']
            ..isMinTarget = hData['isMinTarget'] ?? true
            ..frequency = HabitFrequency.values[hData['frequency'] ?? 0]
            ..customDays = List<int>.from(hData['customDays'] ?? [])
            ..categoryId = hData['categoryId']
            ..isArchived = hData['isArchived'] ?? false
            ..createdAt = DateTime.parse(hData['createdAt'])
            ..order = hData['order'] ?? 0;

          final newId = await _isar.habits.put(habit);

          // Restore records for this habit
          if (data['records'] != null) {
            final oldId = hData['id'];
            final habitRecords = (data['records'] as List)
                .where((r) => r['habitId'] == oldId);

            for (final rData in habitRecords) {
              final record = HabitRecord()
                ..habitId = newId
                ..date = DateTime.parse(rData['date'])
                ..isCompleted = rData['isCompleted'] ?? false
                ..value = rData['value']?.toDouble()
                ..note = rData['note']
                ..updatedAt = DateTime.now();
              await _isar.habitRecords.put(record);
              restoredCount++;
            }
          }
        }
      }

      // Restore categories
      if (data['categories'] != null) {
        for (final cData in data['categories']) {
          final category = Category()
            ..name = cData['name']
            ..icon = cData['icon'] ?? 'star'
            ..color = cData['color'] ?? 0xFF6C63FF
            ..order = cData['order'] ?? 0;
          await _isar.categorys.put(category);
        }
      }
    });

    return restoredCount;
  }
}

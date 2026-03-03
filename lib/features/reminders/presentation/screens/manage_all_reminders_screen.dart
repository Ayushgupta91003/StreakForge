import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:streak_forge/core/theme/app_theme.dart';
import 'package:streak_forge/features/habits/data/models/habit.dart';
import 'package:streak_forge/features/reminders/data/models/reminder.dart';
import 'package:streak_forge/features/habits/presentation/providers/habit_providers.dart';
import 'package:streak_forge/core/constants/app_icons.dart';
import 'package:streak_forge/services/notification_service.dart';

/// Shows all reminders across all habits, allowing bulk management
class ManageAllRemindersScreen extends ConsumerStatefulWidget {
  const ManageAllRemindersScreen({super.key});

  @override
  ConsumerState<ManageAllRemindersScreen> createState() =>
      _ManageAllRemindersScreenState();
}

class _ManageAllRemindersScreenState
    extends ConsumerState<ManageAllRemindersScreen> {
  List<_HabitWithReminders> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isar = ref.read(isarProvider).value;
    if (isar == null) return;

    final habits = await isar.habits.where().findAll();
    final allReminders = await isar.reminders.where().findAll();

    final entries = <_HabitWithReminders>[];
    for (final habit in habits) {
      final reminders =
          allReminders.where((r) => r.habitId == habit.id).toList();
      if (reminders.isNotEmpty) {
        entries.add(_HabitWithReminders(habit: habit, reminders: reminders));
      }
    }

    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Reminders'),
        actions: [
          TextButton.icon(
            onPressed: _muteAll,
            icon: const Icon(Icons.notifications_off_rounded, size: 18),
            label: const Text('Mute All'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.notifications_off_rounded,
              color: AppColors.textTertiary,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No reminders set',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add reminders from habit detail screens',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final color = Color(entry.habit.color);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.surfaceVariant.withOpacity(0.5),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Habit header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        AppIcons.getIcon(entry.habit.icon),
                        color: color,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.habit.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.reminders.length} reminder${entry.reminders.length > 1 ? "s" : ""}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // Reminder rows
              ...entry.reminders.map((reminder) {
                final hour = reminder.timeInMinutes ~/ 60;
                final minute = reminder.timeInMinutes % 60;
                final time = TimeOfDay(hour: hour, minute: minute);

                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.alarm_rounded,
                    color: reminder.isEnabled
                        ? color
                        : AppColors.textTertiary,
                    size: 20,
                  ),
                  title: Text(
                    time.format(context),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: reminder.isEnabled
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                  trailing: Switch(
                    value: reminder.isEnabled,
                    onChanged: (v) => _toggleReminder(reminder, entry.habit, v),
                  ),
                );
              }),

              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleReminder(
      Reminder reminder, Habit habit, bool enabled) async {
    final isar = ref.read(isarProvider).value;
    if (isar == null) return;

    reminder.isEnabled = enabled;
    await isar.writeTxn(() async {
      await isar.reminders.put(reminder);
    });

    final hour = reminder.timeInMinutes ~/ 60;
    final minute = reminder.timeInMinutes % 60;

    if (enabled) {
      await NotificationService().scheduleDaily(
        id: reminder.id * 100,
        title: habit.name,
        body: 'Time to work on your habit! 💪',
        hour: hour,
        minute: minute,
        payload: '${habit.id}',
      );
    } else {
      await NotificationService().cancelReminder(reminder.id * 100);
    }

    await _load();
  }

  Future<void> _muteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mute All Reminders?'),
        content: const Text(
          'This will disable all scheduled reminders. You can re-enable them individually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Mute All',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final isar = ref.read(isarProvider).value;
    if (isar == null) return;

    // Disable all reminders
    final allReminders = await isar.reminders.where().findAll();
    await isar.writeTxn(() async {
      for (final r in allReminders) {
        r.isEnabled = false;
        await isar.reminders.put(r);
      }
    });

    await NotificationService().cancelAll();
    await _load();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All reminders muted')),
      );
    }
  }
}

class _HabitWithReminders {
  final Habit habit;
  final List<Reminder> reminders;

  _HabitWithReminders({required this.habit, required this.reminders});
}

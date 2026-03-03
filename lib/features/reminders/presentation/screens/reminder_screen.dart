import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:streak_forge/core/theme/app_theme.dart';
import 'package:streak_forge/features/reminders/data/models/reminder.dart';
import 'package:streak_forge/features/habits/presentation/providers/habit_providers.dart';
import 'package:streak_forge/services/notification_service.dart';

// ─── Reminder Repository ─────────────────────────────────────────────────────

class ReminderRepository {
  final Isar _isar;
  ReminderRepository(this._isar);

  Future<List<Reminder>> getForHabit(int habitId) async {
    return await _isar.reminders.filter().habitIdEqualTo(habitId).findAll();
  }

  Future<int> save(Reminder reminder) async {
    return await _isar.writeTxn(() async {
      return await _isar.reminders.put(reminder);
    });
  }

  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.reminders.delete(id);
    });
  }

  Future<void> deleteForHabit(int habitId) async {
    await _isar.writeTxn(() async {
      await _isar.reminders.filter().habitIdEqualTo(habitId).deleteAll();
    });
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final isar = ref.watch(isarProvider).value;
  if (isar == null) throw Exception('Database not initialized');
  return ReminderRepository(isar);
});

final habitRemindersProvider =
    FutureProvider.family<List<Reminder>, int>((ref, habitId) async {
  final repo = ref.watch(reminderRepositoryProvider);
  return await repo.getForHabit(habitId);
});

// ─── Reminder Management Screen ──────────────────────────────────────────────

class ReminderManagementScreen extends ConsumerStatefulWidget {
  final int habitId;
  final String habitName;

  const ReminderManagementScreen({
    super.key,
    required this.habitId,
    required this.habitName,
  });

  @override
  ConsumerState<ReminderManagementScreen> createState() =>
      _ReminderManagementScreenState();
}

class _ReminderManagementScreenState
    extends ConsumerState<ReminderManagementScreen> {
  List<Reminder> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final repo = ref.read(reminderRepositoryProvider);
    final reminders = await repo.getForHabit(widget.habitId);
    setState(() {
      _reminders = reminders;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? _buildEmpty()
              : _buildList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReminder,
        child: const Icon(Icons.add_rounded),
      ),
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
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.notifications_off_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No reminders yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap + to add a reminder',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reminders.length,
      itemBuilder: (context, index) {
        final reminder = _reminders[index];
        final hour = reminder.timeInMinutes ~/ 60;
        final minute = reminder.timeInMinutes % 60;
        final time = TimeOfDay(hour: hour, minute: minute);
        final timeStr = time.format(context);

        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final days = reminder.days.map((d) => dayNames[d - 1]).join(', ');

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.surfaceVariant.withOpacity(0.5),
              width: 0.5,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: reminder.isEnabled
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.alarm_rounded,
                color: reminder.isEnabled
                    ? Theme.of(context).colorScheme.primary
                    : AppColors.textTertiary,
                size: 22,
              ),
            ),
            title: Text(
              timeStr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: reminder.isEnabled
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ),
            subtitle: Text(
              days,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: reminder.isEnabled,
                  onChanged: (v) => _toggleReminder(reminder, v),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error, size: 20),
                  onPressed: () => _deleteReminder(reminder),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addReminder() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    final reminder = Reminder()
      ..habitId = widget.habitId
      ..timeInMinutes = time.hour * 60 + time.minute
      ..days = [1, 2, 3, 4, 5, 6, 7]
      ..isEnabled = true;

    final repo = ref.read(reminderRepositoryProvider);
    final id = await repo.save(reminder);
    reminder.id = id;

    // Schedule notification
    await NotificationService().scheduleDaily(
      id: id * 100,
      title: '${widget.habitName}',
      body: 'Time to work on your habit! 💪',
      hour: time.hour,
      minute: time.minute,
      payload: '${widget.habitId}',
    );

    await _loadReminders();
  }

  Future<void> _toggleReminder(Reminder reminder, bool enabled) async {
    reminder.isEnabled = enabled;
    final repo = ref.read(reminderRepositoryProvider);
    await repo.save(reminder);

    final hour = reminder.timeInMinutes ~/ 60;
    final minute = reminder.timeInMinutes % 60;

    if (enabled) {
      await NotificationService().scheduleDaily(
        id: reminder.id * 100,
        title: widget.habitName,
        body: 'Time to work on your habit! 💪',
        hour: hour,
        minute: minute,
        payload: '${widget.habitId}',
      );
    } else {
      await NotificationService().cancelReminder(reminder.id * 100);
    }

    await _loadReminders();
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    final repo = ref.read(reminderRepositoryProvider);
    await repo.delete(reminder.id);
    await NotificationService().cancelReminder(reminder.id * 100);
    await _loadReminders();
  }
}

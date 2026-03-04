import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:streak_forge/core/theme/app_theme.dart';
import 'package:streak_forge/core/constants/app_icons.dart';
import 'package:streak_forge/features/habits/data/models/habit.dart';
import 'package:streak_forge/features/habits/presentation/providers/habit_providers.dart';
import 'package:streak_forge/features/reminders/data/models/reminder.dart';
import 'package:streak_forge/features/reminders/presentation/screens/reminder_screen.dart';
import 'package:streak_forge/services/notification_service.dart';


class CreateHabitScreen extends ConsumerStatefulWidget {
  final Habit? existingHabit;

  const CreateHabitScreen({super.key, this.existingHabit});

  @override
  ConsumerState<CreateHabitScreen> createState() => _CreateHabitScreenState();
}

class _CreateHabitScreenState extends ConsumerState<CreateHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _targetController = TextEditingController();
  final _unitController = TextEditingController();

  HabitType _type = HabitType.yesNo;
  bool _isPositive = true;
  bool _isMinTarget = true;
  HabitFrequency _frequency = HabitFrequency.daily;
  List<int> _customDays = [1, 2, 3, 4, 5, 6, 7];
  String _selectedIcon = 'star';
  int _selectedColorIndex = 0;
  TimeOfDay? _reminderTime;

  DateTime _startDate = DateTime.now();

  bool get _isEditing => widget.existingHabit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final h = widget.existingHabit!;
      _nameController.text = h.name;
      _descController.text = h.description ?? '';
      _type = h.type;
      _isPositive = h.isPositive;
      _isMinTarget = h.isMinTarget;
      _targetController.text = h.targetValue?.toString() ?? '';
      _unitController.text = h.unit ?? '';
      _frequency = h.frequency;
      _customDays = List.from(h.customDays);
      _selectedIcon = h.icon;
      _selectedColorIndex = AppColors.habitColors
          .indexWhere((c) => c.value == h.color)
          .clamp(0, AppColors.habitColors.length - 1);
      _startDate = h.createdAt;
      _loadExistingReminder();
    }
  }

  Future<void> _loadExistingReminder() async {
    // Wait until build is done to safely use ref
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    
    final repo = ref.read(reminderRepositoryProvider);
    final reminders = await repo.getForHabit(widget.existingHabit!.id);
    if (reminders.isNotEmpty && mounted) {
      final rem = reminders.first;
      setState(() {
        _reminderTime = TimeOfDay(
          hour: rem.timeInMinutes ~/ 60,
          minute: rem.timeInMinutes % 60,
        );
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Habit' : 'New Habit'),
        actions: [
          TextButton(
            onPressed: _saveHabit,
            child: Text(
              _isEditing ? 'Save' : 'Create',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ─── Habit Type Selector ───
            _buildSectionTitle('Habit Type'),
            const SizedBox(height: 10),
            _buildTypeSelector(),
            const SizedBox(height: 24),

            // ─── Name ───
            _buildSectionTitle('Habit Name'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'e.g., Morning Workout',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 20),

            // ─── Description ───
            _buildSectionTitle('Description (optional)'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Why is this habit important?',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // ─── Type-specific fields ───
            if (_type == HabitType.yesNo) ...[
              _buildSectionTitle('Success Condition'),
              const SizedBox(height: 10),
              _buildPositiveToggle(),
            ] else ...[
              _buildSectionTitle('Target'),
              const SizedBox(height: 10),
              _buildMinMaxToggle(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _targetController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Target value',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter target'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Unit',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // ─── Frequency ───
            _buildSectionTitle('Frequency'),
            const SizedBox(height: 10),
            _buildFrequencySelector(),
            if (_frequency == HabitFrequency.custom) ...[
              const SizedBox(height: 12),
              _buildCustomDaySelector(),
            ],
            const SizedBox(height: 24),

            // ─── Start Date ───
            _buildSectionTitle('Start Date'),
            const SizedBox(height: 10),
            _buildStartDatePicker(),
            const SizedBox(height: 24),

            // ─── Icon ───
            _buildSectionTitle('Icon'),
            const SizedBox(height: 10),
            _buildIconPicker(),
            const SizedBox(height: 24),

            // ─── Color ───
            _buildSectionTitle('Color'),
            const SizedBox(height: 10),
            _buildColorPicker(),
            const SizedBox(height: 24),

            // ─── Reminder ───
            _buildSectionTitle('Reminder (optional)'),
            const SizedBox(height: 10),
            _buildReminderPicker(),
            const SizedBox(height: 40),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _SelectionCard(
            title: 'Yes / No',
            subtitle: 'Did you do it?',
            icon: Icons.check_circle_outline_rounded,
            isSelected: _type == HabitType.yesNo,
            onTap: () => setState(() => _type = HabitType.yesNo),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SelectionCard(
            title: 'Frequency',
            subtitle: 'Track a number',
            icon: Icons.trending_up_rounded,
            isSelected: _type == HabitType.frequency,
            onTap: () => setState(() => _type = HabitType.frequency),
          ),
        ),
      ],
    );
  }

  Widget _buildPositiveToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _RadioOption(
            title: 'Positive habit',
            subtitle: 'YES = success (e.g., Did I workout?)',
            icon: Icons.thumb_up_rounded,
            color: AppColors.success,
            isSelected: _isPositive,
            onTap: () => setState(() => _isPositive = true),
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.surfaceVariant),
          const SizedBox(height: 10),
          _RadioOption(
            title: 'Quit bad habit',
            subtitle: 'NO = success (e.g., Did I smoke?)',
            icon: Icons.block_rounded,
            color: AppColors.error,
            isSelected: !_isPositive,
            onTap: () => setState(() => _isPositive = false),
          ),
        ],
      ),
    );
  }

  Widget _buildMinMaxToggle() {
    return Row(
      children: [
        Expanded(
          child: _SelectionCard(
            title: 'At least',
            subtitle: 'Minimum target',
            icon: Icons.arrow_upward_rounded,
            isSelected: _isMinTarget,
            onTap: () => setState(() => _isMinTarget = true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SelectionCard(
            title: 'Less than',
            subtitle: 'Maximum limit',
            icon: Icons.arrow_downward_rounded,
            isSelected: !_isMinTarget,
            onTap: () => setState(() => _isMinTarget = false),
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencySelector() {
    return Row(
      children: [
        _FreqChip(
          label: 'Daily',
          isSelected: _frequency == HabitFrequency.daily,
          onTap: () => setState(() => _frequency = HabitFrequency.daily),
        ),
        const SizedBox(width: 8),
        _FreqChip(
          label: 'Weekly',
          isSelected: _frequency == HabitFrequency.weekly,
          onTap: () => setState(() => _frequency = HabitFrequency.weekly),
        ),
        const SizedBox(width: 8),
        _FreqChip(
          label: 'Custom',
          isSelected: _frequency == HabitFrequency.custom,
          onTap: () => setState(() => _frequency = HabitFrequency.custom),
        ),
      ],
    );
  }

  Widget _buildCustomDaySelector() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Wrap(
      spacing: 8,
      children: List.generate(7, (i) {
        final dayNum = i + 1;
        final isSelected = _customDays.contains(dayNum);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _customDays.remove(dayNum);
              } else {
                _customDays.add(dayNum);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              days[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStartDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _startDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.dark(
                  primary: Theme.of(context).colorScheme.primary,
                  onPrimary: Colors.white,
                  surface: AppColors.surface,
                  onSurface: AppColors.textPrimary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _startDate = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.surfaceVariant,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(_startDate),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    'Tap to change start date',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.edit_calendar_rounded,
              color: AppColors.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconPicker() {
    final icons = AppIcons.habitIcons;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: icons.entries.map((entry) {
        final isSelected = _selectedIcon == entry.key;
        return GestureDetector(
          onTap: () => setState(() => _selectedIcon = entry.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.habitColors[_selectedColorIndex].withOpacity(0.2)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                      color: AppColors.habitColors[_selectedColorIndex],
                      width: 2,
                    )
                  : null,
            ),
            child: Icon(
              entry.value,
              color: isSelected
                  ? AppColors.habitColors[_selectedColorIndex]
                  : AppColors.textTertiary,
              size: 22,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(AppColors.habitColors.length, (i) {
        final isSelected = _selectedColorIndex == i;
        return GestureDetector(
          onTap: () => setState(() => _selectedColorIndex = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.habitColors[i],
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.habitColors[i].withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildReminderPicker() {
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: _reminderTime ?? const TimeOfDay(hour: 8, minute: 0),
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
        if (time != null) {
          setState(() => _reminderTime = time);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _reminderTime != null
                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                : AppColors.surfaceVariant,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _reminderTime != null
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _reminderTime != null
                    ? Icons.alarm_on_rounded
                    : Icons.alarm_add_rounded,
                color: _reminderTime != null
                    ? Theme.of(context).colorScheme.primary
                    : AppColors.textTertiary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _reminderTime != null
                        ? 'Reminder at ${_reminderTime!.format(context)}'
                        : 'Tap to set a daily reminder',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _reminderTime != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                  if (_reminderTime != null)
                    const Text(
                      'Every day',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            if (_reminderTime != null)
              GestureDetector(
                onTap: () => setState(() => _reminderTime = null),
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }


  // ─── Save ────────────────────────────────────────────────────────────────────


  Future<void> _saveHabit() async {
    if (!_formKey.currentState!.validate()) return;

    final habit = widget.existingHabit ?? Habit();
    habit.name = _nameController.text.trim();
    habit.description = _descController.text.trim().isEmpty
        ? null
        : _descController.text.trim();
    habit.type = _type;
    habit.isPositive = _isPositive;
    habit.icon = _selectedIcon;
    habit.color = AppColors.habitColors[_selectedColorIndex].value;
    habit.frequency = _frequency;
    habit.customDays = _customDays;
    habit.createdAt = _startDate;

    if (_type == HabitType.frequency) {
      habit.targetValue = double.tryParse(_targetController.text) ?? 0;
      habit.unit = _unitController.text.trim().isEmpty
          ? null
          : _unitController.text.trim();
      habit.isMinTarget = _isMinTarget;
    }

    if (_isEditing) {
      // If start date moved forward, clean up records before new start date
      final oldStartDate = widget.existingHabit!.createdAt;
      final newStartOnly = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final oldStartOnly = DateTime(oldStartDate.year, oldStartDate.month, oldStartDate.day);

      if (newStartOnly.isAfter(oldStartOnly)) {
        // Confirm with user
        final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Remove old entries?'),
            content: const Text(
              'Moving the start date forward will remove all entries before the new start date. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, remove'),
              ),
            ],
          ),
        );
        if (shouldDelete != true) return;

        // Delete old records
        final recordRepo = ref.read(habitRecordRepositoryProvider);
        await recordRepo.deleteRecordsBeforeDate(habit.id, newStartOnly);
      }

      await ref.read(habitListProvider.notifier).updateHabit(habit);
      await _handleReminders(habit.id, habit.name);

      // Invalidate detail providers so heatmap/stats/trends refresh
      ref.invalidate(habitHeatmapProvider(habit.id));
      ref.invalidate(habitStatsProvider(habit.id));
      ref.invalidate(habitWeeklyTrendProvider(habit.id));
    } else {
      final newId = await ref.read(habitListProvider.notifier).addHabit(habit);
      await _handleReminders(newId, habit.name);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _handleReminders(int habitId, String habitName) async {
    final repo = ref.read(reminderRepositoryProvider);
    final existingReminders = await repo.getForHabit(habitId);

    if (_reminderTime == null) {
      // User removed the reminder or didn't set one
      for (final rem in existingReminders) {
        await repo.delete(rem.id);
        await NotificationService().cancel(rem.id * 100);
      }
    } else {
      // User set a new time or updated existing
      Reminder reminder;
      if (existingReminders.isNotEmpty) {
        reminder = existingReminders.first;
      } else {
        reminder = Reminder()
          ..habitId = habitId
          ..days = [1, 2, 3, 4, 5, 6, 7]
          ..isEnabled = true;
      }

      reminder.timeInMinutes = _reminderTime!.hour * 60 + _reminderTime!.minute;
      final remId = await repo.save(reminder);

      await NotificationService().scheduleDaily(
        id: remId * 100,
        title: habitName,
        body: 'Time to work on your habit! 💪',
        hour: _reminderTime!.hour,
        minute: _reminderTime!.minute,
        payload: '$habitId',
      );
    }
  }
}


// ─── Reusable widgets ────────────────────────────────────────────────────────

class _SelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : AppColors.surfaceVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).colorScheme.primary : AppColors.textTertiary,
              size: 24,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected ? Theme.of(context).colorScheme.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RadioOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? color : AppColors.textTertiary,
                width: 2,
              ),
              color: isSelected ? color : Colors.transparent,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
        ],
      ),
    );
  }
}

class _FreqChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FreqChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

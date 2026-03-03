import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streak_forge/core/theme/app_theme.dart';
import 'package:streak_forge/core/constants/app_icons.dart';
import 'package:streak_forge/core/utils/date_utils.dart';
import 'package:streak_forge/features/habits/data/models/habit.dart';
import 'package:streak_forge/features/habits/data/models/habit_record.dart';
import 'package:streak_forge/features/habits/presentation/providers/habit_providers.dart';
import 'package:streak_forge/features/habits/presentation/screens/create_habit_screen.dart';
import 'package:streak_forge/core/widgets/heatmap_calendar.dart';
import 'package:streak_forge/core/widgets/trend_chart.dart';
import 'package:streak_forge/features/habits/domain/streak_calculator.dart';
import 'package:streak_forge/features/reminders/presentation/screens/reminder_screen.dart';

class HabitDetailScreen extends ConsumerWidget {
  final int habitId;

  const HabitDetailScreen({super.key, required this.habitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitListProvider);
    final statsAsync = ref.watch(habitStatsProvider(habitId));
    final heatmapAsync = ref.watch(habitHeatmapProvider(habitId));

    return habitsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (habits) {
        final habit = habits.where((h) => h.id == habitId).firstOrNull;
        if (habit == null) {
          return const Scaffold(
            body: Center(child: Text('Habit not found')),
          );
        }

        final color = Color(habit.color);

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // ─── App Bar ───
              SliverAppBar(
                expandedHeight: 140,
                pinned: true,
                backgroundColor: AppColors.background,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withOpacity(0.2),
                          AppColors.background,
                        ],
                      ),
                    ),
                  ),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.getIcon(habit.icon),
                          color: color, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          habit.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    color: AppColors.surface,
                    onSelected: (v) => _handleAction(context, ref, v, habit),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded,
                                size: 18, color: AppColors.textSecondary),
                            SizedBox(width: 10),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive_rounded,
                                size: 18, color: AppColors.textSecondary),
                            SizedBox(width: 10),
                            Text('Archive'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded,
                                size: 18, color: AppColors.error),
                            SizedBox(width: 10),
                            Text('Delete',
                                style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // ─── Stats Cards ───
              SliverToBoxAdapter(
                child: statsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Error: $e'),
                  ),
                  data: (stats) => _StatsSection(
                    stats: stats,
                    color: color,
                  ),
                ),
              ),

              // ─── Heatmap ───
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Activity',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.edit_calendar_rounded,
                              color: color,
                              size: 22,
                            ),
                            tooltip: 'Edit past entries',
                            onPressed: () => _showDateEditSheet(context, ref, habit, color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      heatmapAsync.when(
                        loading: () => const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => Text('Error: $e'),
                        data: (data) => HeatmapCalendar(
                          data: data,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Trend Chart ───
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weekly Trend',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.surfaceVariant.withOpacity(0.5),
                            width: 0.5,
                          ),
                        ),
                        child: ref.watch(habitWeeklyTrendProvider(habitId)).when(
                          loading: () => const SizedBox(
                            height: 180,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => Text('Error: \$e'),
                          data: (data) => TrendChart(
                            data: data,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Reminders Button ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _ReminderButton(
                    habitId: habitId,
                    habitName: habit.name,
                    color: color,
                  ),
                ),
              ),

              // ─── Habit Info ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _InfoSection(habit: habit, color: color),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        );
      },
    );
  }

  void _handleAction(
      BuildContext context, WidgetRef ref, String action, Habit habit) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateHabitScreen(existingHabit: habit),
          ),
        );
        break;
      case 'archive':
        ref.read(habitListProvider.notifier).archiveHabit(habit.id);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habit archived')),
        );
        break;
      case 'delete':
        _confirmDelete(context, ref, habit);
        break;
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Habit habit) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Habit?'),
        content: Text(
          'This will permanently delete "${habit.name}" and all its records. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(habitListProvider.notifier).deleteHabit(habit.id);
              Navigator.pop(context); // dialog
              Navigator.pop(context); // detail screen
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showDateEditSheet(
      BuildContext context, WidgetRef ref, Habit habit, Color color) async {
    // 1. Pick a date
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              primary: color,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !context.mounted) return;

    // 2. Get current record for that date
    final recordRepo = ref.read(habitRecordRepositoryProvider);
    final existing = await recordRepo.getRecord(habit.id, picked);
    if (!context.mounted) return;

    // 3. Show bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _DateEditSheet(
          habit: habit,
          date: picked,
          existingRecord: existing,
          color: color,
        );
      },
    );
  }
}

// ─── Date Edit Bottom Sheet ──────────────────────────────────────────────────

class _DateEditSheet extends ConsumerStatefulWidget {
  final Habit habit;
  final DateTime date;
  final HabitRecord? existingRecord;
  final Color color;

  const _DateEditSheet({
    required this.habit,
    required this.date,
    this.existingRecord,
    required this.color,
  });

  @override
  ConsumerState<_DateEditSheet> createState() => _DateEditSheetState();
}

class _DateEditSheetState extends ConsumerState<_DateEditSheet> {
  late bool _isCompleted;
  late double _value;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.existingRecord?.isCompleted ?? false;
    _value = widget.existingRecord?.value ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final dayStr =
        '${widget.date.day}/${widget.date.month}/${widget.date.year}';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Edit entry for $dayStr',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.habit.name,
            style: TextStyle(
              fontSize: 14,
              color: widget.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          if (widget.habit.type == HabitType.yesNo) ...[
            // Yes/No toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildToggleButton('Not Done', !_isCompleted, () {
                  setState(() => _isCompleted = false);
                }),
                const SizedBox(width: 16),
                _buildToggleButton('Done ✓', _isCompleted, () {
                  setState(() => _isCompleted = true);
                }),
              ],
            ),
          ] else ...[
            // Frequency input
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() => _value = (_value - 1).clamp(0, 99999));
                  },
                  icon: Icon(Icons.remove_circle_outline,
                      color: widget.color, size: 32),
                ),
                const SizedBox(width: 16),
                Text(
                  _value.toStringAsFixed(_value == _value.roundToDouble() ? 0 : 1),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (widget.habit.unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    widget.habit.unit!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {
                    setState(() => _value += 1);
                  },
                  icon: Icon(Icons.add_circle_outline,
                      color: widget.color, size: 32),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final recordRepo = ref.read(habitRecordRepositoryProvider);
                if (widget.habit.type == HabitType.yesNo) {
                  // For yes/no, toggle to the desired state
                  final existing =
                      await recordRepo.getRecord(widget.habit.id, widget.date);
                  if (existing == null) {
                    if (_isCompleted) {
                      await recordRepo.toggleCompletion(
                          widget.habit.id, widget.date);
                    }
                  } else if (existing.isCompleted != _isCompleted) {
                    await recordRepo.toggleCompletion(
                        widget.habit.id, widget.date);
                  }
                } else {
                  await recordRepo.updateValue(
                    widget.habit.id,
                    widget.date,
                    _value,
                    isMinTarget: widget.habit.isMinTarget,
                    targetValue: widget.habit.targetValue ?? 0,
                  );
                }

                // Auto-adjust start date
                final habitRepo = ref.read(habitRepositoryProvider);
                final habit = await habitRepo.getById(widget.habit.id);
                if (habit != null) {
                  final dateOnly = DateTime(
                      widget.date.year, widget.date.month, widget.date.day);
                  final createdOnly = DateTime(habit.createdAt.year,
                      habit.createdAt.month, habit.createdAt.day);
                  if (dateOnly.isBefore(createdOnly)) {
                    habit.createdAt = dateOnly;
                    await habitRepo.save(habit);
                  }
                }

                // Invalidate providers to refresh
                ref.invalidate(habitHeatmapProvider(widget.habit.id));
                ref.invalidate(habitStatsProvider(widget.habit.id));
                ref.invalidate(habitWeeklyTrendProvider(widget.habit.id));

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text(
                'Save',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: isActive
              ? widget.color.withOpacity(0.2)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? widget.color : AppColors.surfaceVariant,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isActive ? widget.color : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ─── Stats Section ───────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  final HabitStats stats;
  final Color color;

  const _StatsSection({required this.stats, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main streak card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  color: color,
                  size: 36,
                ),
                const SizedBox(height: 8),
                Text(
                  '${stats.currentStreak}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Day Streak',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Stats grid – responsive Wrap layout
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 20) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      label: 'Best Streak',
                      value: '${stats.bestStreak}',
                      icon: Icons.emoji_events_rounded,
                      iconColor: AppColors.warning,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      label: 'Total Done',
                      value: '${stats.totalCompletions}',
                      icon: Icons.check_circle_rounded,
                      iconColor: AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      label: 'Success',
                      value: '${stats.completionPercentage.toStringAsFixed(0)}%',
                      icon: Icons.pie_chart_rounded,
                      iconColor: AppColors.info,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      label: 'Worst Streak',
                      value: '${stats.worstStreak}',
                      icon: Icons.trending_down_rounded,
                      iconColor: AppColors.error,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      label: 'Longest Break',
                      value: '${stats.longestBreak}',
                      icon: Icons.pause_circle_rounded,
                      iconColor: AppColors.textTertiary,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      label: 'Consistency',
                      value: '${stats.consistencyScore.toStringAsFixed(0)}',
                      icon: Icons.speed_rounded,
                      iconColor: AppColors.accent,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.surfaceVariant.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Section ────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final Habit habit;
  final Color color;

  const _InfoSection({required this.habit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.category_rounded,
            label: 'Type',
            value: habit.type == HabitType.yesNo ? 'Yes / No' : 'Frequency',
          ),
          if (habit.type == HabitType.yesNo)
            _InfoRow(
              icon: habit.isPositive
                  ? Icons.thumb_up_rounded
                  : Icons.block_rounded,
              label: 'Mode',
              value: habit.isPositive ? 'Positive' : 'Quit Bad Habit',
            ),
          if (habit.type == HabitType.frequency) ...[
            _InfoRow(
              icon: Icons.track_changes_rounded,
              label: 'Target',
              value:
                  '${habit.isMinTarget ? "At least" : "Less than"} ${habit.targetValue} ${habit.unit ?? ""}',
            ),
          ],
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            label: 'Created',
            value: habit.createdAt.formatted,
          ),
          _InfoRow(
            icon: Icons.repeat_rounded,
            label: 'Frequency',
            value: habit.frequency == HabitFrequency.daily
                ? 'Daily'
                : habit.frequency == HabitFrequency.weekly
                    ? 'Weekly'
                    : 'Custom',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reminder Button ─────────────────────────────────────────────────────────

class _ReminderButton extends StatelessWidget {
  final int habitId;
  final String habitName;
  final Color color;

  const _ReminderButton({
    required this.habitId,
    required this.habitName,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReminderManagementScreen(
              habitId: habitId,
              habitName: habitName,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.surfaceVariant.withOpacity(0.5),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reminders',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Set up daily reminders for this habit',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

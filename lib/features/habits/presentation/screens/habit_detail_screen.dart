import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streak_forge/core/theme/app_theme.dart';
import 'package:streak_forge/core/constants/app_icons.dart';
import 'package:streak_forge/core/utils/date_utils.dart';
import 'package:streak_forge/features/habits/data/models/habit.dart';
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
                      const Text(
                        'Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
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

          // Stats grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: [
              _StatCard(
                label: 'Best Streak',
                value: '${stats.bestStreak}',
                icon: Icons.emoji_events_rounded,
                iconColor: AppColors.warning,
              ),
              _StatCard(
                label: 'Total Done',
                value: '${stats.totalCompletions}',
                icon: Icons.check_circle_rounded,
                iconColor: AppColors.success,
              ),
              _StatCard(
                label: 'Success',
                value: '${stats.completionPercentage.toStringAsFixed(0)}%',
                icon: Icons.pie_chart_rounded,
                iconColor: AppColors.info,
              ),
              _StatCard(
                label: 'Worst Streak',
                value: '${stats.worstStreak}',
                icon: Icons.trending_down_rounded,
                iconColor: AppColors.error,
              ),
              _StatCard(
                label: 'Longest Break',
                value: '${stats.longestBreak}',
                icon: Icons.pause_circle_rounded,
                iconColor: AppColors.textTertiary,
              ),
              _StatCard(
                label: 'Consistency',
                value: '${stats.consistencyScore.toStringAsFixed(0)}',
                icon: Icons.speed_rounded,
                iconColor: AppColors.accent,
              ),
            ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.surfaceVariant.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
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

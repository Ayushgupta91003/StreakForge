import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streak_forge/core/theme/app_theme.dart';
import 'package:streak_forge/features/habits/data/models/habit.dart';
import 'package:streak_forge/features/habits/data/models/habit_record.dart';
import 'package:streak_forge/features/habits/presentation/providers/habit_providers.dart';
import 'package:streak_forge/features/habits/presentation/screens/create_habit_screen.dart';
import 'package:streak_forge/features/habits/presentation/screens/habit_detail_screen.dart';
import 'package:streak_forge/features/settings/presentation/screens/settings_screen.dart';
import 'package:streak_forge/core/utils/date_utils.dart';
import 'package:streak_forge/core/constants/app_icons.dart';
import 'package:streak_forge/core/constants/motivational_quotes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const _HabitListView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateHabitScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text('New Habit'),
      ),
    );
  }
}


// ─── Habit List View ─────────────────────────────────────────────────────────

class _HabitListView extends ConsumerWidget {
  const _HabitListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitListProvider);
    final recordsAsync = ref.watch(todayRecordsProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          floating: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'StreakForge',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                selectedDate.isToday
                    ? 'Today, ${selectedDate.shortFormatted}'
                    : selectedDate.formatted,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: [
            // Date picker
            IconButton(
              icon: const Icon(Icons.calendar_today_rounded, size: 20),
              onPressed: () => _pickDate(context, ref),
            ),
            // Settings
            IconButton(
              icon: const Icon(Icons.settings_rounded, size: 22),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),

        // Date selector row
        SliverToBoxAdapter(
          child: _DateCarousel(
            selectedDate: selectedDate,
            onDateSelected: (date) {
              ref.read(selectedDateProvider.notifier).state = date;
            },
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // Motivational quote
        SliverToBoxAdapter(
          child: _QuoteBanner(),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // Habit list — split into pending / completed
        habitsAsync.when(
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SliverFillRemaining(
            child: Center(child: Text('Error: $e')),
          ),
          data: (habits) {
            if (habits.isEmpty) {
              return SliverFillRemaining(
                child: _EmptyState(),
              );
            }

            return recordsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e')),
              ),
              data: (records) {
                // Split habits into pending and completed
                final pending = <Habit>[];
                final completed = <Habit>[];
                for (final h in habits) {
                  final rec = records[h.id];
                  if (rec != null && rec.isCompleted) {
                    completed.add(h);
                  } else {
                    pending.add(h);
                  }
                }

                return SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Pending habits (reorderable) ──
                    ...pending.map((h) => _HabitCard(
                          key: ValueKey('pending_${h.id}'),
                          habit: h,
                          record: records[h.id],
                        )),

                    // ── Completed section ──
                    if (completed.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 18, color: AppColors.textTertiary),
                            const SizedBox(width: 6),
                            Text(
                              'Completed (${completed.length})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTertiary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...completed.map((h) => _HabitCard(
                            key: ValueKey('completed_${h.id}'),
                            habit: h,
                            record: records[h.id],
                            isInCompletedSection: true,
                          )),
                    ],

                    const SizedBox(height: 100),
                  ]),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final date = await showDatePicker(
      context: context,
      initialDate: ref.read(selectedDateProvider),
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
    if (date != null) {
      ref.read(selectedDateProvider.notifier).state = date;
    }
  }
}

// ─── Date Carousel ───────────────────────────────────────────────────────────

class _DateCarousel extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _DateCarousel({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<_DateCarousel> createState() => _DateCarouselState();
}

class _DateCarouselState extends State<_DateCarousel> {
  late final ScrollController _scrollController;
  // Large number of past days for "infinite" scrollback
  static const int _totalPastDays = 3650; // ~10 years
  static const double _itemWidth = 56.0; // 48 + 8 margin

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDate(widget.selectedDate, animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant _DateCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.selectedDate.isSameDay(widget.selectedDate)) {
      _scrollToDate(widget.selectedDate, animate: true);
    }
  }

  void _scrollToDate(DateTime date, {bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final daysFromToday = today.difference(target).inDays;
    // todayIndex is at (_totalPastDays), so target is at (_totalPastDays - daysFromToday)
    final targetIndex = _totalPastDays - daysFromToday;
    final offset = (targetIndex * _itemWidth) -
        (MediaQuery.of(context).size.width / 2 - _itemWidth / 2);
    final clampedOffset = offset.clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    if (animate) {
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(clampedOffset);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Items: _totalPastDays past days + today = _totalPastDays + 1 items
    final itemCount = _totalPastDays + 1;

    return SizedBox(
      height: 72,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: itemCount,
        itemExtent: _itemWidth,
        itemBuilder: (context, index) {
          final daysAgo = _totalPastDays - index;
          final date = today.subtract(Duration(days: daysAgo));
          final isSelected = date.isSameDay(widget.selectedDate);
          final isToday = date.isToday;

          return GestureDetector(
            onTap: () => widget.onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              width: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : isToday
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                        : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: isToday && !isSelected
                    ? Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.4), width: 1)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    date.shortDayName.substring(0, 2),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white.withOpacity(0.8)
                          : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Habit Card ──────────────────────────────────────────────────────────────

class _HabitCard extends ConsumerWidget {
  final Habit habit;
  final HabitRecord? record;
  final bool isInCompletedSection;

  const _HabitCard({
    super.key,
    required this.habit,
    this.record,
    this.isInCompletedSection = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(habit.color);
    final isCompleted = record?.isCompleted ?? false;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HabitDetailScreen(habitId: habit.id),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isInCompletedSection
              ? AppColors.surfaceLight.withOpacity(0.5)
              : isCompleted
                  ? color.withOpacity(0.12)
                  : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isInCompletedSection
                ? AppColors.surfaceVariant.withOpacity(0.3)
                : isCompleted
                    ? color.withOpacity(0.3)
                    : AppColors.surfaceVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                AppIcons.getIcon(habit.icon),
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: AppColors.textTertiary,
                    ),
                  ),
                  if (habit.type == HabitType.frequency &&
                      habit.targetValue != null) ...[
                    const SizedBox(height: 6),
                    _FrequencyProgress(
                      value: record?.value ?? 0,
                      target: habit.targetValue!,
                      unit: habit.unit ?? '',
                      color: color,
                      isMinTarget: habit.isMinTarget,
                    ),
                  ],
                  if (habit.description != null &&
                      habit.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      habit.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Action
            if (habit.type == HabitType.yesNo)
              _YesNoToggle(
                isCompleted: isCompleted,
                color: color,
                isPositive: habit.isPositive,
                onTap: () async {
                  final adjusted = await ref.read(todayRecordsProvider.notifier).toggleHabit(habit.id);
                  if (adjusted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📅 Habit start date moved back to match this entry'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
              )
            else
              _FrequencyInput(
                value: record?.value ?? 0,
                color: color,
                onIncrement: () async {
                  final newVal = (record?.value ?? 0) + 1;
                  final adjusted = await ref.read(todayRecordsProvider.notifier).updateFrequencyValue(
                    habit.id,
                    newVal,
                    isMinTarget: habit.isMinTarget,
                    targetValue: habit.targetValue ?? 0,
                  );
                  if (adjusted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📅 Habit start date moved back to match this entry'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
                onDecrement: () async {
                  final newVal = ((record?.value ?? 0) - 1).clamp(0.0, double.maxFinite).toDouble();
                  final adjusted = await ref.read(todayRecordsProvider.notifier).updateFrequencyValue(
                    habit.id,
                    newVal,
                    isMinTarget: habit.isMinTarget,
                    targetValue: habit.targetValue ?? 0,
                  );
                  if (adjusted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📅 Habit start date moved back to match this entry'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Yes/No Toggle ───────────────────────────────────────────────────────────

class _YesNoToggle extends StatelessWidget {
  final bool isCompleted;
  final Color color;
  final bool isPositive;
  final VoidCallback onTap;

  const _YesNoToggle({
    required this.isCompleted,
    required this.color,
    required this.isPositive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isCompleted ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCompleted ? color : AppColors.textTertiary,
            width: 2,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isCompleted
              ? Icon(
                  Icons.check_rounded,
                  key: const ValueKey('check'),
                  color: Colors.white,
                  size: 24,
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ),
    );
  }
}

// ─── Frequency Input ─────────────────────────────────────────────────────────

class _FrequencyInput extends StatelessWidget {
  final double value;
  final Color color;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _FrequencyInput({
    required this.value,
    required this.color,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CounterButton(
          icon: Icons.remove_rounded,
          color: color,
          onTap: onDecrement,
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 36),
          alignment: Alignment.center,
          child: Text(
            value == value.toInt() ? value.toInt().toString() : value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        _CounterButton(
          icon: Icons.add_rounded,
          color: color,
          onTap: onIncrement,
        ),
      ],
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CounterButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ─── Frequency Progress ──────────────────────────────────────────────────────

class _FrequencyProgress extends StatelessWidget {
  final double value;
  final double target;
  final String unit;
  final Color color;
  final bool isMinTarget;

  const _FrequencyProgress({
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
    required this.isMinTarget,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    final displayValue = value == value.toInt()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    final displayTarget = target == target.toInt()
        ? target.toInt().toString()
        : target.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$displayValue / $displayTarget $unit',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No habits yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the + button to forge\nyour first streak!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Motivational Quote Banner ───────────────────────────────────────────────

class _QuoteBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final quote = MotivationalQuotes.getDaily();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.12),
            AppColors.accent.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Text(
            '💡',
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${quote['quote']}"',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '— ${quote['author']}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


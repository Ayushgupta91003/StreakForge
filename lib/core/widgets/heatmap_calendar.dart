import 'package:flutter/material.dart';
import 'package:streak_forge/core/theme/app_theme.dart';

/// GitHub-style heatmap calendar widget with horizontal scrolling.
///
/// Uses a fixed cell size so cells are always readable.
/// Scrollable horizontally, auto-scrolls to show today (right edge).
/// Accepts an optional [habitStartDate] to limit the range.
class HeatmapCalendar extends StatefulWidget {
  final Map<DateTime, double> data;
  final Color color;
  final int months;
  final DateTime? habitStartDate;

  const HeatmapCalendar({
    super.key,
    required this.data,
    required this.color,
    this.months = 12,
    this.habitStartDate,
  });

  @override
  State<HeatmapCalendar> createState() => _HeatmapCalendarState();
}

class _HeatmapCalendarState extends State<HeatmapCalendar> {
  late final ScrollController _scrollController;
  late final ScrollController _monthScrollController;

  static const double _cellSize = 13.0;
  static const double _gap = 2.0;
  static const double _colWidth = _cellSize + _gap;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _monthScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
      if (_monthScrollController.hasClients) {
        _monthScrollController
            .jumpTo(_monthScrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _monthScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Determine start: use habit start date if provided, else N months ago
    DateTime rangeStart;
    if (widget.habitStartDate != null) {
      final hs = widget.habitStartDate!;
      final fallback = DateTime(now.year, now.month - widget.months + 1, 1);
      // Use whichever is earlier
      rangeStart = hs.isBefore(fallback) ? hs : fallback;
    } else {
      rangeStart = DateTime(now.year, now.month - widget.months + 1, 1);
    }
    // Align to Monday
    final alignedStart =
        rangeStart.subtract(Duration(days: (rangeStart.weekday - 1) % 7));

    // Generate all weeks
    final weeks = <List<DateTime?>>[];
    var currentDate = alignedStart;
    while (!currentDate.isAfter(today)) {
      final week = <DateTime?>[];
      for (int d = 0; d < 7; d++) {
        if (currentDate.isAfter(today)) {
          week.add(null);
        } else {
          week.add(currentDate);
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }
      weeks.add(week);
    }

    // Find max value for intensity
    double maxValue = 1;
    for (final v in widget.data.values) {
      if (v > maxValue) maxValue = v;
    }

    // Month/year labels with positions — avoid collisions
    final monthLabels = <String>[];
    final monthPositions = <int>[];
    int? lastMonth;
    int? lastYear;
    for (int w = 0; w < weeks.length; w++) {
      for (final day in weeks[w]) {
        if (day != null && (day.month != lastMonth || day.year != lastYear)) {
          // Skip if too close to previous label (< 4 columns apart)
          if (monthPositions.isNotEmpty &&
              (w - monthPositions.last) < 4) {
            break;
          }
          lastMonth = day.month;
          lastYear = day.year;
          // Show year on Jan or first label
          if (day.month == 1 || monthLabels.isEmpty) {
            monthLabels.add('${_monthName(day.month)} ${day.year}');
          } else {
            monthLabels.add(_monthName(day.month));
          }
          monthPositions.add(w);
          break;
        }
      }
    }

    final gridWidth = weeks.length * _colWidth;
    const dayLabelWidth = 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month labels
        SizedBox(
          height: 16,
          child: Row(
            children: [
              const SizedBox(width: dayLabelWidth),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (_) => true,
                  child: SingleChildScrollView(
                    controller: _monthScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: gridWidth,
                      child: Stack(
                        children: List.generate(monthLabels.length, (i) {
                          return Positioned(
                            left: monthPositions[i] * _colWidth,
                            child: Text(
                              monthLabels[i],
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Heatmap grid
        SizedBox(
          height: 7 * (_cellSize + _gap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day labels
              SizedBox(
                width: dayLabelWidth,
                child: Column(
                  children: [
                    _dayLabel('M'),
                    _dayLabel(''),
                    _dayLabel('W'),
                    _dayLabel(''),
                    _dayLabel('F'),
                    _dayLabel(''),
                    _dayLabel('S'),
                  ],
                ),
              ),
              // Scrollable grid
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (_monthScrollController.hasClients) {
                      _monthScrollController
                          .jumpTo(_scrollController.offset);
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: weeks.map((week) {
                        return SizedBox(
                          width: _colWidth,
                          child: Column(
                            children: week.map((day) {
                              if (day == null) {
                                return SizedBox(
                                  width: _cellSize,
                                  height: _cellSize + _gap,
                                );
                              }

                              final key =
                                  DateTime(day.year, day.month, day.day);
                              final value = widget.data[key] ?? 0;
                              final intensity = maxValue > 0
                                  ? (value / maxValue).clamp(0.0, 1.0)
                                  : 0.0;

                              return Padding(
                                padding: const EdgeInsets.all(_gap / 2),
                                child: Tooltip(
                                  message:
                                      '${day.day}/${day.month}/${day.year} — ${value > 0 ? "✓ ${value > 1 ? value.toStringAsFixed(0) : ""}" : "—"}',
                                  child: Container(
                                    width: _cellSize,
                                    height: _cellSize,
                                    decoration: BoxDecoration(
                                      color: _getCellColor(intensity),
                                      borderRadius:
                                          BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'Less',
              style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
            ),
            const SizedBox(width: 4),
            ...[0.0, 0.25, 0.5, 0.75, 1.0].map((intensity) {
              return Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _getCellColor(intensity),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
            const SizedBox(width: 4),
            const Text(
              'More',
              style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
            ),
          ],
        ),
      ],
    );
  }

  Color _getCellColor(double intensity) {
    if (intensity <= 0) return AppColors.heatmapEmpty;
    if (intensity <= 0.25) return widget.color.withOpacity(0.25);
    if (intensity <= 0.5) return widget.color.withOpacity(0.45);
    if (intensity <= 0.75) return widget.color.withOpacity(0.7);
    return widget.color;
  }

  Widget _dayLabel(String text) {
    return SizedBox(
      height: _cellSize + _gap,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[month - 1];
  }
}

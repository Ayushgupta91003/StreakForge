import 'package:flutter/material.dart';
import 'package:streak_forge/core/theme/app_theme.dart';

/// GitHub-style heatmap calendar widget
class HeatmapCalendar extends StatelessWidget {
  final Map<DateTime, double> data;
  final Color color;
  final int months;

  const HeatmapCalendar({
    super.key,
    required this.data,
    required this.color,
    this.months = 12,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Calculate the start date (beginning of the period, aligned to start of week)
    final startDate = DateTime(now.year, now.month - months + 1, 1);
    // Align to Monday
    final alignedStart = startDate.subtract(
      Duration(days: (startDate.weekday - 1) % 7),
    );

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

    // Find max value for intensity scaling
    double maxValue = 1;
    for (final v in data.values) {
      if (v > maxValue) maxValue = v;
    }

    // Month labels
    final monthLabels = <String>[];
    final monthPositions = <int>[];
    int? lastMonth;
    for (int w = 0; w < weeks.length; w++) {
      for (final day in weeks[w]) {
        if (day != null && day.month != lastMonth) {
          lastMonth = day.month;
          monthLabels.add(_monthName(day.month));
          monthPositions.add(w);
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month labels
        SizedBox(
          height: 16,
          child: Row(
            children: [
              const SizedBox(width: 24), // Space for day labels
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cellWidth = constraints.maxWidth / weeks.length;
                    return Stack(
                      children: List.generate(monthLabels.length, (i) {
                        return Positioned(
                          left: monthPositions[i] * cellWidth,
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Heatmap grid
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day labels
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  const SizedBox(height: 0),
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

            // Grid
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellSize =
                      (constraints.maxWidth / weeks.length).clamp(4.0, 14.0);
                  final gap = (cellSize * 0.15).clamp(1.0, 2.0);

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: weeks.map((week) {
                        return Column(
                          children: week.map((day) {
                            if (day == null) {
                              return SizedBox(
                                width: cellSize,
                                height: cellSize,
                              );
                            }

                            final key = DateTime(day.year, day.month, day.day);
                            final value = data[key] ?? 0;
                            final intensity = maxValue > 0
                                ? (value / maxValue).clamp(0.0, 1.0)
                                : 0.0;

                            return Padding(
                              padding: EdgeInsets.all(gap / 2),
                              child: Tooltip(
                                message:
                                    '${day.day}/${day.month} — ${value > 0 ? "✓" : "—"}',
                                child: Container(
                                  width: cellSize - gap,
                                  height: cellSize - gap,
                                  decoration: BoxDecoration(
                                    color: _getCellColor(intensity),
                                    borderRadius:
                                        BorderRadius.circular(cellSize * 0.2),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
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
    if (intensity <= 0.25) return color.withOpacity(0.25);
    if (intensity <= 0.5) return color.withOpacity(0.45);
    if (intensity <= 0.75) return color.withOpacity(0.7);
    return color;
  }

  Widget _dayLabel(String text) {
    return SizedBox(
      height: 14,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textTertiary,
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

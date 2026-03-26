import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/daily_total_model.dart';
import '../theme/app_theme.dart';
import '../utils/money_calculator.dart';

class WeeklyChart extends StatefulWidget {
  final List<DailyTotalModel> days;

  const WeeklyChart({super.key, required this.days});

  @override
  State<WeeklyChart> createState() => _WeeklyChartState();
}

class _WeeklyChartState extends State<WeeklyChart> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final maxVal = widget.days
        .map((d) => d.totalMoney)
        .fold(0.0, (a, b) => a > b ? a : b);
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return BarChart(
      swapAnimationDuration: Duration.zero,
      BarChartData(
        maxY: maxVal == 0 ? 100 : maxVal * 1.3,
        barTouchData: BarTouchData(
          touchCallback: (event, response) {
            setState(() {
              if (response?.spot != null) {
                _touched = response!.spot!.touchedBarGroupIndex;
              } else {
                _touched = null;
              }
            });
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${MoneyCalculator.rupeeSymbol}${rod.toY.toInt()}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                final idx = value.toInt();
                if (idx < 0 || idx >= widget.days.length) {
                  return const SizedBox();
                }

                final date = DateTime.tryParse(widget.days[idx].date);
                final label = date != null
                    ? labels[date.weekday - 1]
                    : labels[idx % labels.length];

                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: widget.days[idx].date == todayKey
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.divider, strokeWidth: 1),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(widget.days.length, (i) {
          final isToday = widget.days[i].date == todayKey;
          final isTouched = _touched == i;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: widget.days[i].totalMoney,
                color: isToday
                    ? AppColors.primary
                    : isTouched
                        ? AppColors.primary.withOpacity(0.6)
                        : const Color(0xFF444444),
                width: 18,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

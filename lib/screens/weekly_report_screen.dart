import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/daily_total_model.dart';
import '../services/hive_service.dart';
import '../theme/app_theme.dart';
import '../utils/money_calculator.dart';
import '../widgets/weekly_chart.dart';

class WeeklyReportScreen extends StatelessWidget {
  final bool embedded;
  const WeeklyReportScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final days = HiveService.getLast7Days();
    final weekTotal = days.fold(0.0, (s, d) => s + d.totalMoney);

    final timePerApp = <String, int>{};
    final costPerApp = <String, double>{};
    for (final d in days) {
      final apps = HiveService.getAppUsageForDate(d.date);
      for (final a in apps) {
        timePerApp[a.appName] = (timePerApp[a.appName] ?? 0) + a.durationMinutes;
        costPerApp[a.appName] = (costPerApp[a.appName] ?? 0.0) + a.moneyCost;
      }
    }

    String biggestApp = 'None';
    int biggestMinutes = 0;
    double biggestCost = 0;
    
    timePerApp.forEach((app, minutes) {
      if (minutes > biggestMinutes) {
        biggestMinutes = minutes;
        biggestApp = app;
        biggestCost = costPerApp[app] ?? 0.0;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: embedded
          ? null
          : AppBar(
              title: Text('Your Week in ${MoneyCalculator.rupeeSymbol}'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
      body: SafeArea(
        top: embedded,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, embedded ? 16 : 0, 16, 16),
          children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total wasted this week',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  MoneyCalculator.formatRupees(weekTotal),
                  style: textTheme.displaySmall?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 220,
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: WeeklyChart(days: days),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your Biggest Time Thief',
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  biggestApp,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${MoneyCalculator.formatDuration(biggestMinutes)} this week | ${MoneyCalculator.formatRupees(biggestCost)} wasted',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share My Report'),
              onPressed: () => _share(weekTotal, days),
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _share(double weekTotal, List<DailyTotalModel> days) {
    final allApps = <String, double>{};
    for (final day in days) {
      final apps = HiveService.getAppUsageForDate(day.date);
      for (final app in apps) {
        allApps[app.appName] = (allApps[app.appName] ?? 0) + app.moneyCost;
      }
    }

    final sorted = allApps.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted
        .take(3)
        .map((entry) => '- ${entry.key}: ${MoneyCalculator.formatRupees(entry.value)}')
        .join('\n');

    final summary = top3.isEmpty ? '- No tracked apps this week' : top3;
    final text = '''
ScrollToll Weekly Report

I wasted ${MoneyCalculator.formatRupees(weekTotal)} this week on my phone.

Top apps:
$summary

Track yours -> ScrollToll
''';
    Share.share(text);
  }
}

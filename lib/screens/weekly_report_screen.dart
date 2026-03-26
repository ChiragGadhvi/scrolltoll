import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:device_apps/device_apps.dart';
import 'dart:typed_data';

import '../models/daily_total_model.dart';
import '../services/hive_service.dart';
import '../theme/app_theme.dart';
import '../utils/money_calculator.dart';
import '../widgets/weekly_chart.dart';

class WeeklyReportScreen extends StatefulWidget {
  final bool embedded;
  const WeeklyReportScreen({super.key, this.embedded = false});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  List<DailyTotalModel> _days = [];
  double _weekTotal = 0;
  int _totalWeekMinutes = 0;
  double _avgDaily = 0;
  
  List<Map<String, dynamic>> _top5Apps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final days = HiveService.getLast7Days();
    final weekTotal = days.fold(0.0, (s, d) => s + d.totalMoney);
    final totalWeekMinutes = days.fold(0, (s, d) => s + d.totalMinutes);
    final avgDaily = weekTotal / 7;

    final timePerPkg = <String, int>{};
    final costPerPkg = <String, double>{};
    final namePerPkg = <String, String>{};

    for (final d in days) {
      final apps = HiveService.getAppUsageForDate(d.date);
      for (final a in apps) {
        timePerPkg[a.packageName] = (timePerPkg[a.packageName] ?? 0) + a.durationMinutes;
        costPerPkg[a.packageName] = (costPerPkg[a.packageName] ?? 0.0) + a.moneyCost;
        if (a.appName.isNotEmpty) namePerPkg[a.packageName] = a.appName;
      }
    }

    final sortedPkgs = timePerPkg.keys.toList()
      ..sort((a, b) => timePerPkg[b]!.compareTo(timePerPkg[a]!));
    
    final top5 = sortedPkgs.take(5).toList();
    final top5Data = <Map<String, dynamic>>[];

    for (final pkg in top5) {
      Uint8List? icon;
      try {
        final app = await DeviceApps.getApp(pkg, true);
        if (app is ApplicationWithIcon) {
          icon = app.icon;
        }
      } catch (_) {}

      top5Data.add({
        'name': namePerPkg[pkg] ?? pkg,
        'minutes': timePerPkg[pkg] ?? 0,
        'cost': costPerPkg[pkg] ?? 0.0,
        'icon': icon,
      });
    }

    if (mounted) {
      setState(() {
        _days = days;
        _weekTotal = weekTotal;
        _totalWeekMinutes = totalWeekMinutes;
        _avgDaily = avgDaily;
        _top5Apps = top5Data;
        _isLoading = false;
      });
    }
  }

  void _share() async {
    try {
      await Share.share(
        'Here is my Weekly ScrollToll Report!\n'
        'I wasted ${MoneyCalculator.formatRupees(_weekTotal)} this week scrolling.\n'
        'Get off your phone! #ScrollToll',
      );
    } catch (e) {
      debugPrint('Share error: \$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text('Your Week in ${MoneyCalculator.rupeeSymbol}'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
      body: SafeArea(
        top: widget.embedded,
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: EdgeInsets.fromLTRB(16, widget.embedded ? 16 : 0, 16, 16),
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
                          MoneyCalculator.formatRupees(_weekTotal),
                          style: textTheme.displaySmall?.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _StatBox(
                                label: 'Time Wasted',
                                value: MoneyCalculator.formatDuration(_totalWeekMinutes),
                                color: AppColors.warning,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatBox(
                                label: 'Avg. Daily Toll',
                                value: MoneyCalculator.formatRupees(_avgDaily),
                                color: AppColors.safe,
                              ),
                            ),
                          ],
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
                    child: WeeklyChart(days: _days),
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
                              'Your Top 5 Time Thieves',
                              style: textTheme.titleSmall?.copyWith(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_top5Apps.isEmpty)
                          Text(
                            'No tracked apps this week',
                            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                          )
                        else
                          ..._top5Apps.map((app) {
                            final icon = app['icon'] as Uint8List?;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  if (icon != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(icon, width: 36, height: 36, fit: BoxFit.cover),
                                    )
                                  else
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.divider,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          (app['name'] as String).isNotEmpty ? (app['name'] as String)[0].toUpperCase() : '?',
                                          style: textTheme.titleSmall?.copyWith(color: AppColors.primary),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          app['name'] as String,
                                          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          MoneyCalculator.formatDuration(app['minutes'] as int),
                                          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    MoneyCalculator.formatRupees(app['cost'] as double),
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share My Report'),
                      onPressed: _share,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

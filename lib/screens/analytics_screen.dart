import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:device_apps/device_apps.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';

import '../models/daily_total_model.dart';
import '../models/app_usage_model.dart';
import '../services/hive_service.dart';
import '../services/usage_stats_service.dart';
import '../theme/app_theme.dart';
import '../utils/money_calculator.dart';
import '../widgets/weekly_chart.dart';
import '../widgets/app_usage_tile.dart';
import '../widgets/time_value_jar.dart';

enum AnalyticsView { daily, weekly }

class AnalyticsScreen extends StatefulWidget {
  final bool embedded;
  const AnalyticsScreen({super.key, this.embedded = false});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsView _currentView = AnalyticsView.weekly;
  List<DailyTotalModel> _weekDays = [];
  double _totalCost = 0;
  int _totalMinutes = 0;
  double _avgDaily = 0;
  
  List<AppUsageModel> _apps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    if (_currentView == AnalyticsView.weekly) {
      final days = HiveService.getLast7Days();
      final weekTotal = days.fold(0.0, (s, d) => s + d.totalMoney);
      final totalWeekMinutes = days.fold(0, (s, d) => s + d.totalMinutes);
      
      final timePerPkg = <String, int>{};
      final costPerPkg = <String, double>{};
      final namePerPkg = <String, String>{};

      for (final d in days) {
        final dayApps = HiveService.getAppUsageForDate(d.date);
        for (final a in dayApps) {
          timePerPkg[a.packageName] = (timePerPkg[a.packageName] ?? 0) + a.durationMinutes;
          costPerPkg[a.packageName] = (costPerPkg[a.packageName] ?? 0.0) + a.moneyCost;
          if (a.appName.isNotEmpty) namePerPkg[a.packageName] = a.appName;
        }
      }

      final sortedPkgs = timePerPkg.keys.toList()
        ..sort((a, b) => timePerPkg[b]!.compareTo(timePerPkg[a]!));
      
      final appsList = sortedPkgs.map((pkg) => AppUsageModel(
        appName: namePerPkg[pkg] ?? pkg,
        packageName: pkg,
        durationMinutes: timePerPkg[pkg] ?? 0,
        moneyCost: costPerPkg[pkg] ?? 0.0,
      )).toList();

      if (mounted) {
        setState(() {
          _weekDays = days.reversed.toList(); // Newest first
          _totalCost = weekTotal;
          _totalMinutes = totalWeekMinutes;
          _avgDaily = weekTotal / 7;
          _apps = appsList;
          _isLoading = false;
        });
      }
    } else {
      // Daily view
      final dailyApps = await UsageStatsService.getTodayUsage();
      final todayCost = dailyApps.fold(0.0, (s, a) => s + a.moneyCost);
      final todayMinutes = dailyApps.fold(0, (s, a) => s + a.durationMinutes);

      if (mounted) {
        setState(() {
          _totalCost = todayCost;
          _totalMinutes = todayMinutes;
          _avgDaily = todayCost; 
          _apps = dailyApps;
          _isLoading = false;
        });
      }
    }
  }

  void _share() async {
    final period = _currentView == AnalyticsView.daily ? 'Today' : 'this Week';
    try {
      await Share.share(
        'Here is my ScrollToll Analytics for $period!\n'
        'I wasted ${MoneyCalculator.formatRupees(_totalCost)} scrolling.\n'
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
              title: const Text('Analytics'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
      body: SafeArea(
        top: widget.embedded,
        child: Column(
          children: [
            // Toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ToggleButton(
                        label: 'Today',
                        active: _currentView == AnalyticsView.daily,
                        onTap: () {
                          if (_currentView != AnalyticsView.daily) {
                            setState(() => _currentView = AnalyticsView.daily);
                            _loadData();
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: _ToggleButton(
                        label: 'History',
                        active: _currentView == AnalyticsView.weekly,
                        onTap: () {
                          if (_currentView != AnalyticsView.weekly) {
                            setState(() => _currentView = AnalyticsView.weekly);
                            _loadData();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Expanded(
              child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        if (_currentView == AnalyticsView.daily) ...[
                          // Jar on Today's View
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: TimeValueJar(
                              percentageRemaining: (1.0 - (_totalCost / HiveService.dailyBudget)).clamp(0.0, 1.0),
                              size: 140,
                            ),
                          ),
                        ],

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
                                _currentView == AnalyticsView.daily 
                                    ? 'Total wasted today' 
                                    : 'Total wasted last 7 days',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                MoneyCalculator.formatRupees(_totalCost),
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
                                      label: 'Time spent',
                                      value: MoneyCalculator.formatDuration(_totalMinutes),
                                      color: AppColors.warning,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatBox(
                                      label: _currentView == AnalyticsView.daily ? 'Remaining Budget' : 'Avg. Daily Toll',
                                      value: _currentView == AnalyticsView.daily 
                                          ? MoneyCalculator.formatRupees((HiveService.dailyBudget - _totalCost).clamp(0.0, double.infinity))
                                          : MoneyCalculator.formatRupees(_avgDaily),
                                      color: AppColors.safe,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        if (_currentView == AnalyticsView.weekly) ...[
                          const SizedBox(height: 24),
                          Text(
                            "Daywise Savings",
                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          ..._weekDays.map((day) {
                            final savings = HiveService.dailyBudget - day.totalMoney;
                            final percent = (1.0 - (day.totalMoney / HiveService.dailyBudget)).clamp(0.0, 1.0);
                            final isToday = day.date == HiveService.todayKey;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: isToday ? Border.all(color: AppColors.primary.withOpacity(0.5)) : null,
                              ),
                              child: Row(
                                children: [
                                  TimeValueJar(
                                    percentageRemaining: percent,
                                    size: 44,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatDateLabel(day.date),
                                          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        Text(
                                          MoneyCalculator.formatDuration(day.totalMinutes),
                                          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        savings >= 0 ? 'Saved' : 'Exceeded',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: savings >= 0 ? AppColors.safe : AppColors.danger,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        MoneyCalculator.formatRupees(savings.abs()),
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: savings >= 0 ? AppColors.safe : AppColors.danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],

                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(
                              _currentView == AnalyticsView.daily ? Icons.today_rounded : Icons.bar_chart_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _currentView == AnalyticsView.daily ? 'Today\'s Breakdown' : 'App Breakdown (Weekly)',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        if (_apps.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'No usage tracked',
                                style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        else
                          ..._apps.map((app) => AppUsageTile(app: app)),
                        
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share Report'),
                            onPressed: _share,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateLabel(String dateKey) {
    if (dateKey == HiveService.todayKey) return 'Today';
    try {
      final dt = DateTime.parse(dateKey);
      return DateFormat('EEE, MMM d').format(dt);
    } catch (_) {
      return dateKey;
    }
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
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

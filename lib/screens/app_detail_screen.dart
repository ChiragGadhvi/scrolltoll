import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';

import '../services/hive_service.dart';
import '../services/usage_stats_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/rotto_character.dart';
import '../utils/rotto_score.dart';
import '../widgets/rotto_coin_chart.dart';
import '../widgets/ui_kit.dart';

/// Per-app detail: today's total, this app's recent history, and how it sits
/// against the rest of your tracked time.
///
/// Reads the same `app_brainfog_usage` records Home already writes, so opening
/// this screen never triggers a usage query of its own.
class AppDetailScreen extends StatefulWidget {
  final String packageName;
  final String appName;

  /// Today's minutes as Home already measured them, so the header matches the
  /// list the user tapped from.
  final int todayMinutes;

  const AppDetailScreen({
    super.key,
    required this.packageName,
    required this.appName,
    required this.todayMinutes,
  });

  @override
  State<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends State<AppDetailScreen> {
  /// This app's minutes per day, oldest first.
  List<DayValue> _history = [];

  /// Every tracked app's minutes over the same window, for the share figure.
  int _allAppsWeekMinutes = 0;
  int _previousWeekMinutes = 0;
  bool _tracked = true;

  /// Read from events rather than the daily totals, so it only covers the week
  /// Android still holds detail for.
  AppSessionStats? _sessions;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final stats = await UsageStatsService.sessionStatsFor(widget.packageName);
    if (mounted) setState(() => _sessions = stats);
  }

  void _load() {
    int minutesFor(String date) => HiveService.getAppBrainfogUsageForDate(date)
        .where((a) => a.packageName == widget.packageName)
        .fold(0, (sum, a) => sum + a.minutes);

    final days = HiveService.getLastNDays(14);
    _history = [
      for (final d in days) (date: d.date, minutes: minutesFor(d.date)),
    ];

    final week = HiveService.getLast7Days();
    _allAppsWeekMinutes = week.fold(0, (s, d) => s + d.totalMinutes);
    _previousWeekMinutes = HiveService.getPrevious7Days().fold(
      0,
      (s, d) => s + minutesFor(d.date),
    );
    _tracked = HiveService.trackedApps.contains(widget.packageName);
  }

  /// This app's own total over the last 7 days.
  int get _weekMinutes {
    final recent = _history.length <= 7
        ? _history
        : _history.sublist(_history.length - 7);
    return recent.fold(0, (sum, d) => sum + d.minutes);
  }

  List<DayValue> get _daysWithTime =>
      _history.where((d) => d.minutes > 0).toList();

  Future<void> _openApp() async {
    await DeviceApps.openApp(widget.packageName);
  }

  void _toggleTracking() {
    final apps = HiveService.trackedApps.toList();
    if (_tracked) {
      apps.remove(widget.packageName);
    } else {
      apps.add(widget.packageName);
    }
    // Writing this bumps trackedAppsRevision, so Home reloads behind us.
    HiveService.trackedApps = apps;
    setState(() => _tracked = !_tracked);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = RottoCharacter.colorFor(
      RottoScore(widget.todayMinutes).state,
    );
    final withTime = _daysWithTime;
    final busiest = withTime.isEmpty
        ? null
        : withTime.reduce((a, b) => b.minutes > a.minutes ? b : a);
    final weekMinutes = _weekMinutes;
    final share = _allAppsWeekMinutes == 0
        ? 0
        : (weekMinutes / _allAppsWeekMinutes * 100).round();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.appName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _header(textTheme, color),
          const SizedBox(height: 10),
          MetricStrip(
            metrics: [
              Metric(label: 'This week', value: formatDuration(weekMinutes)),
              Metric(
                label: 'Daily average',
                value: formatDuration(
                  withTime.isEmpty
                      ? 0
                      : (weekMinutes / (withTime.length.clamp(1, 7))).round(),
                ),
              ),
              Metric(
                label: 'Of your total',
                value: _allAppsWeekMinutes == 0 ? '—' : '$share%',
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: SectionHeading(
              title: 'Recent days',
              subtitle: 'Tap a day to read its total',
            ),
          ),
          if (withTime.isEmpty)
            const RottoEmptyState(
              title: 'No history yet',
              message:
                  'Rotto has not recorded any time in this app yet. It shows '
                  'up here once you use it.',
            )
          else
            SoftCard(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
              child: RottoCoinChart(days: _history, isPerApp: true),
            ),
          const SizedBox(height: 26),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: SectionHeading(
              title: 'How you use it',
              subtitle: 'Last 7 days',
            ),
          ),
          _HowYouUseIt(stats: _sessions),
          const SizedBox(height: 26),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: SectionHeading(title: 'About this app'),
          ),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (busiest != null) ...[
                  _InfoRow(
                    icon: Icons.trending_up_rounded,
                    iconColor: AppColors.warning,
                    label: 'Busiest day',
                    value:
                        '${_weekdayName(busiest.date)} · '
                        '${formatDuration(busiest.minutes)}',
                  ),
                  const Divider(),
                ],
                _InfoRow(
                  icon: Icons.history_rounded,
                  iconColor: AppColors.primary,
                  label: 'Previous 7 days',
                  value: _previousWeekMinutes == 0
                      ? 'No record'
                      : formatDuration(_previousWeekMinutes),
                  trailing: _previousWeekMinutes == 0
                      ? null
                      : TrendPill(
                          percent:
                              ((weekMinutes - _previousWeekMinutes) /
                                      _previousWeekMinutes *
                                      100)
                                  .round(),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openApp,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open app'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDeep,
                    side: BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _toggleTracking,
                  icon: Icon(
                    _tracked ? Icons.visibility_off_rounded : Icons.add_rounded,
                    size: 18,
                  ),
                  label: Text(_tracked ? 'Stop tracking' : 'Track this'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _tracked
                        ? AppColors.danger
                        : AppColors.safe,
                    side: BorderSide(
                      color: (_tracked ? AppColors.danger : AppColors.safe)
                          .withValues(alpha: 0.35),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Rotto only measures. It never blocks or closes an app.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(TextTheme textTheme, Color color) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          AppIconAvatar(
            packageName: widget.packageName,
            appName: widget.appName,
            size: 54,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  formatDuration(widget.todayMinutes),
                  style: textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Today", or the day's full weekday name via the shared formatter — the
  /// "Today" override is specific to this row, not part of [weekdayName]
  /// itself.
  String _weekdayName(String dateKey) =>
      dateKey == HiveService.todayKey ? 'Today' : weekdayName(dateKey);
}

/// Session-level habits: how often it is opened, the longest single stretch,
/// and which part of the day it gets reached for.
class _HowYouUseIt extends StatelessWidget {
  final AppSessionStats? stats;

  const _HowYouUseIt({required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;

    if (s == null) {
      return const SoftCard(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: RottoLoader(size: 74)),
      );
    }

    if (s.opens == 0) {
      return SoftCard(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Center(
          child: Text(
            'No sessions recorded in the last 7 days.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
        ),
      );
    }

    final avgMs = (s.totalMs / s.opens).round();

    return Column(
      children: [
        MetricStrip(
          metrics: [
            Metric(label: 'Times opened', value: '${s.opens}'),
            Metric(
              label: 'Longest stretch',
              value: formatDuration((s.longestMs / 60000).round()),
            ),
            Metric(
              label: 'Typical visit',
              value: avgMs < 60000
                  // Under a minute would round to "0m", which reads as broken.
                  ? '${(avgMs / 1000).round()}s'
                  : formatDuration((avgMs / 60000).round()),
            ),
          ],
        ),
      ],
    );
  }
}

/// One labelled fact about the app.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

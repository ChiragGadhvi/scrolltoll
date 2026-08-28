import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_brainfog_stats_model.dart';
import '../models/daily_brainfog_stats_model.dart';
import '../services/hive_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/rotto_character.dart';
import '../utils/rotto_score.dart';
import '../widgets/app_brainfog_tile.dart';
import '../widgets/rotto_coin_calendar.dart';
import '../widgets/rotto_coin_chart.dart';
import '../widgets/ui_kit.dart';

/// Which period Insights is showing.
enum InsightsRange { today, week, month }

/// Insights: today, or the last 7 days — the total, how it compares with the
/// period before it, and the apps that filled it.
///
/// Reads only from Hive; Home owns querying Android usage stats.
class AnalyticsScreen extends StatefulWidget {
  final bool embedded;
  const AnalyticsScreen({super.key, this.embedded = false});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  InsightsRange _range = InsightsRange.today;

  List<DailyBrainfogStats> _weekDaysOldestFirst = [];
  List<DailyBrainfogStats> _monthDaysOldestFirst = [];
  List<AppBrainfogStats> _weekApps = [];
  List<AppBrainfogStats> _todayApps = [];

  /// date key -> the app that took the most of that day.
  Map<String, DayTopApp> _topAppByDate = {};
  int _weekMinutes = 0;
  int _previousWeekMinutes = 0;
  int _todayMinutes = 0;
  int _yesterdayMinutes = 0;

  @override
  void initState() {
    super.initState();
    // This screen is built inside HomeScreen's IndexedStack, before Home's
    // first async read has written anything. Without this listener it showed an
    // empty week until the app was restarted.
    HiveService.statsRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    HiveService.statsRevision.removeListener(_load);
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    final days = HiveService.getLast7Days();

    final minutesPerPkg = <String, int>{};
    final namePerPkg = <String, String>{};
    for (final d in days) {
      for (final a in HiveService.getAppBrainfogUsageForDate(d.date)) {
        minutesPerPkg[a.packageName] =
            (minutesPerPkg[a.packageName] ?? 0) + a.minutes;
        if (a.appName.isNotEmpty) namePerPkg[a.packageName] = a.appName;
      }
    }
    final weekApps =
        minutesPerPkg.entries
            .map(
              (e) => AppBrainfogStats(
                appName: namePerPkg[e.key] ?? e.key,
                packageName: e.key,
                minutes: e.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.minutes.compareTo(a.minutes));

    final todayApps = HiveService.getAppBrainfogUsageForDate(
      HiveService.todayKey,
    )..sort((a, b) => b.minutes.compareTo(a.minutes));

    // Per-day "most used app", so tapping a coin can name it. Widened to 30
    // days so the Month chart's bubbles work too.
    final monthDays = HiveService.getLastNDays(30);
    final topByDate = <String, DayTopApp>{};
    for (final d in monthDays) {
      final apps = HiveService.getAppBrainfogUsageForDate(d.date);
      if (apps.isEmpty) continue;
      final top = apps.reduce((a, b) => b.minutes > a.minutes ? b : a);
      if (top.minutes <= 0) continue;
      topByDate[d.date] = (
        appName: top.appName,
        packageName: top.packageName,
        minutes: top.minutes,
      );
    }

    setState(() {
      _weekDaysOldestFirst = days;
      _monthDaysOldestFirst = monthDays;
      _topAppByDate = topByDate;
      _weekMinutes = days.fold(0, (s, d) => s + d.totalMinutes);
      _previousWeekMinutes = HiveService.getPrevious7Days().fold(
        0,
        (s, d) => s + d.totalMinutes,
      );
      _weekApps = weekApps;
      _todayApps = todayApps;
      // getLast7Days() is oldest first, so today is last and yesterday is the
      // one before it.
      _todayMinutes = days.isEmpty ? 0 : days.last.totalMinutes;
      _yesterdayMinutes = days.length < 2
          ? 0
          : days[days.length - 2].totalMinutes;
    });
  }

  int get _avgDailyMinutes => (_weekMinutes / 7).round();

  /// Days with any recorded time, so "busiest" and "quietest" ignore the zero
  /// padding Hive returns for days that were never recorded.
  List<DailyBrainfogStats> get _daysWithTime =>
      _weekDaysOldestFirst.where((d) => d.totalMinutes > 0).toList();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.embedded ? null : AppBar(title: const Text('Insights')),
      body: SafeArea(
        top: widget.embedded,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, widget.embedded ? 18 : 8, 16, 28),
          children: [
            if (widget.embedded)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 16),
                child: Text(
                  'Insights',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            _RangeSelector(
              range: _range,
              onChanged: (r) => setState(() => _range = r),
            ),
            const SizedBox(height: 16),
            ...switch (_range) {
              InsightsRange.today => _todayView(textTheme),
              InsightsRange.week => _weekView(textTheme),
              InsightsRange.month => _monthView(textTheme),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _todayView(TextTheme textTheme) {
    final level = RottoScore(_todayMinutes);
    final topMinutes = _todayApps.isEmpty ? 0 : _todayApps.first.minutes;

    return [
      _TotalCard(
        label: DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase(),
        minutes: _todayMinutes,
        // Nothing honest to compare against until yesterday has data.
        trendPercent: _yesterdayMinutes > 0
            ? ((_todayMinutes - _yesterdayMinutes) / _yesterdayMinutes * 100)
                  .round()
            : null,
        trendCaption: 'vs yesterday',
        character: level,
        footer: _MoodLine(level: level),
      ),
      const SizedBox(height: 10),
      MetricStrip(
        metrics: [
          Metric(
            label: 'Rotto score',
            value: '${level.score}',
            valueColor: RottoCharacter.colorFor(level.state),
          ),
          Metric(
            label: 'Yesterday',
            value: _yesterdayMinutes == 0
                ? '—'
                : formatDuration(_yesterdayMinutes),
          ),
        ],
      ),
      if (_todayApps.isNotEmpty) ...[
        const SizedBox(height: 10),
        _AppCircles(apps: _todayApps),
      ],
      const SizedBox(height: 26),
      const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 12),
        child: SectionHeading(
          title: 'Apps today',
          subtitle: 'Tap an app for its own history',
        ),
      ),
      if (_todayApps.isEmpty)
        const RottoEmptyState(
          title: 'Nothing tracked yet today',
          message: 'Your tracked apps will show up here as you use them.',
        )
      else
        ..._todayApps.asMap().entries.map(
          (e) => AppBrainfogTile(
            app: e.value,
            rank: e.key + 1,
            shareOfMax: topMinutes == 0 ? 0 : e.value.minutes / topMinutes,
          ),
        ),
    ];
  }

  List<Widget> _weekView(TextTheme textTheme) {
    final withTime = _daysWithTime;
    final busiest = withTime.isEmpty
        ? null
        : withTime.reduce((a, b) => b.totalMinutes > a.totalMinutes ? b : a);
    final quietest = withTime.isEmpty
        ? null
        : withTime.reduce((a, b) => b.totalMinutes < a.totalMinutes ? b : a);
    final topMinutes = _weekApps.isEmpty ? 0 : _weekApps.first.minutes;

    return [
      _TotalCard(
        label: 'LAST 7 DAYS · ${_weekRangeLabel().toUpperCase()}',
        minutes: _weekMinutes,
        trendPercent: _previousWeekMinutes > 0
            ? ((_weekMinutes - _previousWeekMinutes) /
                      _previousWeekMinutes *
                      100)
                  .round()
            : null,
        trendCaption: 'vs previous 7 days',
        character: RottoScore(_avgDailyMinutes),
      ),
      const SizedBox(height: 10),
      MetricStrip(
        metrics: [
          Metric(
            label: 'Daily average',
            value: formatDuration(_avgDailyMinutes),
          ),
          Metric(
            label: busiest == null
                ? 'Busiest day'
                : 'Busiest · ${weekdayName(busiest.date, short: true)}',
            value: busiest == null ? '—' : formatDuration(busiest.totalMinutes),
          ),
          Metric(
            label: quietest == null
                ? 'Quietest day'
                : 'Quietest · ${weekdayName(quietest.date, short: true)}',
            value: quietest == null
                ? '—'
                : formatDuration(quietest.totalMinutes),
          ),
        ],
      ),
      const SizedBox(height: 10),
      SoftCard(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
        child: RottoCoinChart(
          days: _asDayValues(_weekDaysOldestFirst),
          topApps: _topAppByDate,
        ),
      ),
      const SizedBox(height: 26),
      const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 12),
        child: SectionHeading(
          title: 'Apps this week',
          subtitle: 'Tap an app for its own history',
        ),
      ),
      if (_weekApps.isEmpty)
        const RottoEmptyState(
          title: 'No usage recorded yet',
          message:
              'Once Rotto has a day or two of data, your week shows up here.',
        )
      else
        ..._weekApps.asMap().entries.map(
          (e) => AppBrainfogTile(
            app: e.value,
            rank: e.key + 1,
            shareOfMax: topMinutes == 0 ? 0 : e.value.minutes / topMinutes,
          ),
        ),
    ];
  }

  List<Widget> _monthView(TextTheme textTheme) {
    final withTime = _monthDaysOldestFirst
        .where((d) => d.totalMinutes > 0)
        .toList();
    final monthMinutes = _monthDaysOldestFirst.fold(
      0,
      (s, d) => s + d.totalMinutes,
    );
    // Average over days that actually have data, not over a fixed 30 — a fresh
    // install would otherwise report a flatteringly low daily average.
    final avg = withTime.isEmpty ? 0 : (monthMinutes / withTime.length).round();
    final busiest = withTime.isEmpty
        ? null
        : withTime.reduce((a, b) => b.totalMinutes > a.totalMinutes ? b : a);

    return [
      _TotalCard(
        label: 'LAST 30 DAYS',
        minutes: monthMinutes,
        trendPercent: null,
        trendCaption: '',
        character: RottoScore(avg),
      ),
      const SizedBox(height: 10),
      MetricStrip(
        metrics: [
          Metric(label: 'Days tracked', value: '${withTime.length}'),
          Metric(label: 'Daily average', value: formatDuration(avg)),
          Metric(
            label: 'Busiest day',
            value: busiest == null ? '—' : formatDuration(busiest.totalMinutes),
          ),
        ],
      ),
      const SizedBox(height: 10),
      SoftCard(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        child: RottoCoinCalendar(
          days: _asDayValues(_monthDaysOldestFirst),
          topApps: _topAppByDate,
        ),
      ),
    ];
  }

  static List<DayValue> _asDayValues(List<DailyBrainfogStats> days) => [
    for (final d in days) (date: d.date, minutes: d.totalMinutes),
  ];

  String _weekRangeLabel() {
    if (_weekDaysOldestFirst.isEmpty) return '';
    try {
      final start = DateTime.parse(_weekDaysOldestFirst.first.date);
      final end = DateTime.parse(_weekDaysOldestFirst.last.date);
      return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(end)}';
    } catch (_) {
      return '';
    }
  }
}

/// Today / This week switch.
class _RangeSelector extends StatelessWidget {
  final InsightsRange range;
  final ValueChanged<InsightsRange> onChanged;

  const _RangeSelector({required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(15),
      ),
      child: SegmentedButton<InsightsRange>(
        segments: const [
          ButtonSegment(value: InsightsRange.today, label: Text('Today')),
          ButtonSegment(value: InsightsRange.week, label: Text('Week')),
          ButtonSegment(value: InsightsRange.month, label: Text('Month')),
        ],
        selected: {range},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

/// The period's headline figure, with an optional change against the period
/// before it.
class _TotalCard extends StatelessWidget {
  final String label;
  final int minutes;
  final int? trendPercent;
  final String trendCaption;

  /// Whose mood decides which Rotto pose sits beside the figure. Null hides him.
  final RottoScore? character;
  final Widget? footer;

  const _TotalCard({
    required this.label,
    required this.minutes,
    required this.trendPercent,
    required this.trendCaption,
    this.character,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trend = trendPercent;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatDuration(minutes),
                              maxLines: 1,
                              style: textTheme.displaySmall?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                letterSpacing: -1.4,
                                fontFeatures: tabularFigures,
                              ),
                            ),
                          ),
                        ),
                        if (trend != null) ...[
                          const SizedBox(width: 10),
                          TrendPill(percent: trend),
                        ],
                      ],
                    ),
                    if (trend != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          trendCaption,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Rotto keeps the numbers company: the period's own mood, so the
              // card reads as his reaction rather than a bare statistic.
              if (character != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Image.asset(
                    RottoCharacter.assetFor(character!.state),
                    height: 88,
                    filterQuality: FilterQuality.high,
                  ),
                ),
            ],
          ),
          if (footer != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(),
            ),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// The apps used today, as a row of circular icons.
///
/// A count told you how many; this tells you which, in the time it takes to
/// glance at it.
class _AppCircles extends StatelessWidget {
  final List<AppBrainfogStats> apps;

  const _AppCircles({required this.apps});

  /// Beyond this the row stops being scannable and becomes a smear.
  static const _maxShown = 7;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shown = apps.take(_maxShown).toList();
    final overflow = apps.length - shown.length;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'APPS USED',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${apps.length}',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final app in shown)
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.card,
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: ClipOval(
                        child: AppIconAvatar(
                          packageName: app.packageName,
                          appName: app.appName,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                ),
              if (overflow > 0)
                Expanded(
                  child: Center(
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primarySoft,
                      ),
                      child: Text(
                        '+$overflow',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.primaryDeep,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              // Keeps a short row left-aligned instead of stretching the
              // circles apart across the whole card.
              for (
                var i = shown.length + (overflow > 0 ? 1 : 0);
                i < _maxShown + 1;
                i++
              )
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rotto's mood for the day, as a coloured dot and its name.
class _MoodLine extends StatelessWidget {
  final RottoScore level;

  const _MoodLine({required this.level});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = RottoCharacter.colorFor(level.state);
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          RottoCharacter.nameFor(level.state),
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            RottoCharacter.captionFor(level.state),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }
}

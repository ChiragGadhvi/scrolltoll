import 'package:flutter/material.dart';

import '../services/hive_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/rotto_character.dart';
import '../utils/rotto_score.dart';
import 'day_detail_dialog.dart';

export 'day_detail_dialog.dart' show DayTopApp;

/// One plotted day: its date key and the minutes recorded against it.
typedef DayValue = ({String date, int minutes});

/// A time-series chart where every day's point is a circular coin holding
/// that day's Rotto pose, ringed in that day's mood colour.
///
/// Pass [isPerApp] on a per-app history (App Detail reuses this same chart)
/// to suppress the day-wide mood label in the tap popup, which would be
/// misleading once the chart is scoped to one app rather than the whole day.
///
/// Drawn natively: a [CustomPainter] lays down the grid, curve and fill, and the
/// coins ride on top as real widgets so they can use the existing art and take
/// taps. The y-axis gutter sits outside the scroll view, so labels stay pinned
/// while a long range scrolls under them.
class RottoCoinChart extends StatefulWidget {
  /// Oldest first.
  final List<DayValue> days;

  /// True on a per-app history, where the day-wide mood label in the detail
  /// popup would be misleading. Coins still show Rotto either way.
  final bool isPerApp;

  /// Per-date "most used app", shown in a bubble when a day is tapped. Omit for
  /// a chart that already describes a single app.
  final Map<String, DayTopApp>? topApps;

  const RottoCoinChart({
    super.key,
    required this.days,
    this.isPerApp = false,
    this.topApps,
  });

  @override
  State<RottoCoinChart> createState() => _RottoCoinChartState();
}

class _RottoCoinChartState extends State<RottoCoinChart> {
  static const _plotHeight = 196.0;
  static const _coinSize = 54.0;
  static const _minColumnWidth = 66.0;
  static const _gutterWidth = 40.0;
  static const _xLabelHeight = 26.0;

  final _scrollController = ScrollController();
  int? _selected;

  @override
  void initState() {
    super.initState();
    // Today is the newest point, so on a long range it starts off-screen to the
    // right. Open on it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onSelect(int index) {
    setState(() => _selected = index);
    final day = widget.days[index];
    showDayDetail(
      context,
      date: day.date,
      minutes: day.minutes,
      topApp: widget.topApps?[day.date],
      showMood: !widget.isPerApp,
    );
  }

  /// A round ceiling for the y-axis, so gridline labels read as whole hours
  /// rather than arbitrary minutes.
  static int _niceMax(int busiest) {
    const steps = [30, 60, 90, 120, 180, 240, 300, 360, 480, 600];
    for (final s in steps) {
      if (busiest <= s) return s;
    }
    return ((busiest / 60).ceil()) * 60;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.days.isEmpty) return const SizedBox.shrink();

    final selectedIndex = (_selected ?? widget.days.length - 1).clamp(
      0,
      widget.days.length - 1,
    );
    final busiest = widget.days.fold<int>(
      0,
      (m, d) => d.minutes > m ? d.minutes : m,
    );
    final maxMinutes = _niceMax(busiest);
    final recorded = widget.days.where((d) => d.minutes > 0).length;

    return Column(
      children: [
        _SelectedDayHeader(
          day: widget.days[selectedIndex],
          moodFromDay: !widget.isPerApp,
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: _plotHeight + _xLabelHeight,
          child: Row(
            children: [
              _YAxis(maxMinutes: maxMinutes),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Short ranges spread to fill the card; long ones keep a
                    // readable column width and scroll instead of squashing.
                    final spread = constraints.maxWidth / widget.days.length;
                    final columnWidth = spread >= _minColumnWidth
                        ? spread
                        : _minColumnWidth;
                    final plotWidth = columnWidth * widget.days.length;

                    return SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: plotWidth <= constraints.maxWidth
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      child: SizedBox(
                        width: plotWidth,
                        child: _Plot(
                          days: widget.days,
                          maxMinutes: maxMinutes,
                          columnWidth: columnWidth,
                          coinSize: _coinSize,
                          plotHeight: _plotHeight,
                          xLabelHeight: _xLabelHeight,
                          selectedIndex: selectedIndex,
                          onSelect: _onSelect,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (recorded < widget.days.length) ...[
          const SizedBox(height: 12),
          Text(
            // Says plainly that a gap is missing history, not a quiet day —
            // Android only hands over about a week of detail, so earlier days
            // only exist once Rotto has recorded them itself.
            '$recorded of ${widget.days.length} days recorded so far',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ],
    );
  }
}

/// Pinned y-axis labels, aligned to the gridlines the painter draws.
class _YAxis extends StatelessWidget {
  final int maxMinutes;

  const _YAxis({required this.maxMinutes});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.textTertiary,
      fontSize: 9.5,
      fontFeatures: tabularFigures,
    );

    return SizedBox(
      width: _RottoCoinChartState._gutterWidth,
      child: Padding(
        // Leave the x-label strip clear so labels line up with the plot.
        padding: const EdgeInsets.only(
          bottom: _RottoCoinChartState._xLabelHeight,
          right: 6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 3; i >= 0; i--) ...[
              Text(
                i == 0 ? '0' : formatDuration((maxMinutes * i / 3).round()),
                style: style,
                textAlign: TextAlign.right,
              ),
              if (i > 0) const Spacer(),
            ],
          ],
        ),
      ),
    );
  }
}

/// The grid, curve and coins for the visible range.
class _Plot extends StatelessWidget {
  final List<DayValue> days;
  final int maxMinutes;
  final double columnWidth;
  final double coinSize;
  final double plotHeight;
  final double xLabelHeight;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _Plot({
    required this.days,
    required this.maxMinutes,
    required this.columnWidth,
    required this.coinSize,
    required this.plotHeight,
    required this.xLabelHeight,
    required this.selectedIndex,
    required this.onSelect,
  });

  /// Vertical centre of a day's coin, measured from the top of the plot.
  double _dy(int minutes) {
    // Coins are inset by half their height at both ends so a 0-minute day and
    // a maximum day are both drawn fully inside the plot.
    final usable = plotHeight - coinSize;
    final fraction = maxMinutes == 0
        ? 0.0
        : (minutes / maxMinutes).clamp(0.0, 1.0);
    return coinSize / 2 + usable * (1 - fraction);
  }

  @override
  Widget build(BuildContext context) {
    final points = [
      for (var i = 0; i < days.length; i++)
        Offset(columnWidth * i + columnWidth / 2, _dy(days[i].minutes)),
    ];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: plotHeight,
          child: CustomPaint(painter: _GridAndCurvePainter(points: points)),
        ),
        for (var i = 0; i < days.length; i++)
          Positioned(
            left: points[i].dx - columnWidth / 2,
            top: 0,
            width: columnWidth,
            height: plotHeight + xLabelHeight,
            child: _CoinColumn(
              day: days[i],
              coinSize: coinSize,
              coinTop: points[i].dy - coinSize / 2,
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
          ),
      ],
    );
  }
}

class _GridAndCurvePainter extends CustomPainter {
  final List<Offset> points;

  const _GridAndCurvePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;

    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (points.length < 2) return;

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      // Horizontal control points give a gentle S between days without
      // overshooting into impossible negative time.
      final prev = points[i - 1];
      final next = points[i];
      final midX = (prev.dx + next.dx) / 2;
      line.cubicTo(midX, prev.dy, midX, next.dy, next.dx, next.dy);
    }

    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.22),
            AppColors.primary.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_GridAndCurvePainter old) => old.points != points;
}

/// One day: its coin at the right height, and its label underneath.
class _CoinColumn extends StatelessWidget {
  final DayValue day;
  final double coinSize;
  final double coinTop;
  final bool selected;
  final VoidCallback onTap;

  const _CoinColumn({
    required this.day,
    required this.coinSize,
    required this.coinTop,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = day.date == HiveService.todayKey;
    final empty = day.minutes == 0;
    final accent = RottoCharacter.colorFor(RottoScore(day.minutes).state);
    final label = weekdayInitial(day.date);

    final coinContents = empty
        // An unrecorded day gets a hollow coin — it must not read as a
        // cheerful zero-minute day.
        ? Center(
            child: Text(
              '–',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w800,
                fontSize: coinSize * 0.4,
              ),
            ),
          )
        // Zoomed 30% and clipped to the circle, so he fills the coin instead of
        // floating in the middle of it. Centred, so nothing is lopped off one
        // end the way the old top-aligned scale cropped his feet.
        : ClipOval(
            child: Transform.scale(
              scale: 1.3,
              child: Image.asset(
                RottoCharacter.assetFor(RottoScore(day.minutes).state),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
          );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: coinTop,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: selected ? 1.16 : 1,
                child: Container(
                  width: coinSize,
                  height: coinSize,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: empty ? AppColors.divider : accent,
                      width: selected ? 2.5 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (empty ? AppColors.textTertiary : accent)
                            .withValues(alpha: selected ? 0.32 : 0.14),
                        blurRadius: selected ? 9 : 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: coinContents,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 21,
                height: 21,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isToday
                        ? Theme.of(context).colorScheme.onPrimary
                        : selected
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                    fontWeight: isToday || selected
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The tapped day, spelled out above the chart.
class _SelectedDayHeader extends StatelessWidget {
  final DayValue day;

  /// False on a per-app chart, where a whole-day mood label would be wrong.
  final bool moodFromDay;

  const _SelectedDayHeader({required this.day, required this.moodFromDay});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final empty = day.minutes == 0;
    final level = RottoScore(day.minutes);
    final accent = RottoCharacter.colorFor(level.state);

    final heading = day.date == HiveService.todayKey
        ? 'Today'
        : weekdayAndDay(day.date);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading.toUpperCase(),
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                empty ? 'No record' : formatDuration(day.minutes),
                style: textTheme.titleLarge?.copyWith(
                  color: empty ? AppColors.textTertiary : AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
        ),
        if (!empty && moodFromDay)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              RottoCharacter.nameFor(level.state),
              style: textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

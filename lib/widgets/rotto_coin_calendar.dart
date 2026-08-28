import 'package:flutter/material.dart';

import '../services/hive_service.dart';
import '../theme/app_theme.dart';
import '../utils/rotto_character.dart';
import '../utils/rotto_score.dart';
import 'day_detail_dialog.dart';
import 'rotto_coin_chart.dart' show DayValue;

/// A month laid out as a calendar, each day a Rotto coin.
///
/// Same coin and same tap-to-open-detail as the week chart, so the two views
/// feel like one idea at two zoom levels.
class RottoCoinCalendar extends StatelessWidget {
  /// Oldest first.
  final List<DayValue> days;

  /// Per-date "most used app", passed straight to the day detail.
  final Map<String, DayTopApp>? topApps;

  const RottoCoinCalendar({super.key, required this.days, this.topApps});

  static const _weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    // Pad the front so the first day sits under its real weekday column.
    var leadingBlanks = 0;
    try {
      leadingBlanks = DateTime.parse(days.first.date).weekday - 1;
    } catch (_) {}

    final recorded = days.where((d) => d.minutes > 0).length;

    return Column(
      children: [
        Row(
          children: [
            for (final d in _weekdayInitials)
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 4,
            // Taller than wide, to fit the coin plus its date label.
            childAspectRatio: 0.72,
          ),
          itemCount: leadingBlanks + days.length,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = days[index - leadingBlanks];
            return _CalendarCoin(
              day: day,
              onTap: () => showDayDetail(
                context,
                date: day.date,
                minutes: day.minutes,
                topApp: topApps?[day.date],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          recorded == days.length
              ? 'Tap any day to see it'
              : '$recorded of ${days.length} days recorded so far',
          style: textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _CalendarCoin extends StatelessWidget {
  final DayValue day;
  final VoidCallback onTap;

  const _CalendarCoin({required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final empty = day.minutes == 0;
    final isToday = day.date == HiveService.todayKey;
    final level = RottoScore(day.minutes);
    final accent = RottoCharacter.colorFor(level.state);

    var dayNum = '';
    try {
      dayNum = '${DateTime.parse(day.date).day}';
    } catch (_) {}

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: empty
                      ? AppColors.surfaceMuted
                      : accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    // Today is ringed in brand purple so it is findable at a
                    // glance in a grid of thirty.
                    color: isToday
                        ? AppColors.primary
                        : empty
                        ? AppColors.divider
                        : accent.withValues(alpha: 0.5),
                    width: isToday ? 2.2 : 1.4,
                  ),
                ),
                child: empty
                    // An unrecorded day must not read as a cheerful zero.
                    ? Center(
                        child: Text(
                          '–',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      )
                    // Matches the week chart's coins: zoomed 30% and clipped
                    // to the circle so he fills it.
                    : ClipOval(
                        child: Transform.scale(
                          scale: 1.3,
                          child: Image.asset(
                            RottoCharacter.assetFor(level.state),
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            dayNum,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isToday ? AppColors.primaryDeep : AppColors.textTertiary,
              fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
              fontSize: 10,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

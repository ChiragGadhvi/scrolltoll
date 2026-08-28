import 'package:flutter/material.dart';

import '../services/hive_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/rotto_character.dart';
import '../utils/rotto_score.dart';
import 'ui_kit.dart';

/// The app that took the most of a given day.
typedef DayTopApp = ({String appName, String packageName, int minutes});

/// Opens the centred day detail: the day's Rotto pose at full size, its total,
/// and the app that took the most of it.
///
/// Shared by the week chart and the month calendar so a tap means the same
/// thing everywhere.
Future<void> showDayDetail(
  BuildContext context, {
  required String date,
  required int minutes,
  DayTopApp? topApp,

  /// Set on a per-app view, where a whole-day mood label would be misleading.
  bool showMood = true,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.45),
    builder: (_) => _DayDetailDialog(
      date: date,
      minutes: minutes,
      topApp: topApp,
      showMood: showMood,
    ),
  );
}

class _DayDetailDialog extends StatelessWidget {
  final String date;
  final int minutes;
  final DayTopApp? topApp;
  final bool showMood;

  const _DayDetailDialog({
    required this.date,
    required this.minutes,
    required this.topApp,
    required this.showMood,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final empty = minutes == 0;
    final level = RottoScore(minutes);
    final accent = RottoCharacter.colorFor(level.state);
    final top = topApp;

    final heading = date == HiveService.todayKey
        ? 'Today'
        : '${weekdayName(date)}, ${monthDayLabel(date)}';

    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              heading.toUpperCase(),
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 14),
            // The pose at a size where it actually reads, which is the point of
            // opening the dialog at all.
            Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: empty
                    ? AppColors.surfaceMuted
                    : accent.withValues(alpha: 0.10),
                border: Border.all(
                  color: empty
                      ? AppColors.divider
                      : accent.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: Opacity(
                opacity: empty ? 0.35 : 1,
                child: ClipOval(
                  child: Transform.scale(
                    scale: 1.2,
                    child: Image.asset(
                      RottoCharacter.assetFor(level.state),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              empty ? 'No record' : formatDuration(minutes),
              style: textTheme.displaySmall?.copyWith(
                color: empty ? AppColors.textTertiary : AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                height: 1.05,
                letterSpacing: -1.2,
                fontFeatures: tabularFigures,
              ),
            ),
            if (empty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Rotto had no data for this day.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            if (!empty && showMood) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  RottoCharacter.nameFor(level.state),
                  style: textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            if (top != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(),
              ),
              Row(
                children: [
                  AppIconAvatar(
                    packageName: top.packageName,
                    appName: top.appName,
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MOST USED',
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          top.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatDuration(top.minutes),
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.primaryDeep,
                      fontWeight: FontWeight.w800,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  backgroundColor: AppColors.surfaceMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

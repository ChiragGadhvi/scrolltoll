import 'package:flutter/material.dart';

import '../models/app_brainfog_stats_model.dart';
import '../screens/app_detail_screen.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/rotto_character.dart';
import '../utils/rotto_score.dart';
import 'ui_kit.dart';

/// One tracked app and the time it took, coloured on the same green → red ramp
/// as the rest of the app. Tapping opens that app's history.
class AppBrainfogTile extends StatelessWidget {
  final AppBrainfogStats app;

  /// 1-based position in the list, shown as a small ordinal. Null hides it.
  final int? rank;

  /// 0.0-1.0 share of the busiest app in the same list, drawn as a thin bar so
  /// the rows compare at a glance. Null or 0 hides the bar.
  final double? shareOfMax;

  /// Shown in place of the duration. Used for tracked apps with no time yet,
  /// where "0min" reads like a bug rather than "not opened".
  final String? trailingLabel;

  const AppBrainfogTile({
    super.key,
    required this.app,
    this.rank,
    this.shareOfMax,
    this.trailingLabel,
  });

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppDetailScreen(
          packageName: app.packageName,
          appName: app.appName,
          todayMinutes: app.minutes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = RottoCharacter.colorFor(RottoScore(app.minutes).state);
    final share = shareOfMax;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              if (rank != null) ...[
                SizedBox(
                  width: 18,
                  child: Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              AppIconAvatar(
                packageName: app.packageName,
                appName: app.appName,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      app.appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (share != null && share > 0) ...[
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.easeOutCubic,
                          tween: Tween(begin: 0, end: share.clamp(0.0, 1.0)),
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                                value: value,
                                minHeight: 6,
                                color: color,
                                backgroundColor: color.withValues(alpha: 0.14),
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                trailingLabel ?? formatDuration(app.minutes),
                style: textTheme.bodyMedium?.copyWith(
                  color: trailingLabel != null ? AppColors.textTertiary : color,
                  fontWeight: trailingLabel != null
                      ? FontWeight.w600
                      : FontWeight.w800,
                  fontFeatures: tabularFigures,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

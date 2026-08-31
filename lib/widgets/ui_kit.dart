import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

/// Shared building blocks, so every screen looks like one app. Before this
/// existed the launcher-icon lookup and the same rounded container were
/// copy-pasted into each screen.

/// The standard rounded surface everything sits on.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}

/// A section title, with optional supporting line and trailing widget.
class SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.1,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// One value in a [MetricStrip].
class Metric {
  final String label;
  final String value;

  /// Colours the value. Defaults to primary text when null.
  final Color? valueColor;

  const Metric({required this.label, required this.value, this.valueColor});
}

/// Two or three related figures in a single card, separated by hairlines.
///
/// Replaces the old row of separate chunky stat cards — one surface with
/// dividers reads as one set of related numbers instead of three competing
/// tiles.
class MetricStrip extends StatelessWidget {
  final List<Metric> metrics;

  const MetricStrip({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 36, color: AppColors.divider),
            Expanded(
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      metrics[i].value,
                      maxLines: 1,
                      style: textTheme.titleMedium?.copyWith(
                        color: metrics[i].valueColor ?? AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    metrics[i].label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small pill showing a change against a previous period.
///
/// Down is green because less screen time is the good direction — the arrow
/// and the colour have to agree or the badge reads backwards.
class TrendPill extends StatelessWidget {
  final int percent;

  const TrendPill({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    final down = percent < 0;
    final color = down ? AppColors.safe : AppColors.bingeOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            down ? Icons.south_rounded : Icons.north_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '${percent.abs()}%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// A launcher icon for [packageName], falling back to a lettered tile while the
/// lookup is in flight or when the app has no icon to give.
class AppIconAvatar extends StatelessWidget {
  final String packageName;
  final String appName;
  final double size;

  const AppIconAvatar({
    super.key,
    required this.packageName,
    required this.appName,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.3);
    return FutureBuilder<Application?>(
      future: DeviceApps.getApp(packageName, true),
      builder: (context, snapshot) {
        final app = snapshot.data;
        if (app is ApplicationWithIcon) {
          return ClipRRect(
            borderRadius: radius,
            child: Image.memory(
              app.icon,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        }
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: radius,
          ),
          child: Center(
            child: Text(
              appName.isNotEmpty ? appName[0].toUpperCase() : '?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Rotto waiting, in place of a spinner.
///
/// A character who is visibly *fine with waiting* reads better than a spinning
/// ring, and it keeps him present on the one screen where he would otherwise
/// vanish.
class RottoLoader extends StatelessWidget {
  final String? message;
  final double size;

  const RottoLoader({super.key, this.message, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/rotto_waiting.webp',
          // The webp still carries a little padding around Rotto (unlike
          // the old PNG, cropped almost edge-to-edge), so scale the box up
          // to keep his rendered size matching `size` as callers expect.
          height: size * 1.17,
          filterQuality: FilterQuality.high,
        ),
        if (message != null) ...[
          const SizedBox(height: 14),
          Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 900.ms)
              .then()
              .fadeOut(duration: 900.ms),
        ],
      ],
    );
  }
}

/// An empty state: Rotto shrugging, a headline, and one line of guidance.
///
/// A named state with a face reads as "nothing here yet" rather than as a
/// broken screen, which a bare sentence in a grey box does not.
class RottoEmptyState extends StatelessWidget {
  final String title;
  final String message;

  const RottoEmptyState({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      child: Column(
        children: [
          Image.asset(
            'assets/rotto_empty.webp',
            // The webp keeps a little padding around Rotto (for the
            // shrug's raised arms), unlike the old PNG which was cropped
            // almost edge-to-edge — sized up so he renders at the same
            // visual size as before, not just the same box height.
            height: 157,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/rotto_character.dart';
import '../utils/rotto_score.dart';
import '../widgets/ui_kit.dart';
import 'tracked_apps_screen.dart';

const _appVersionLabel = '2.0.0';

class SettingsScreen extends StatefulWidget {
  final bool embedded;

  const SettingsScreen({super.key, this.embedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _notificationsEnabled;
  late TimeOfDay _notifTime;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = HiveService.notificationsEnabled;
    _notifTime = TimeOfDay(
      hour: HiveService.notificationHour,
      minute: HiveService.notificationMinute,
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notifTime,
    );
    if (picked != null) {
      setState(() => _notifTime = picked);
      HiveService.notificationHour = picked.hour;
      HiveService.notificationMinute = picked.minute;
      // Reschedule immediately. This used to wait for Home to refresh, so the
      // reminder kept firing at the old time until the app was reopened.
      if (_notificationsEnabled) {
        await NotificationService.scheduleDailyReminder(
          hour: picked.hour,
          minute: picked.minute,
        );
      }
    }
  }

  void _showHelp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => _HelpSheet(versionLabel: _appVersionLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trackedCount = HiveService.trackedApps.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.embedded ? null : AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: widget.embedded,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, widget.embedded ? 18 : 8, 16, 24),
          children: [
            if (widget.embedded)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 18),
                child: Text(
                  'Settings',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            _groupLabel('TRACKING', textTheme),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.ads_click_rounded,
                  iconColor: AppColors.primary,
                  title: 'Apps to Track',
                  subtitle: trackedCount == 0
                      ? 'None selected yet'
                      : '$trackedCount app${trackedCount == 1 ? '' : 's'} tracked',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TrackedAppsScreen(),
                      ),
                    ).then((_) => setState(() {}));
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            _groupLabel('ROTTO’S MOODS', textTheme),
            const _MoodLegend(),
            const SizedBox(height: 22),
            _groupLabel('NOTIFICATIONS', textTheme),
            _SettingsGroup(
              children: [
                _SwitchRow(
                  icon: Icons.notifications_active_rounded,
                  iconColor: AppColors.safe,
                  title: 'Daily report',
                  subtitle: 'A short summary of your day',
                  value: _notificationsEnabled,
                  onChanged: (v) async {
                    setState(() => _notificationsEnabled = v);
                    HiveService.notificationsEnabled = v;
                    if (v) {
                      // Onboarding only asks on the path the user can skip, so
                      // enabling here has to ask too or the switch lies.
                      await NotificationService.requestPermission();
                      await NotificationService.scheduleDailyReminder(
                        hour: HiveService.notificationHour,
                        minute: HiveService.notificationMinute,
                      );
                    } else {
                      await NotificationService.cancel();
                    }
                  },
                ),
                if (_notificationsEnabled) ...[
                  const Divider(),
                  _SettingsRow(
                    icon: Icons.schedule_rounded,
                    iconColor: AppColors.warning,
                    title: 'Report time',
                    subtitle: null,
                    trailingText: _notifTime.format(context),
                    onTap: _pickTime,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 22),
            _groupLabel('ABOUT', textTheme),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.help_outline_rounded,
                  iconColor: AppColors.primaryDeep,
                  title: 'Help & FAQ',
                  subtitle: null,
                  onTap: _showHelp,
                ),
                const Divider(),
                _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  iconColor: AppColors.textSecondary,
                  title: 'App version',
                  subtitle: null,
                  trailingText: _appVersionLabel,
                  showChevron: false,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Everything stays on this phone.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupLabel(String title, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 6),
      child: Text(
        title,
        style: textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Every mood Rotto has, with the pose and the screen time that earns it, as
/// a swipeable carousel of cards rather than a stacked list.
///
/// Thresholds come from [RottoScore.moodStartMinutes], so this list cannot drift
/// from the ladder the rest of the app computes with.
class _MoodLegend extends StatefulWidget {
  const _MoodLegend();

  @override
  State<_MoodLegend> createState() => _MoodLegendState();
}

class _MoodLegendState extends State<_MoodLegend> {
  final _controller = PageController(viewportFraction: 1);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final starts = RottoScore.moodStartMinutes;
    final states = RottoState.values;

    return Column(
      children: [
        SizedBox(
          height: 340,
          child: PageView.builder(
            controller: _controller,
            itemCount: states.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  var scale = 1.0;
                  if (_controller.position.haveDimensions) {
                    final delta = (_controller.page ?? _page.toDouble()) - i;
                    scale = (1 - delta.abs() * 0.15).clamp(0.85, 1.0);
                  }
                  return Center(
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _MoodCard(
                    state: states[i],
                    fromMinutes: starts[states[i]] ?? 0,
                    // The last rung runs to the end of the day, so it has no ceiling.
                    toMinutes: i + 1 < states.length
                        ? (starts[states[i + 1]] ?? 0) - 1
                        : null,
                    textTheme: textTheme,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < states.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _page == i
                      ? RottoCharacter.colorFor(states[i])
                      : AppColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MoodCard extends StatelessWidget {
  final RottoState state;
  final int fromMinutes;
  final int? toMinutes;
  final TextTheme textTheme;

  const _MoodCard({
    required this.state,
    required this.fromMinutes,
    required this.toMinutes,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final color = RottoCharacter.colorFor(state);
    final to = toMinutes;
    final range = to == null
        ? '${formatDuration(fromMinutes)}+'
        : fromMinutes == 0
        ? 'Up to ${formatDuration(to)}'
        : '${formatDuration(fromMinutes)} – ${formatDuration(to)}';

    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.10),
              border: Border.all(color: color.withValues(alpha: 0.40)),
            ),
            child: ClipOval(
              child: Transform.scale(
                scale: 1.55,
                child: Image.asset(
                  RottoCharacter.assetFor(state),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            RottoCharacter.nameFor(state),
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              range,
              style: textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontFeatures: tabularFigures,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            RottoCharacter.captionFor(state),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// A card grouping a set of setting rows.
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    // Material, not a decorated Container: the rows are ListTiles, which paint
    // their ink splashes onto the nearest Material ancestor. A Container's
    // colour would sit on top of those splashes and hide them.
    return Material(
      color: AppColors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.divider),
      ),
      child: Column(children: children),
    );
  }
}

/// The rounded icon chip every settings row leads with.
class _RowIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _RowIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final bool showChevron;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailingText,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: _RowIcon(icon: icon, color: iconColor),
      title: Text(
        title,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText!,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (showChevron && onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      secondary: _RowIcon(icon: icon, color: iconColor),
      title: Text(
        title,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
      value: value,
      activeThumbColor: AppColors.card,
      activeTrackColor: AppColors.primary,
      onChanged: onChanged,
    );
  }
}

class _HelpSheet extends StatelessWidget {
  final String versionLabel;
  const _HelpSheet({required this.versionLabel});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Help & FAQ',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 18),
            _faq(
              textTheme,
              'What does Rotto measure?',
              'Only one thing: how long you spend in the apps you choose to '
                  'track. Rotto reads that from Android and adds it up for the '
                  'day. It never blocks, closes or limits an app.',
            ),
            _faq(
              textTheme,
              'How does the score work?',
              'It starts at 100 each morning and counts down as your tracked '
                  'screen time adds up, reaching 0 at around 4 hours. Higher '
                  'is better.',
            ),
            _faq(
              textTheme,
              'Why does Rotto keep changing?',
              'His mood follows the score: Energetic at 80 and above, '
                  'Scrolling 60-79, Tired 40-59, Binge Mode 20-39 and No '
                  'Energy under 20. It is for fun — not a medical or '
                  'diagnostic measurement of anything.',
            ),
            _faq(
              textTheme,
              'Which apps can I track?',
              'Any app installed on your phone — not just Instagram, YouTube '
                  'or TikTok. Nothing is counted until you add it to your '
                  '"Apps to Track" list yourself.',
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'App Version',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  versionLabel,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _faq(TextTheme textTheme, String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            answer,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

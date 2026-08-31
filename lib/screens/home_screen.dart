import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../models/app_brainfog_stats_model.dart';
import '../models/daily_brainfog_stats_model.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../services/usage_stats_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/rotto_character.dart';
import '../utils/rotto_score.dart';
import '../widgets/app_brainfog_tile.dart';
import '../widgets/ui_kit.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  List<AppBrainfogStats> _apps = [];

  /// Tracked apps with no recorded time today, listed so a just-added app is
  /// visibly tracked instead of silently absent. Never persisted.
  List<AppBrainfogStats> _unusedTracked = [];
  bool _loading = true;
  bool _permissionMissing = false;
  String _lastLoadedDate = '';
  StreamSubscription<dynamic>? _midnightCheckerSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastLoadedDate = HiveService.todayKey;
    // Changing the tracked set anywhere (Settings, the picker, onboarding) has
    // to refresh today's list; returning from a pushed route never fires
    // didChangeAppLifecycleState, and IndexedStack keeps this screen alive.
    HiveService.trackedAppsRevision.addListener(_loadData);
    _loadData();
    _midnightCheckerSub = Stream.periodic(const Duration(minutes: 1)).listen((
      _,
    ) {
      if (HiveService.todayKey != _lastLoadedDate) {
        HiveService.lastNotifiedMood = null;
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _midnightCheckerSub?.cancel();
    HiveService.trackedAppsRevision.removeListener(_loadData);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadData();
  }

  /// Today's total tracked minutes, and Rotto's mood they produce.
  RottoScore get _level =>
      RottoScore(_apps.fold(0, (sum, app) => sum + app.minutes));

  /// The tracked app with the most foreground time, or null if none.
  static AppBrainfogStats? _busiest(List<AppBrainfogStats> apps) => apps.isEmpty
      ? null
      : (List<AppBrainfogStats>.of(
          apps,
        )..sort((a, b) => b.minutes.compareTo(a.minutes))).first;

  Future<void> _loadData() async {
    _lastLoadedDate = HiveService.todayKey;
    if (mounted) setState(() => _loading = true);

    final hasPermission = await UsageStatsService.checkPermission();
    if (!hasPermission) {
      if (mounted) {
        setState(() {
          _permissionMissing = true;
          _loading = false;
        });
      }
      return;
    }

    final apps = await UsageStatsService.getTodayUsage();
    final totalMinutes = apps.fold(0, (sum, app) => sum + app.minutes);
    final snapshot = List<String>.of(HiveService.trackedApps);
    final today = HiveService.todayKey;

    HiveService.saveAppBrainfogUsageForDate(today, apps);
    HiveService.saveDailyBrainfogStats(
      DailyBrainfogStats(
        date: today,
        totalMinutes: totalMinutes,
        brainfogScore: RottoScore(totalMinutes).score,
        trackedPackagesSnapshot: snapshot,
      ),
    );

    // Android only surfaces about a week of event detail, so probing further
    // back returns nothing. A record is still written for each probed day so it
    // is not re-queried on every refresh; days beyond this simply have no row,
    // which the chart draws as an empty coin rather than a zero.
    //
    // Which days still need a record is decided up front (the write-once
    // guard), then those days' usage is fetched concurrently rather than one
    // await at a time — the days are independent, so there is no reason a
    // slow query for day 9 should hold up starting day 10's.
    final now = DateTime.now();
    final needsBackfill = [
      for (var i = 1; i <= 13; i++)
        if (HiveService.getDailyBrainfogStats(
              HiveService.dateKeyFor(now.subtract(Duration(days: i))),
            ) ==
            null)
          now.subtract(Duration(days: i)),
    ];
    final backfillResults = await Future.wait(
      needsBackfill.map(UsageStatsService.getUsageForDate),
    );
    for (var i = 0; i < needsBackfill.length; i++) {
      final key = HiveService.dateKeyFor(needsBackfill[i]);
      final pastApps = backfillResults[i];
      final pastMinutes = pastApps.fold(0, (sum, app) => sum + app.minutes);
      HiveService.saveAppBrainfogUsageForDate(key, pastApps);
      HiveService.saveDailyBrainfogStats(
        DailyBrainfogStats(
          date: key,
          totalMinutes: pastMinutes,
          brainfogScore: RottoScore(pastMinutes).score,
          trackedPackagesSnapshot: snapshot,
        ),
      );
    }

    final busiestApp = _busiest(apps);
    if (HiveService.notificationsEnabled) {
      NotificationService.scheduleDailyReminder(
        hour: HiveService.notificationHour,
        minute: HiveService.notificationMinute,
      );
      await _announceMoodChange(totalMinutes);
    }

    final usedPackages = apps.map((a) => a.packageName).toSet();
    final unusedPackages = HiveService.trackedApps
        .where((p) => !usedPackages.contains(p))
        .toList();
    final unusedNames = await UsageStatsService.resolveAppNames(unusedPackages);
    final unusedTracked =
        [
          for (final pkg in unusedPackages)
            AppBrainfogStats(
              appName: unusedNames[pkg] ?? pkg,
              packageName: pkg,
              minutes: 0,
            ),
        ]..sort(
          (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
        );

    if (mounted) {
      setState(() {
        _apps = apps;
        _unusedTracked = unusedTracked;
        _loading = false;
        _permissionMissing = false;
      });
    }

    // Insights and any other cached reader can now see today's records.
    HiveService.notifyStatsChanged();

    await _updateHomeWidget(totalMinutes, busiestApp?.appName ?? '');
  }

  /// Tells the user when Rotto's mood changes, once per change.
  ///
  /// The first ever refresh only records the mood — announcing "you are now
  /// Energetic" the moment someone installs the app would be noise. Resets at
  /// midnight along with everything else, so each new day's first mood is
  /// recorded rather than announced.
  Future<void> _announceMoodChange(int totalMinutes) async {
    final state = RottoScore(totalMinutes).state;
    final previous = HiveService.lastNotifiedMood;
    HiveService.lastNotifiedMood = state.name;
    if (previous == null || previous == state.name) return;
    await NotificationService.notifyMoodChange(
      state: state,
      totalMinutes: totalMinutes,
    );
  }

  /// Pushes today's snapshot to the Android home widget.
  Future<void> _updateHomeWidget(int totalMinutes, String topApp) async {
    final level = RottoScore(totalMinutes);
    try {
      // Four independent keys — write them concurrently, then flip the widget
      // over once all four have landed.
      await Future.wait([
        HomeWidget.saveWidgetData<String>('tracked_minutes', '$totalMinutes'),
        HomeWidget.saveWidgetData<String>('rotto_score', '${level.score}'),
        HomeWidget.saveWidgetData<String>('rotto_state', level.state.name),
        HomeWidget.saveWidgetData<String>('top_app', topApp),
      ]);
      await HomeWidget.updateWidget(androidName: 'BrainfogWidgetProvider');
    } catch (_) {
      // The HomeWidget bridge is unavailable during widget tests and on any
      // non-Android host; the in-app view is unaffected either way.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.card,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _DashboardTab(
              apps: _apps,
              unusedTracked: _unusedTracked,
              level: _level,
              loading: _loading,
              permissionMissing: _permissionMissing,
              onRequestPermission: UsageStatsService.requestPermission,
              onRefresh: _loadData,
            ),
            const AnalyticsScreen(embedded: true),
            const SettingsScreen(embedded: true),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.cottage_outlined),
                selectedIcon: Icon(Icons.cottage_rounded),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: 'Insights',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final List<AppBrainfogStats> apps;
  final List<AppBrainfogStats> unusedTracked;
  final RottoScore level;
  final bool loading;
  final bool permissionMissing;
  final VoidCallback onRequestPermission;
  final Future<void> Function() onRefresh;

  const _DashboardTab({
    required this.apps,
    required this.unusedTracked,
    required this.level,
    required this.loading,
    required this.permissionMissing,
    required this.onRequestPermission,
    required this.onRefresh,
  });

  /// Busiest first, so the list reads as "what took the day".
  List<AppBrainfogStats> get _ranked =>
      List<AppBrainfogStats>.of(apps)
        ..sort((a, b) => b.minutes.compareTo(a.minutes));

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: RottoLoader(message: 'Counting up your day…'));
    }

    final ranked = _ranked;
    final topMinutes = ranked.isEmpty ? 0 : ranked.first.minutes;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _WordmarkHeader()),
            if (permissionMissing)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _PermissionBanner(onGrant: onRequestPermission),
                ),
              )
            else ...[
              SliverToBoxAdapter(child: _RottoStage(level: level)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                  child: SectionHeading(
                    title: 'Top apps',
                    subtitle: ranked.isEmpty ? null : 'Busiest first',
                    trailing: ranked.isEmpty
                        ? null
                        : Text(
                            '${ranked.length}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: tabularFigures,
                                ),
                          ),
                  ),
                ),
              ),
              if (ranked.isEmpty)
                const SliverToBoxAdapter(
                  child: RottoEmptyState(
                    title: 'Nothing tracked yet today',
                    message:
                        'Pick the apps you want Rotto to watch in '
                        'Settings › Apps to Track.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => AppBrainfogTile(
                        app: ranked[index],
                        rank: index + 1,
                        // Bars are relative to the busiest app, so the list
                        // reads as a ranking rather than a share of nothing.
                        shareOfMax: topMinutes == 0
                            ? 0
                            : ranked[index].minutes / topMinutes,
                      ),
                      childCount: ranked.length,
                    ),
                  ),
                ),
              if (unusedTracked.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: SectionHeading(
                      title: 'Also tracked',
                      subtitle: 'Not opened today',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => AppBrainfogTile(
                        app: unusedTracked[index],
                        trailingLabel: 'Not used',
                      ),
                      childCount: unusedTracked.length,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Centred wordmark.
class _WordmarkHeader extends StatelessWidget {
  const _WordmarkHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Center(
        child: Text(
          'ROTTO',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// The hero: Rotto on his hill, his score, today's total, and the mood line.
///
/// Art and caption come from [RottoCharacter] for the current state; the hill
/// stays brand purple so only his pose and the score colour change.
class _RottoStage extends StatelessWidget {
  final RottoScore level;

  const _RottoStage({required this.level});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = RottoCharacter.colorFor(level.state);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.card, AppColors.hillLight],
                  ),
                ),
              ),
            ),
            // The hill sits behind Rotto's feet and under the score.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 226,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.hill,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(170),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 16),
                SizedBox(
                  height: 317, // 244 * 1.3
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    // The idle motion used to be a hand-rolled bob here; now
                    // it's baked into the looping WebP itself, so this is
                    // just the cross-fade between one mood's animation and
                    // the next.
                    child: Image.asset(
                      RottoCharacter.assetFor(level.state),
                      key: ValueKey(level.state),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                _ScoreNumber(score: level.score),
                const SizedBox(height: 2),
                Text(
                  '${formatDuration(level.trackedMinutes)} today',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.primaryDeep,
                    fontWeight: FontWeight.w700,
                    fontFeatures: tabularFigures,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      tween: Tween(begin: 1, end: level.score / 100),
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 12,
                        color: accent,
                        backgroundColor: AppColors.card.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Text(
                    RottoCharacter.captionFor(level.state),
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The score, set heavy with a white outline so it stays legible against the
/// hill. Counts up on first paint.
class _ScoreNumber extends StatelessWidget {
  final int score;

  const _ScoreNumber({required this.score});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rotto score $score out of 100',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0, end: score.toDouble()),
          builder: (context, value, _) {
            final text = '${value.round()}';
            const size = 66.0;
            return Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: size,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -2,
                    fontFeatures: tabularFigures,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 9
                      ..strokeJoin = StrokeJoin.round
                      ..color = AppColors.card,
                  ),
                ),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: size,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -2,
                    fontFeatures: tabularFigures,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onGrant;

  const _PermissionBanner({required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Usage Access Required',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Usage Access lets Rotto measure time in only the apps you '
            'choose. Your data stays on this phone.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onGrant,
              child: const Text('Grant Usage Access'),
            ),
          ),
        ],
      ),
    );
  }
}

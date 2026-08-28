import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_brainfog_stats_model.dart';
import '../models/daily_brainfog_stats_model.dart';

class HiveService {
  static const _settingsBox = 'settings';
  static const _dailyBrainfogStatsBox = 'daily_brainfog_stats';
  static const _appBrainfogUsageBox = 'app_brainfog_usage';

  /// Bumped when stored usage numbers become untrustworthy and have to be
  /// rebuilt rather than migrated.
  ///
  /// v2: everything written before this used `queryUsageStats`, which sums
  /// Android's interval buckets and so recorded wildly inflated totals — days
  /// reading 30h were common. Those records cannot be corrected in place (the
  /// original per-session detail was never stored), and the write-once backfill
  /// guard means they would never be overwritten either. So they are dropped and
  /// re-derived from event data, which is accurate for roughly the last week.
  static const _dataVersion = 2;

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(DailyBrainfogStatsAdapter());
    await Hive.openBox(_settingsBox);
    await Hive.openBox<DailyBrainfogStats>(_dailyBrainfogStatsBox);
    await Hive.openBox(_appBrainfogUsageBox);

    if (settings.get('data_version') != _dataVersion) {
      await dailyBrainfogStats.clear();
      await appBrainfogUsage.clear();
      await settings.put('data_version', _dataVersion);
    }
  }

  // Settings
  static Box get settings => Hive.box(_settingsBox);

  /// Bumped whenever [trackedApps] is written, so screens holding cached usage
  /// can reload. Watched by HomeScreen.
  static final trackedAppsRevision = ValueNotifier<int>(0);

  /// Bumped once after a refresh has finished writing usage records.
  ///
  /// Insights is built inside HomeScreen's IndexedStack, so it is constructed
  /// *before* the first async read has written anything — it used to render an
  /// empty week and never reload, which looked like the tab was broken until
  /// the app was restarted. Home fires this when its writes are done.
  ///
  /// Deliberately not fired from the save methods themselves: the backfill
  /// writes a dozen days in a loop and would rebuild Insights on each one.
  static final statsRevision = ValueNotifier<int>(0);

  static void notifyStatsChanged() => statsRevision.value++;

  static List<String> get trackedApps =>
      (settings.get('tracked_apps', defaultValue: <String>[]) as List)
          .cast<String>();
  static set trackedApps(List<String> v) {
    settings.put('tracked_apps', v);
    trackedAppsRevision.value++;
  }

  static bool get notificationsEnabled =>
      settings.get('notifications_enabled', defaultValue: true) as bool;
  static set notificationsEnabled(bool v) =>
      settings.put('notifications_enabled', v);

  static int get notificationHour =>
      settings.get('notification_hour', defaultValue: 21) as int;
  static set notificationHour(int v) => settings.put('notification_hour', v);

  static int get notificationMinute =>
      settings.get('notification_minute', defaultValue: 0) as int;
  static set notificationMinute(int v) =>
      settings.put('notification_minute', v);

  /// The mood Rotto was last seen in, so a change can be announced exactly
  /// once. Null until the first refresh, which is deliberately silent — nobody
  /// wants a notification for "you are now Energetic" on install.
  static String? get lastNotifiedMood =>
      settings.get('last_notified_mood') as String?;
  static set lastNotifiedMood(String? v) =>
      settings.put('last_notified_mood', v);

  static bool get onboardingDone =>
      settings.get('onboarding_done', defaultValue: false) as bool;
  static set onboardingDone(bool v) => settings.put('onboarding_done', v);

  // Daily brainfog stats
  static Box<DailyBrainfogStats> get dailyBrainfogStats =>
      Hive.box<DailyBrainfogStats>(_dailyBrainfogStatsBox);

  static void saveDailyBrainfogStats(DailyBrainfogStats model) {
    dailyBrainfogStats.put(model.date, model);
    // Keep only last 30 days
    if (dailyBrainfogStats.length > 30) {
      final keys = dailyBrainfogStats.keys.toList()..sort();
      dailyBrainfogStats.delete(keys.first);
    }
  }

  static DailyBrainfogStats? getDailyBrainfogStats(String date) =>
      dailyBrainfogStats.get(date);

  static List<DailyBrainfogStats> getLast7Days() => getLastNDays(7);

  static List<DailyBrainfogStats> getPrevious7Days() =>
      _daysEndingOffsetAgo(7, 7);

  /// The last [n] days, oldest first, ending today. Days never recorded come
  /// back as zero-minute placeholders.
  static List<DailyBrainfogStats> getLastNDays(int n) =>
      _daysEndingOffsetAgo(0, n);

  /// Returns [count] days, oldest first, the newest being `offsetDays` ago
  /// (0 = today).
  static List<DailyBrainfogStats> _daysEndingOffsetAgo(
    int offsetDays,
    int count,
  ) {
    final now = DateTime.now();
    final result = <DailyBrainfogStats>[];
    for (int i = count - 1 + offsetDays; i >= offsetDays; i--) {
      final date = now.subtract(Duration(days: i));
      final key = dateKeyFor(date);
      result.add(
        dailyBrainfogStats.get(key) ??
            DailyBrainfogStats(
              date: key,
              totalMinutes: 0,
              brainfogScore: 0,
              trackedPackagesSnapshot: const [],
            ),
      );
    }
    return result;
  }

  // App usage
  static Box get appBrainfogUsage => Hive.box(_appBrainfogUsageBox);

  static void saveAppBrainfogUsageForDate(
    String date,
    List<AppBrainfogStats> apps,
  ) {
    final data = apps
        .map(
          (a) => {
            'appName': a.appName,
            'packageName': a.packageName,
            'minutes': a.minutes,
          },
        )
        .toList();
    appBrainfogUsage.put(date, data);
  }

  static List<AppBrainfogStats> getAppBrainfogUsageForDate(String date) {
    final raw = appBrainfogUsage.get(date);
    if (raw == null) return [];
    return (raw as List).map((e) {
      final m = e as Map;
      return AppBrainfogStats(
        appName: m['appName'] as String,
        packageName: m['packageName'] as String,
        minutes: m['minutes'] as int,
      );
    }).toList();
  }

  /// The `yyyy-MM-dd` key a day is stored and looked up under. Public so
  /// callers deriving a key for a specific [DateTime] (the backfill loop in
  /// `home_screen.dart`) use this instead of re-deriving the same format.
  static String dateKeyFor(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String get todayKey => dateKeyFor(DateTime.now());
}

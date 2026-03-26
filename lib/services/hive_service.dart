import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_usage_model.dart';
import '../models/daily_total_model.dart';

class HiveService {
  static const _settingsBox = 'settings';
  static const _dailyTotalsBox = 'daily_totals';
  static const _appUsageBox = 'app_usage';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(AppUsageModelAdapter());
    Hive.registerAdapter(DailyTotalModelAdapter());
    await Hive.openBox(_settingsBox);
    await Hive.openBox<DailyTotalModel>(_dailyTotalsBox);
    await Hive.openBox(_appUsageBox);
  }

  // Settings
  static Box get settings => Hive.box(_settingsBox);

  // Removed monthlySalary logic for a simpler 1:1 minute mapping

  static double get dailyBudget => settings.get('daily_budget', defaultValue: 150.0) as double;
  static set dailyBudget(double v) => settings.put('daily_budget', v);

  static List<String> get trackedApps => (settings.get('tracked_apps', defaultValue: <String>[]) as List).cast<String>();
  static set trackedApps(List<String> v) => settings.put('tracked_apps', v);

  static bool get notificationsEnabled => settings.get('notifications_enabled', defaultValue: true) as bool;
  static set notificationsEnabled(bool v) => settings.put('notifications_enabled', v);

  static int get notificationHour => settings.get('notification_hour', defaultValue: 21) as int;
  static set notificationHour(int v) => settings.put('notification_hour', v);

  static int get notificationMinute => settings.get('notification_minute', defaultValue: 0) as int;
  static set notificationMinute(int v) => settings.put('notification_minute', v);

  static bool get onboardingDone => settings.get('onboarding_done', defaultValue: false) as bool;
  static set onboardingDone(bool v) => settings.put('onboarding_done', v);

  // Daily totals
  static Box<DailyTotalModel> get dailyTotals => Hive.box<DailyTotalModel>(_dailyTotalsBox);

  static void saveDailyTotal(DailyTotalModel model) {
    dailyTotals.put(model.date, model);
    // Keep only last 30 days
    if (dailyTotals.length > 30) {
      final keys = dailyTotals.keys.toList()..sort();
      dailyTotals.delete(keys.first);
    }
  }

  static DailyTotalModel? getDailyTotal(String date) => dailyTotals.get(date);

  static List<DailyTotalModel> getLast7Days() {
    final now = DateTime.now();
    final result = <DailyTotalModel>[];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKey(date);
      result.add(dailyTotals.get(key) ?? DailyTotalModel(date: key, totalMoney: 0, totalMinutes: 0));
    }
    return result;
  }

  // App usage
  static Box get appUsage => Hive.box(_appUsageBox);

  static void saveAppUsageForDate(String date, List<AppUsageModel> apps) {
    final data = apps.map((a) => {
      'appName': a.appName,
      'packageName': a.packageName,
      'durationMinutes': a.durationMinutes,
      'moneyCost': a.moneyCost,
    }).toList();
    appUsage.put(date, data);
  }

  static List<AppUsageModel> getAppUsageForDate(String date) {
    final raw = appUsage.get(date);
    if (raw == null) return [];
    return (raw as List).map((e) {
      final m = e as Map;
      return AppUsageModel(
        appName: m['appName'] as String,
        packageName: m['packageName'] as String,
        durationMinutes: m['durationMinutes'] as int,
        moneyCost: m['moneyCost'] as double,
      );
    }).toList();
  }

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String get todayKey => _dateKey(DateTime.now());
}

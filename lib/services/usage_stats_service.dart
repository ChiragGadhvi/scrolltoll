import 'package:usage_stats/usage_stats.dart';
import 'package:flutter/services.dart';
import '../models/app_usage_model.dart';
import '../utils/money_calculator.dart';

import 'package:device_apps/device_apps.dart';

// System/launcher packages to exclude from the list
const _excludedPackages = {
  'com.android.systemui',
  'com.android.settings',
  'com.android.launcher',
  'com.android.launcher2',
  'com.android.launcher3',
  'com.google.android.launcher',
  'com.sec.android.app.launcher',
  'com.miui.home',
  'com.huawei.android.launcher',
  'com.oppo.launcher',
  'com.vivo.launcher',
  'com.oneplus.launcher',
  'com.android.phone',
  'com.android.dialer',
  'com.samsung.android.dialer',
  'com.android.incallui',
  'com.google.android.dialer',
  'com.android.inputmethod.latin',
  'com.google.android.inputmethod.latin',
  'com.samsung.android.honeyboard',
  'com.android.server.telecom',
  'android',
  'com.android.packageinstaller',
  'com.google.android.packageinstaller',
  'com.android.externalstorage',
  'com.android.documentsui',
  'com.android.calendar',
  'com.android.deskclock',
  'com.android.contacts',
  'com.android.mms',
  'com.android.messaging',
  'com.google.android.gms',
  'com.google.android.gsf',
  'com.google.android.gms.persistent',
  'com.motorola.mobiledesktop',
  'com.motorola.launcher3',
};

class UsageStatsService {
  static Future<bool> checkPermission() async {
    try {
      return await UsageStats.checkUsagePermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestPermission() async {
    await UsageStats.grantUsagePermission();
  }

  static Future<List<AppUsageModel>> getTodayUsage(double monthlySalary) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _getUsageBetween(startOfDay, now, monthlySalary);
  }

  static Future<List<AppUsageModel>> getUsageForDate(
      DateTime date, double monthlySalary) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _getUsageBetween(start, end, monthlySalary);
  }

  static Future<List<AppUsageModel>> _getUsageBetween(
      DateTime start, DateTime end, double monthlySalary) async {
    try {
      final stats = await UsageStats.queryUsageStats(start, end);
      
      final installedApps = await DeviceApps.getInstalledApplications(
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
        includeAppIcons: false,
      );
      final validLaunchableApps = {for (var app in installedApps) app.packageName};
      final realAppNames = {for (var app in installedApps) app.packageName: app.appName};

      final result = <AppUsageModel>[];

      for (final stat in stats) {
        final pkg = stat.packageName ?? '';
        if (_excludedPackages.contains(pkg)) continue;
        if (pkg.isEmpty) continue;
        
        // Exclude completely hidden background processes (those without generic launch intents)
        if (!validLaunchableApps.contains(pkg)) continue;

        final totalMs = int.tryParse(stat.totalTimeInForeground ?? '0') ?? 0;
        final minutes = (totalMs / 60000).round();
        if (minutes < 1) continue;

        // Use the OS actual app name for correctness, fallback if needed
        final appName = realAppNames[pkg] ?? _prettyName(pkg);
        final cost = MoneyCalculator.moneyCost(minutes, monthlySalary);

        result.add(AppUsageModel(
          appName: appName,
          packageName: pkg,
          durationMinutes: minutes,
          moneyCost: cost,
        ));
      }

      result.sort((a, b) => b.moneyCost.compareTo(a.moneyCost));
      return result;
    } on PlatformException {
      return [];
    }
  }

  static String _prettyName(String packageName) {
    const known = {
      'com.instagram.android': 'Instagram',
      'com.facebook.katana': 'Facebook',
      'com.twitter.android': 'Twitter / X',
      'com.zhiliaoapp.musically': 'TikTok',
      'com.snapchat.android': 'Snapchat',
      'com.whatsapp': 'WhatsApp',
      'com.google.android.youtube': 'YouTube',
      'com.netflix.mediaclient': 'Netflix',
      'com.spotify.music': 'Spotify',
      'com.amazon.mShop.android.shopping': 'Amazon',
      'in.amazon.mShop.android.shopping': 'Amazon',
      'com.flipkart.android': 'Flipkart',
      'com.reddit.frontpage': 'Reddit',
      'com.linkedin.android': 'LinkedIn',
      'com.google.android.apps.maps': 'Google Maps',
      'com.google.android.gm': 'Gmail',
      'com.google.android.chrome': 'Chrome',
      'org.mozilla.firefox': 'Firefox',
      'com.microsoft.launcher': 'Microsoft Launcher',
      'com.swiggy.android': 'Swiggy',
      'app.zomato': 'Zomato',
      'com.phonepe.app': 'PhonePe',
      'net.one97.paytm': 'Paytm',
      'com.google.android.apps.nbu.paisa.user': 'Google Pay',
    };
    if (known.containsKey(packageName)) return known[packageName]!;

    // Fall back to last segment of package name, title-cased
    final parts = packageName.split('.');
    final last = parts.last;
    return last[0].toUpperCase() + last.substring(1);
  }
}

import 'package:device_apps/device_apps.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:usage_stats/usage_stats.dart';

import '../models/app_brainfog_stats_model.dart';
import 'hive_service.dart';

/// Launchers, system UI, dialers and IMEs — never meaningful "screen time",
/// and since system apps are enumerated (so YouTube/Chrome/Gmail can be tracked
/// at all) this set is the only thing keeping them out of the picker.
/// Shared with TrackedAppsScreen so both paths filter identically.
const excludedPackages = {
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

/// One raw usage event: when it happened, what kind it was, and for which app.
typedef UsageEvent = ({int ts, int type, String pkg});

/// A single continuous stretch with an app in the foreground.
typedef AppSession = ({int start, int end});

/// How one app is actually used, beyond a daily total.
typedef AppSessionStats = ({int opens, int longestMs, int totalMs});

/// Reads Android's UsageStatsManager and turns it into per-app minutes.
///
/// ## Why this walks events instead of calling queryUsageStats
///
/// The usage_stats plugin's queryUsageStats asks Android with INTERVAL_BEST,
/// which returns **one row per time bucket** — so a single package comes back
/// several times, each row carrying the total for its whole bucket, and a
/// bucket can extend outside the window that was asked for. Summing those rows
/// (which this service used to do) inflates every figure, badly and
/// unpredictably. That was the "data is wrong" bug.
///
/// Walking the raw event stream gives the real thing: actual foreground
/// intervals, clamped to the window, which is how the platform's own wellbeing
/// screens compute it.
class UsageStatsService {
  // UsageEvents.Event constants. Kept local because the plugin hands them over
  // as bare strings without naming them.
  static const _evResumed = 1; // ACTIVITY_RESUMED
  static const _evPaused = 2; // ACTIVITY_PAUSED
  static const _evStopped = 23; // ACTIVITY_STOPPED
  static const _evScreenOff = 16; // SCREEN_NON_INTERACTIVE
  static const _evShutdown = 26; // DEVICE_SHUTDOWN

  /// Foreground time below this is a momentary app switch, not usage.
  static const _minSessionMs = 5000;

  static Future<bool> checkPermission() async {
    try {
      return await UsageStats.checkUsagePermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestPermission() async {
    try {
      await UsageStats.grantUsagePermission();
    } catch (_) {
      // Nothing useful to do if the settings intent will not launch; callers
      // already handle the still-denied case when the app resumes.
    }
  }

  static Future<List<AppBrainfogStats>> getTodayUsage() async {
    final now = DateTime.now();
    return _usageBetween(DateTime(now.year, now.month, now.day), now);
  }

  static Future<List<AppBrainfogStats>> getUsageForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final dayEnd = start.add(const Duration(days: 1));
    final now = DateTime.now();
    // Never ask past the present: an end in the future made a partial day look
    // like a whole one.
    return _usageBetween(start, dayEnd.isAfter(now) ? now : dayEnd);
  }

  /// Onboarding needs the unfiltered 7-day picture to suggest apps, so it skips
  /// the tracked-apps gate. Everything else about the read is identical — this
  /// used to be a near-verbatim copy of [_usageBetween].
  static Future<List<AppBrainfogStats>> getRawUsageForOnboarding() {
    final now = DateTime.now();
    return _usageBetween(
      now.subtract(const Duration(days: 7)),
      now,
      onlyTracked: false,
    );
  }

  static Future<List<AppBrainfogStats>> _usageBetween(
    DateTime start,
    DateTime end, {
    bool onlyTracked = true,
  }) async {
    if (!end.isAfter(start)) return [];
    try {
      // The event walk and the installed-app enumeration read unrelated data.
      // Starting both futures before awaiting either lets them run
      // concurrently — Dart begins an async call's work immediately, not on
      // first `await`, so this needs no Future.wait.
      final eventsFuture = _msFromEvents(start, end);
      final installedFuture = DeviceApps.getInstalledApplications(
        includeSystemApps: true,
        onlyAppsWithLaunchIntent: true,
        includeAppIcons: false,
      );
      final msPerPackage = await eventsFuture;
      final installed = await installedFuture;
      if (msPerPackage.isEmpty) return [];

      // No window can contain more time than it spans. Anything over that is a
      // platform artefact, not usage, and clamping here is what stops a single
      // day ever reporting something impossible like 30h.
      final windowMs = end.difference(start).inMilliseconds;

      final launchable = {for (final a in installed) a.packageName};
      final realNames = {for (final a in installed) a.packageName: a.appName};
      final tracked = onlyTracked ? HiveService.trackedApps.toSet() : null;

      final result = <AppBrainfogStats>[];
      msPerPackage.forEach((pkg, ms) {
        if (excludedPackages.contains(pkg)) return;
        if (!launchable.contains(pkg)) return;
        if (tracked != null && !tracked.contains(pkg)) return;
        if (ms < _minSessionMs) return;
        final bounded = ms > windowMs ? windowMs : ms;
        result.add(
          AppBrainfogStats(
            appName: realNames[pkg] ?? _prettyName(pkg),
            packageName: pkg,
            minutes: (bounded / 60000).round(),
          ),
        );
      });

      result.sort((a, b) => b.minutes.compareTo(a.minutes));
      return result;
    } on PlatformException {
      return [];
    } on MissingPluginException {
      // No platform side: widget tests, or any non-Android host. This used to
      // escape uncaught, because MissingPluginException does not extend
      // PlatformException.
      return [];
    }
  }

  /// Real foreground milliseconds per package, from the raw event stream.
  static Future<Map<String, int>> _msFromEvents(
    DateTime start,
    DateTime end,
  ) async {
    final parsed = _parseEvents(await UsageStats.queryEvents(start, end));
    return foldEvents(
      parsed,
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    );
  }

  /// Turns an event stream into foreground milliseconds per package.
  ///
  /// Pure and platform-free so it can be tested directly: this is the
  /// arithmetic that replaced the bucket-summing which inflated every figure.
  @visibleForTesting
  static Map<String, int> foldEvents(
    List<UsageEvent> events,
    int startMs,
    int endMs,
  ) {
    final totals = <String, int>{};
    foldSessions(events, startMs, endMs).forEach((pkg, sessions) {
      totals[pkg] = sessions.fold(0, (sum, s) => sum + (s.end - s.start));
    });
    return totals;
  }

  /// The individual foreground stretches per package, clamped to the window.
  ///
  /// [foldEvents] is just the sum of these, so there is one walk of the event
  /// stream and one set of session rules to reason about.
  @visibleForTesting
  static Map<String, List<AppSession>> foldSessions(
    List<UsageEvent> events,
    int startMs,
    int endMs,
  ) {
    // queryEvents is documented as ordered and the arithmetic below depends on
    // that, so this is cheap insurance rather than trust.
    final parsed = List<UsageEvent>.of(events)
      ..sort((a, b) => a.ts.compareTo(b.ts));

    final sessions = <String, List<AppSession>>{};
    final openSince = <String, int>{};

    void close(String pkg, int at) {
      final since = openSince.remove(pkg);
      if (since == null) return;
      final from = since.clamp(startMs, endMs);
      final to = at.clamp(startMs, endMs);
      if (to > from) (sessions[pkg] ??= []).add((start: from, end: to));
    }

    void closeAll(int at) {
      for (final pkg in openSince.keys.toList()) {
        close(pkg, at);
      }
    }

    for (final e in parsed) {
      switch (e.type) {
        case _evResumed:
          // Only one app is genuinely foreground. If a previous one never got
          // its pause event, close it here instead of letting it run forever.
          for (final pkg in openSince.keys.toList()) {
            if (pkg != e.pkg) close(pkg, e.ts);
          }
          openSince[e.pkg] ??= e.ts;
        case _evPaused:
        case _evStopped:
          close(e.pkg, e.ts);
        case _evScreenOff:
        case _evShutdown:
          // Screen off ends every session: a phone put down on an open app is
          // not screen time.
          closeAll(e.ts);
      }
    }

    // A session still open at the window's edge counts up to it — for today
    // that edge is now, which is what keeps a live total honest.
    closeAll(endMs);
    return sessions;
  }

  /// How [packageName] has actually been used over the last [days] days.
  ///
  /// Unlike the daily totals this reads events directly, so it only covers the
  /// window Android still retains detail for. Returns zeros rather than
  /// throwing when there is nothing to report.
  static Future<AppSessionStats> sessionStatsFor(
    String packageName, {
    int days = 7,
  }) async {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    const empty = (opens: 0, longestMs: 0, totalMs: 0);

    try {
      final events = _parseEvents(await UsageStats.queryEvents(start, now));
      final sessions =
          foldSessions(
            events,
            start.millisecondsSinceEpoch,
            now.millisecondsSinceEpoch,
          )[packageName] ??
          const <AppSession>[];
      if (sessions.isEmpty) return empty;

      var longest = 0;
      var total = 0;
      for (final s in sessions) {
        final length = s.end - s.start;
        total += length;
        if (length > longest) longest = length;
      }

      return (opens: sessions.length, longestMs: longest, totalMs: total);
    } on PlatformException {
      return empty;
    } on MissingPluginException {
      return empty;
    }
  }

  static List<UsageEvent> _parseEvents(List<EventUsageInfo> raw) {
    final parsed = <UsageEvent>[];
    for (final e in raw) {
      final ts = int.tryParse(e.timeStamp ?? '');
      final type = int.tryParse(e.eventType ?? '');
      final pkg = e.packageName ?? '';
      if (ts == null || type == null || pkg.isEmpty) continue;
      parsed.add((ts: ts, type: type, pkg: pkg));
    }
    return parsed;
  }

  /// Display names for [packages], for tracked apps that have no usage yet.
  ///
  /// Falls back to [_prettyName] for anything DeviceApps cannot resolve, so a
  /// row always has a label.
  static Future<Map<String, String>> resolveAppNames(
    List<String> packages,
  ) async {
    if (packages.isEmpty) return {};
    // Independent per-package lookups — resolving N tracked-but-unused apps
    // sequentially meant N platform-channel round trips end to end.
    final resolved = await Future.wait(
      packages.map((pkg) async {
        try {
          final app = await DeviceApps.getApp(pkg);
          return MapEntry(pkg, app?.appName ?? _prettyName(pkg));
        } catch (_) {
          return MapEntry(pkg, _prettyName(pkg));
        }
      }),
    );
    return Map.fromEntries(resolved);
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
    final pretty = known[packageName];
    if (pretty != null) return pretty;

    // Fall back to the last segment of the package name, title-cased.
    final last = packageName.split('.').last;
    if (last.isEmpty) return packageName;
    return last[0].toUpperCase() + last.substring(1);
  }
}

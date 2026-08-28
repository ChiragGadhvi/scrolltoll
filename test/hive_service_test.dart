import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:scrolltoll/models/app_brainfog_stats_model.dart';
import 'package:scrolltoll/models/daily_brainfog_stats_model.dart';
import 'package:scrolltoll/services/hive_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('brainfog_hive_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(DailyBrainfogStatsAdapter());
    }
    await Hive.openBox('settings');
    await Hive.openBox<DailyBrainfogStats>('daily_brainfog_stats');
    await Hive.openBox('app_brainfog_usage');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('tracked apps persist across a box close/reopen', () async {
    HiveService.trackedApps = [
      'com.instagram.android',
      'com.google.android.youtube',
    ];

    await Hive.box('settings').close();
    await Hive.openBox('settings');

    expect(HiveService.trackedApps, [
      'com.instagram.android',
      'com.google.android.youtube',
    ]);
  });

  test('daily brainfog stats round-trip through the typed box', () {
    final stats = DailyBrainfogStats(
      date: '2026-08-20',
      totalMinutes: 120,
      brainfogScore: 70,
      trackedPackagesSnapshot: ['com.instagram.android'],
    );

    HiveService.saveDailyBrainfogStats(stats);
    final loaded = HiveService.getDailyBrainfogStats('2026-08-20');

    expect(loaded, isNotNull);
    expect(loaded!.totalMinutes, 120);
    expect(loaded.brainfogScore, 70);
    expect(loaded.trackedPackagesSnapshot, ['com.instagram.android']);
  });

  test('app brainfog usage round-trips through manual map serialization', () {
    HiveService.saveAppBrainfogUsageForDate('2026-08-20', [
      AppBrainfogStats(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        minutes: 161,
      ),
    ]);

    final loaded = HiveService.getAppBrainfogUsageForDate('2026-08-20');

    expect(loaded, hasLength(1));
    expect(loaded.first.packageName, 'com.instagram.android');
    expect(loaded.first.minutes, 161);
  });
}

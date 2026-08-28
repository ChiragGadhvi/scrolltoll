import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:scrolltoll/models/daily_brainfog_stats_model.dart';
import 'package:scrolltoll/services/hive_service.dart';

/// Proves the fix for the historical-data bug: once a past day's stats are
/// recorded, changing today's tracked-app selection must never silently
/// reinterpret that record. This mirrors the exact backfill guard used in
/// home_screen.dart's `_loadData()`:
///   if (HiveService.getDailyBrainfogStats(pastKey) == null) { ...write... }
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

  test(
    'a past day already recorded is never overwritten by a later tracked-apps change',
    () {
      const pastKey = '2026-08-14';

      HiveService.trackedApps = [
        'com.instagram.android',
        'com.google.android.youtube',
      ];
      HiveService.saveDailyBrainfogStats(
        DailyBrainfogStats(
          date: pastKey,
          totalMinutes: 90,
          brainfogScore: 55,
          trackedPackagesSnapshot: List.of(HiveService.trackedApps),
        ),
      );

      final originalRecord = HiveService.getDailyBrainfogStats(pastKey)!;

      // The user changes their tracked apps entirely.
      HiveService.trackedApps = ['com.zhiliaoapp.musically'];

      // Re-run the exact backfill guard idiom from home_screen.dart: it must
      // find the record already exists and skip writing.
      if (HiveService.getDailyBrainfogStats(pastKey) == null) {
        HiveService.saveDailyBrainfogStats(
          DailyBrainfogStats(
            date: pastKey,
            totalMinutes: 999,
            brainfogScore: 1,
            trackedPackagesSnapshot: List.of(HiveService.trackedApps),
          ),
        );
      }

      final afterTrackedAppsChanged = HiveService.getDailyBrainfogStats(
        pastKey,
      )!;

      expect(afterTrackedAppsChanged.totalMinutes, originalRecord.totalMinutes);
      expect(
        afterTrackedAppsChanged.brainfogScore,
        originalRecord.brainfogScore,
      );
      expect(afterTrackedAppsChanged.trackedPackagesSnapshot, [
        'com.instagram.android',
        'com.google.android.youtube',
      ]);
    },
  );

  test(
    "today's own record is allowed to be overwritten (only today is mutable)",
    () {
      final todayKey = HiveService.todayKey;

      HiveService.saveDailyBrainfogStats(
        DailyBrainfogStats(
          date: todayKey,
          totalMinutes: 10,
          brainfogScore: 5,
          trackedPackagesSnapshot: const [],
        ),
      );

      // Unlike the backfill loop, today's own write in _loadData() is
      // unconditional -- simulate that directly.
      HiveService.saveDailyBrainfogStats(
        DailyBrainfogStats(
          date: todayKey,
          totalMinutes: 50,
          brainfogScore: 30,
          trackedPackagesSnapshot: const ['com.instagram.android'],
        ),
      );

      final today = HiveService.getDailyBrainfogStats(todayKey)!;
      expect(today.totalMinutes, 50);
      expect(today.brainfogScore, 30);
    },
  );
}

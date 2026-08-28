import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:scrolltoll/services/hive_service.dart';

/// Regression test for the "I added an app and Home didn't show it" bug.
///
/// Home caches today's usage and only reloaded on lifecycle resume or midnight,
/// neither of which fires when returning from the tracked-apps picker. The
/// revision notifier is what wakes it up, so writing trackedApps must bump it.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rotto_revision_test');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('writing trackedApps bumps the revision notifier', () {
    final seen = <int>[];
    void listener() => seen.add(HiveService.trackedAppsRevision.value);
    HiveService.trackedAppsRevision.addListener(listener);
    addTearDown(() => HiveService.trackedAppsRevision.removeListener(listener));

    final before = HiveService.trackedAppsRevision.value;
    HiveService.trackedApps = ['com.google.android.youtube'];
    HiveService.trackedApps = ['com.google.android.youtube', 'com.whatsapp'];

    expect(seen.length, 2, reason: 'each write should notify exactly once');
    expect(HiveService.trackedAppsRevision.value, before + 2);
    expect(HiveService.trackedApps, hasLength(2));
  });

  test('reading trackedApps does not bump the revision', () {
    final before = HiveService.trackedAppsRevision.value;
    HiveService.trackedApps;
    HiveService.trackedApps;
    expect(HiveService.trackedAppsRevision.value, before);
  });
}

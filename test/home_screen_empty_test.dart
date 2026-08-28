import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:scrolltoll/models/daily_brainfog_stats_model.dart';
import 'package:scrolltoll/screens/home_screen.dart';
import 'package:scrolltoll/theme/app_theme.dart';

void main() {
  late Directory tempDir;
  const usageStatsChannel = MethodChannel('usage_stats');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('brainfog_hive_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(DailyBrainfogStatsAdapter());
    }
    await Hive.openBox('settings');
    await Hive.openBox<DailyBrainfogStats>('daily_brainfog_stats');
    await Hive.openBox('app_brainfog_usage');

    // Deterministically answer "no usage-access permission" instead of
    // relying on the no-handler MissingPluginException path, which needs a
    // real event-loop turn that plain pump() doesn't service.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(usageStatsChannel, (call) async {
          if (call.method == 'checkUsagePermission') return false;
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(usageStatsChannel, null);
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
    'HomeScreen renders its permission-missing state without crashing '
    'when there are no tracked apps and no platform channel available',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      );
      // Not pumpAndSettle(): the initial loading state renders an indeterminate
      // CircularProgressIndicator, which schedules frames forever by design and
      // would make pumpAndSettle() time out. Pump a bounded number of times
      // instead, enough for the async permission check to resolve.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
      expect(find.text('Usage Access Required'), findsOneWidget);

      // Replace the tree so HomeScreen disposes cleanly (cancels its timers).
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

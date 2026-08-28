import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:scrolltoll/models/daily_brainfog_stats_model.dart';
import 'package:scrolltoll/screens/onboarding_screen.dart';
import 'package:scrolltoll/theme/app_theme.dart';

void main() {
  late Directory tempDir;

  // OnboardingScreen writes tracked apps and the onboarding flag through
  // HiveService, so the settings box has to exist — exactly as main()
  // guarantees on a real launch.
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('brainfog_hive_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(DailyBrainfogStatsAdapter());
    }
    await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Not pumpAndSettle(): the welcome page runs Rotto's idle bob on
  /// `repeat(reverse: true)`, which schedules frames forever by design and
  /// would make pumpAndSettle() time out. Pump a bounded number of frames
  /// instead — enough for the entry animations and any page transition to
  /// finish. Same reasoning as home_screen_empty_test.dart.
  Future<void> settleFrames(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const OnboardingScreen()),
    );
    await settleFrames(tester);
  }

  testWidgets('onboarding opens on the "meet Rotto" page', (tester) async {
    await pumpOnboarding(tester);

    expect(find.textContaining('MEET'), findsOneWidget);
    expect(find.textContaining('ROTTO.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Say hello'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the second page explains private Usage Access', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Say hello'));
    await settleFrames(tester);

    expect(find.text('Stays on your phone'), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Allow Usage Access'),
      findsOneWidget,
    );
    // Skipping the permission must remain possible.
    expect(find.widgetWithText(TextButton, 'Maybe later'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

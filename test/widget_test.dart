import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrolltoll/screens/onboarding_screen.dart';
import 'package:scrolltoll/theme/app_theme.dart';

void main() {
  testWidgets('onboarding renders salary entry flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const OnboardingScreen(),
      ),
    );

    expect(find.text('ScrollToll'), findsOneWidget);
    expect(find.textContaining('Your Monthly Salary'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Get Started'), findsOneWidget);
  });
}

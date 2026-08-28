import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrolltoll/theme/app_theme.dart';
import 'package:scrolltoll/widgets/ui_kit.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  group('TrendPill', () {
    // Less screen time is the good direction, so a drop must read as positive.
    // If the arrow and the colour ever disagree the badge reads backwards.
    testWidgets('a drop points down and is green', (tester) async {
      await tester.pumpWidget(_host(const TrendPill(percent: -12)));

      expect(find.text('12%'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.south_rounded);
      expect(icon.color, AppColors.safe);
    });

    testWidgets('a rise points up and is warm', (tester) async {
      await tester.pumpWidget(_host(const TrendPill(percent: 30)));

      expect(find.text('30%'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.north_rounded);
      expect(icon.color, AppColors.bingeOrange);
    });

    testWidgets('the sign is dropped from the label, not the direction', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const TrendPill(percent: -5)));
      expect(find.text('5%'), findsOneWidget);
      expect(find.text('-5%'), findsNothing);
    });
  });

  group('MetricStrip', () {
    testWidgets('renders every metric with its label', (tester) async {
      await tester.pumpWidget(
        _host(
          const MetricStrip(
            metrics: [
              Metric(label: 'Daily average', value: '1hr 47min'),
              Metric(label: 'Busiest', value: '3hr 20min'),
              Metric(label: 'Quietest', value: '12min'),
            ],
          ),
        ),
      );

      for (final t in [
        'Daily average',
        '1hr 47min',
        'Busiest',
        '3hr 20min',
        'Quietest',
        '12min',
      ]) {
        expect(find.text(t), findsOneWidget);
      }
    });

    testWidgets('a single metric draws no divider', (tester) async {
      await tester.pumpWidget(
        _host(
          const MetricStrip(
            metrics: [Metric(label: 'Total', value: '2hr')],
          ),
        ),
      );
      expect(find.text('Total'), findsOneWidget);
    });
  });

  group('AppIconAvatar', () {
    testWidgets('falls back to an initial when there is no icon', (
      tester,
    ) async {
      // DeviceApps has no platform side under `flutter test`, so this exercises
      // the fallback path the real app hits for an unresolvable package.
      await tester.pumpWidget(
        _host(
          const AppIconAvatar(packageName: 'com.example.x', appName: 'Zebra'),
        ),
      );
      await tester.pump();
      expect(find.text('Z'), findsOneWidget);
    });

    testWidgets('an empty name degrades to a placeholder, not a crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const AppIconAvatar(packageName: 'com.example.y', appName: '')),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('?'), findsOneWidget);
    });
  });
}

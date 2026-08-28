import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrolltoll/theme/app_theme.dart';

/// Light is the only theme, and Poppins is bundled rather than fetched. Both of
/// those are easy to regress silently, so they get pinned here.
void main() {
  double luminance(Color c) => c.computeLuminance();

  group('palette', () {
    test('is a light theme: dark text on light surfaces', () {
      expect(luminance(AppColors.card), greaterThan(0.8));
      expect(luminance(AppColors.background), greaterThan(0.8));
      expect(luminance(AppColors.textPrimary), lessThan(0.1));
    });

    test('text stays readable against the card', () {
      final bg = luminance(AppColors.card);
      expect((luminance(AppColors.textPrimary) - bg).abs(), greaterThan(0.4));
      // Tertiary is intentionally faint, but must not vanish into the card.
      expect((luminance(AppColors.textTertiary) - bg).abs(), greaterThan(0.08));
    });

    test('the mood ramp runs green to red, in order', () {
      // The single severity ladder, mirrored in BrainfogWidgetProvider.kt.
      // Ordering matters: a worse mood must never look calmer than a better one.
      const ramp = [
        AppColors.safe,
        AppColors.safeDim,
        AppColors.warning,
        AppColors.bingeOrange,
        AppColors.danger,
      ];
      // Neither channel alone is monotonic (danger is *less* red than binge
      // orange), so the invariant is the balance between them: how much greener
      // than red each rung is must fall strictly, all the way down.
      double greenBias(Color c) => c.g - c.r;
      for (var i = 1; i < ramp.length; i++) {
        expect(
          greenBias(ramp[i]),
          lessThan(greenBias(ramp[i - 1])),
          reason: 'rung $i is not warmer than rung ${i - 1}',
        );
      }
      expect(greenBias(ramp.first), greaterThan(0)); // safe reads green
      expect(greenBias(ramp.last), lessThan(0)); // danger reads red
    });
  });

  group('ThemeData', () {
    testWidgets('is light and uses the bundled Poppins', (tester) async {
      final theme = AppTheme.light;
      expect(theme.brightness, Brightness.light);
      // If this ever reverts to google_fonts the family becomes a generated
      // name like "Poppins_regular" and the release build loses its font.
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Poppins');
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Poppins');
    });

    testWidgets('scaffold and surfaces come from the palette', (tester) async {
      final theme = AppTheme.light;
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.surface, AppColors.card);
    });
  });
}

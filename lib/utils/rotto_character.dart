import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'rotto_score.dart';

/// How Rotto presents himself for a given [RottoState].
///
/// Home, the weekly chart, the tracked-app tiles and the Android home widget
/// all render the character, so his art, name, caption and colour are defined
/// once here. Every string is upbeat or matter-of-fact — Rotto reacts to the
/// day, he never scolds the user for it.
class RottoCharacter {
  /// Everything about one mood, keyed once instead of across four parallel
  /// maps. Colour ramp reads best-to-worst in [RottoState] order, so a
  /// falling score always moves toward red.
  static const _moods =
      <RottoState, ({String asset, String name, String caption, Color color})>{
        RottoState.energetic: (
          asset: 'assets/rotto_energetic.png',
          name: 'Energetic',
          caption: 'Rotto is bouncing off the walls.',
          color: AppColors.safe,
        ),
        RottoState.scrolling: (
          asset: 'assets/rotto_scrolling.png',
          name: 'Scrolling',
          caption: 'Rotto is settling in for a scroll.',
          color: AppColors.safeDim,
        ),
        RottoState.tired: (
          asset: 'assets/rotto_tired.png',
          name: 'Tired',
          caption: 'Rotto is starting to droop.',
          color: AppColors.warning,
        ),
        RottoState.bingeMode: (
          asset: 'assets/rotto_bingemode.png',
          name: 'Binge Mode',
          caption: 'Rotto has fully committed to the feed.',
          color: AppColors.bingeOrange,
        ),
        RottoState.noEnergy: (
          asset: 'assets/rotto_noenergy.png',
          name: 'No Energy',
          caption: 'Rotto is out of energy. Tomorrow he resets.',
          color: AppColors.danger,
        ),
      };

  static String assetFor(RottoState state) => _moods[state]!.asset;

  static String nameFor(RottoState state) => _moods[state]!.name;

  static String captionFor(RottoState state) => _moods[state]!.caption;

  static Color colorFor(RottoState state) => _moods[state]!.color;

  /// The Android drawable resource name backing [assetFor] — the same asset,
  /// without the `assets/` prefix or extension. Used wherever a drawable name
  /// is needed directly (notifications), so there is one mood→art mapping,
  /// not a second copy re-deriving Android resource names.
  static String drawableNameFor(RottoState state) =>
      _moods[state]!.asset.split('/').last.replaceAll('.png', '');
}

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
  ///
  /// `animatedAsset` is a looping WebP — Flutter's `Image.asset` plays it
  /// natively, no extra package, and it's what every in-app placement uses
  /// (including the coin chart and month calendar, each showing several at
  /// once). `stillAsset` is the original static PNG; nothing in `lib/` shows
  /// it directly any more, but it still backs [drawableNameFor], since the
  /// Android side (widget, notifications) has no concept of the animation at
  /// all — RemoteViews cannot play animated images, full stop, regardless of
  /// format.
  static const _moods =
      <
        RottoState,
        ({
          String animatedAsset,
          String stillAsset,
          String name,
          String caption,
          Color color,
        })
      >{
        RottoState.energetic: (
          animatedAsset: 'assets/rotto_energetic.webp',
          stillAsset: 'assets/rotto_energetic.png',
          name: 'Energetic',
          caption: 'Rotto is bouncing off the walls.',
          color: AppColors.safe,
        ),
        RottoState.scrolling: (
          animatedAsset: 'assets/rotto_scrolling.webp',
          stillAsset: 'assets/rotto_scrolling.png',
          name: 'Scrolling',
          caption: 'Rotto is settling in for a scroll.',
          color: AppColors.safeDim,
        ),
        RottoState.tired: (
          animatedAsset: 'assets/rotto_tired.webp',
          stillAsset: 'assets/rotto_tired.png',
          name: 'Tired',
          caption: 'Rotto is starting to droop.',
          color: AppColors.warning,
        ),
        RottoState.bingeMode: (
          animatedAsset: 'assets/rotto_bingemode.webp',
          stillAsset: 'assets/rotto_bingemode.png',
          name: 'Binge Mode',
          caption: 'Rotto has fully committed to the feed.',
          color: AppColors.bingeOrange,
        ),
        RottoState.noEnergy: (
          animatedAsset: 'assets/rotto_noenergy.webp',
          stillAsset: 'assets/rotto_noenergy.png',
          name: 'No Energy',
          caption: 'Rotto is out of energy. Tomorrow he resets.',
          color: AppColors.danger,
        ),
      };

  /// The looping animation Rotto renders as everywhere in the Flutter app.
  static String assetFor(RottoState state) => _moods[state]!.animatedAsset;

  static String nameFor(RottoState state) => _moods[state]!.name;

  static String captionFor(RottoState state) => _moods[state]!.caption;

  static Color colorFor(RottoState state) => _moods[state]!.color;

  /// The Android drawable resource name for the static PNG — without the
  /// `assets/` prefix or extension. Used wherever a drawable name is needed
  /// directly (notifications, the widget), so there is one mood→art mapping,
  /// not a second copy re-deriving Android resource names. Always the static
  /// PNG's name: the Android side cannot play the animated WebP at all.
  static String drawableNameFor(RottoState state) =>
      _moods[state]!.stillAsset.split('/').last.replaceAll('.png', '');
}

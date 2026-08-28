/// Rotto's energy score for a day: **100 is good, 0 is spent.**
///
/// The score counts *down* as tracked screen time goes up, so a high number is
/// always something to feel good about. It is derived purely from measured
/// foreground minutes in the apps the user chose to track — nothing is
/// estimated, and there is no user-set allowance.
///
/// This is the only severity ladder in the app: screens, the weekly chart and
/// the Android home widget all read from here.
class RottoScore {
  /// The one tunable knob. Screen time at or above this drains the score to 0.
  ///
  /// With even 20-point bands, this also fixes every state boundary. At 240
  /// the moods start at: energetic 0min, scrolling 50min, tired 1hr 38min,
  /// binge mode 2hr 26min, no energy 3hr 14min. (Verified by
  /// test/rotto_score_test.dart, which probes boundaries relative to this
  /// constant rather than hardcoding them.)
  static const drainedAtMinutes = 240;

  final int trackedMinutes;

  const RottoScore(this.trackedMinutes);

  /// 0-100, counting down. Clamped, so it never reads negative or above 100.
  int get score {
    final drained = (trackedMinutes / drainedAtMinutes).clamp(0.0, 1.0);
    return (100 - drained * 100).round();
  }

  /// How drained the day is, 0.0-1.0 — the mirror of [score].
  ///
  /// Note that progress bars do NOT fill on this: both the app and the home
  /// widget fill on [score], so full-and-green always reads as "good", like a
  /// game energy bar. This is used for pacing animations, not for bar widths.
  double get drainedFraction => (100 - score) / 100;

  /// Even 20-point bands over [score]. Ordered best to worst.
  RottoState get state {
    final s = score;
    if (s >= 80) return RottoState.energetic;
    if (s >= 60) return RottoState.scrolling;
    if (s >= 40) return RottoState.tired;
    if (s >= 20) return RottoState.bingeMode;
    return RottoState.noEnergy;
  }

  /// The first minute count at which each mood begins, in ladder order.
  ///
  /// Derived by walking the ladder rather than hardcoded, so retuning
  /// [drainedAtMinutes] moves these with it. Used by the Settings mood list, so
  /// what the app tells the user can never drift from what it computes.
  static Map<RottoState, int> get moodStartMinutes {
    final starts = <RottoState, int>{};
    for (var m = 0; m <= drainedAtMinutes; m++) {
      starts.putIfAbsent(RottoScore(m).state, () => m);
    }
    return starts;
  }

  /// Minutes of screen time before the next state down begins, or null when
  /// already at [RottoState.noEnergy]. Never zero or negative.
  int? get minutesUntilNextState {
    final nextBandFloor = switch (state) {
      RottoState.energetic => 80,
      RottoState.scrolling => 60,
      RottoState.tired => 40,
      RottoState.bingeMode => 20,
      RottoState.noEnergy => null,
    };
    if (nextBandFloor == null) return null;
    // The band ends on the first minute whose score drops below its floor.
    //
    // [score] rounds, so it falls under `floor` at the first minute where the
    // unrounded value is below `floor - 0.5`. Solving
    //   100 - 100*m/drainedAtMinutes < nextBandFloor - 0.5
    // gives m > drainedAtMinutes * (100.5 - floor) / 100, so the first such
    // minute is that value floored, plus one. The previous form used
    // `ceil((100 - floor + 1)/100 * drained)`, which overshot by a minute at
    // every band (it reported 51 where the mood actually turns at 50) and
    // disagreed with the thresholds documented above.
    final minutesAtFloor =
        (drainedAtMinutes * (100.5 - nextBandFloor) / 100).floor() + 1;
    final remaining = minutesAtFloor - trackedMinutes;
    return remaining > 0 ? remaining : 1;
  }
}

/// Rotto's five moods, best to worst. Order is meaningful — `index` doubles as
/// the severity rank.
enum RottoState { energetic, scrolling, tired, bingeMode, noEnergy }

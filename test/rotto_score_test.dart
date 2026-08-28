import 'package:flutter_test/flutter_test.dart';
import 'package:scrolltoll/utils/rotto_score.dart';

void main() {
  // Every boundary is expressed against RottoScore.drainedAtMinutes rather
  // than a hardcoded minute count, so retuning the single knob does not
  // invalidate the suite — only genuinely wrong behaviour fails.
  const drain = RottoScore.drainedAtMinutes;

  group('score counts down from 100', () {
    test('an untouched day scores a full 100', () {
      expect(const RottoScore(0).score, 100);
    });

    test('half the drain time scores about 50', () {
      expect(RottoScore(drain ~/ 2).score, closeTo(50, 1));
    });

    test('the drain mark scores exactly 0', () {
      expect(RottoScore(drain).score, 0);
    });

    test('past the drain mark the score floors at 0, never negative', () {
      expect(RottoScore(drain * 3).score, 0);
      expect(const RottoScore(99999).score, 0);
    });

    test('the score never exceeds 100 on degenerate input', () {
      // Usage minutes are never negative in practice; this is defensive.
      expect(const RottoScore(-500).score, 100);
    });

    test('more screen time never scores higher than less', () {
      var previous = 101;
      for (var m = 0; m <= drain + 60; m += 5) {
        final s = RottoScore(m).score;
        expect(s, lessThanOrEqualTo(previous), reason: 'at $m minutes');
        previous = s;
      }
    });
  });

  group('states map to even 20-point bands', () {
    RottoState stateFor(int score) {
      // Invert the score back to minutes to probe a specific band.
      final minutes = ((100 - score) / 100 * drain).round();
      return RottoScore(minutes).state;
    }

    test('100 is energetic', () => expect(stateFor(100), RottoState.energetic));
    test('80 is energetic', () => expect(stateFor(80), RottoState.energetic));
    test('79 is scrolling', () => expect(stateFor(79), RottoState.scrolling));
    test('60 is scrolling', () => expect(stateFor(60), RottoState.scrolling));
    test('59 is tired', () => expect(stateFor(59), RottoState.tired));
    test('40 is tired', () => expect(stateFor(40), RottoState.tired));
    test('39 is binge mode', () => expect(stateFor(39), RottoState.bingeMode));
    test('20 is binge mode', () => expect(stateFor(20), RottoState.bingeMode));
    test('19 is no energy', () => expect(stateFor(19), RottoState.noEnergy));
    test('0 is no energy', () => expect(stateFor(0), RottoState.noEnergy));

    test('states worsen monotonically as time climbs', () {
      var previous = -1;
      for (var m = 0; m <= drain; m += 5) {
        final rank = RottoScore(m).state.index;
        expect(rank, greaterThanOrEqualTo(previous), reason: 'at $m minutes');
        previous = rank;
      }
      // And the full range is actually reachable.
      expect(const RottoScore(0).state, RottoState.energetic);
      expect(RottoScore(drain).state, RottoState.noEnergy);
    });
  });

  group('drainedFraction', () {
    test('is the mirror of the score', () {
      expect(const RottoScore(0).drainedFraction, 0.0);
      expect(RottoScore(drain).drainedFraction, 1.0);
      expect(RottoScore(drain ~/ 2).drainedFraction, closeTo(0.5, 0.01));
    });

    test('stays within 0-1 past the drain mark', () {
      expect(RottoScore(drain * 5).drainedFraction, 1.0);
      expect(const RottoScore(-100).drainedFraction, 0.0);
    });
  });

  group('minutesUntilNextState', () {
    test('is null only at the worst state', () {
      expect(RottoScore(drain).minutesUntilNextState, null);
      expect(const RottoScore(0).minutesUntilNextState, isNotNull);
    });

    test('is always positive while a next state exists', () {
      for (var m = 0; m <= drain + 30; m++) {
        final level = RottoScore(m);
        final remaining = level.minutesUntilNextState;
        if (level.state == RottoState.noEnergy) {
          expect(remaining, null, reason: 'at $m minutes');
        } else {
          expect(remaining, greaterThan(0), reason: 'at $m minutes');
        }
      }
    });

    test('waiting out the countdown really does change the state', () {
      for (final start in [0, 30, 90, 150, 200]) {
        final level = RottoScore(start);
        final wait = level.minutesUntilNextState;
        if (wait == null) continue;
        final later = RottoScore(start + wait);
        expect(
          later.state.index,
          greaterThan(level.state.index),
          reason: 'from $start minutes, waiting $wait',
        );
      }
    });
  });

  // The suite above probes boundaries by inverting the score formula, which
  // means a rounding bug would shift both the probe and the result together and
  // stay invisible. These pin the concrete numbers the class doc-comment (and
  // the Settings FAQ) promise, in the form the rest of the app actually calls.
  group('concrete minute thresholds', () {
    test('state at raw minute counts matches the documented ladder', () {
      expect(RottoScore(0).state, RottoState.energetic);
      expect(RottoScore(49).state, RottoState.energetic);
      expect(RottoScore(50).state, RottoState.scrolling);
      expect(RottoScore(97).state, RottoState.scrolling);
      expect(RottoScore(98).state, RottoState.tired);
      expect(RottoScore(145).state, RottoState.tired);
      expect(RottoScore(146).state, RottoState.bingeMode);
      expect(RottoScore(193).state, RottoState.bingeMode);
      expect(RottoScore(194).state, RottoState.noEnergy);
    });

    test('score at raw minute counts', () {
      expect(RottoScore(0).score, 100);
      expect(RottoScore(60).score, 75);
      expect(RottoScore(120).score, 50);
      expect(RottoScore(180).score, 25);
      expect(RottoScore(240).score, 0);
    });

    test('minutesUntilNextState returns the real distance, not a fallback', () {
      // Pinned so the ceil() arithmetic cannot drift unnoticed; the existing
      // tests only assert it is positive.
      // These are exactly the thresholds the class doc-comment and CLAUDE.md
      // promise: scrolling at 50min, tired at 98, binge at 146, spent at 194.
      expect(RottoScore(0).minutesUntilNextState, 50);
      expect(RottoScore(49).minutesUntilNextState, 1);
      expect(RottoScore(50).minutesUntilNextState, 48);
      expect(RottoScore(98).minutesUntilNextState, 48);
      expect(RottoScore(146).minutesUntilNextState, 48);
      expect(RottoScore(193).minutesUntilNextState, 1);
      expect(RottoScore(194).minutesUntilNextState, isNull);
    });

    test('landing exactly on a boundary reports the better mood', () {
      // The FAQ wording depends on this: a score of exactly 80 is Energetic,
      // not Scrolling.
      expect(RottoScore(48).score, 80);
      expect(RottoScore(48).state, RottoState.energetic);
    });
  });

  // The Settings mood list renders straight from this, so a wrong value here is
  // the app telling the user something it does not itself believe.
  group('moodStartMinutes', () {
    test('covers every mood exactly once', () {
      final starts = RottoScore.moodStartMinutes;
      expect(starts.keys.toSet(), RottoState.values.toSet());
    });

    test('matches the documented thresholds', () {
      final starts = RottoScore.moodStartMinutes;
      expect(starts[RottoState.energetic], 0);
      expect(starts[RottoState.scrolling], 50);
      expect(starts[RottoState.tired], 98);
      expect(starts[RottoState.bingeMode], 146);
      expect(starts[RottoState.noEnergy], 194);
    });

    test('each start really is that mood, and one minute earlier is not', () {
      final starts = RottoScore.moodStartMinutes;
      for (final entry in starts.entries) {
        expect(RottoScore(entry.value).state, entry.key);
        if (entry.value > 0) {
          expect(
            RottoScore(entry.value - 1).state,
            isNot(entry.key),
            reason:
                '${entry.key} should not already hold at ${entry.value - 1}',
          );
        }
      }
    });

    test('starts ascend in ladder order', () {
      final starts = RottoScore.moodStartMinutes;
      for (var i = 1; i < RottoState.values.length; i++) {
        expect(
          starts[RottoState.values[i]]!,
          greaterThan(starts[RottoState.values[i - 1]]!),
        );
      }
    });
  });
}

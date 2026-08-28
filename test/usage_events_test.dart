import 'package:flutter_test/flutter_test.dart';
import 'package:scrolltoll/services/usage_stats_service.dart';

/// Tests for the event arithmetic that replaced `queryUsageStats`.
///
/// The old code summed Android's INTERVAL_BEST rows, so one package spread over
/// several buckets got counted several times and every figure came out inflated.
/// These lock in the real behaviour: measured intervals, clamped to the window.
void main() {
  // A fixed, readable window: 0 to 60 minutes.
  const start = 0;
  const end = 60 * 60 * 1000;

  int min(int m) => m * 60 * 1000;

  const resumed = 1;
  const paused = 2;
  const stopped = 23;
  const screenOff = 16;

  group('foldEvents', () {
    test('a single closed session counts its own length', () {
      final totals = UsageStatsService.foldEvents(
        [
          (ts: min(5), type: resumed, pkg: 'a'),
          (ts: min(15), type: paused, pkg: 'a'),
        ],
        start,
        end,
      );

      expect(totals, {'a': min(10)});
    });

    test('separate sessions of one app add up', () {
      final totals = UsageStatsService.foldEvents(
        [
          (ts: min(0), type: resumed, pkg: 'a'),
          (ts: min(5), type: paused, pkg: 'a'),
          (ts: min(20), type: resumed, pkg: 'a'),
          (ts: min(30), type: paused, pkg: 'a'),
        ],
        start,
        end,
      );

      expect(totals, {'a': min(15)});
    });

    test('two apps are measured independently', () {
      final totals = UsageStatsService.foldEvents(
        [
          (ts: min(0), type: resumed, pkg: 'a'),
          (ts: min(10), type: paused, pkg: 'a'),
          (ts: min(10), type: resumed, pkg: 'b'),
          (ts: min(40), type: paused, pkg: 'b'),
        ],
        start,
        end,
      );

      expect(totals, {'a': min(10), 'b': min(30)});
    });

    test('a repeated resume does not restart or double count', () {
      // This is the shape that used to inflate everything.
      final totals = UsageStatsService.foldEvents(
        [
          (ts: min(0), type: resumed, pkg: 'a'),
          (ts: min(3), type: resumed, pkg: 'a'),
          (ts: min(6), type: resumed, pkg: 'a'),
          (ts: min(10), type: paused, pkg: 'a'),
        ],
        start,
        end,
      );

      expect(totals, {'a': min(10)});
    });

    test('one app resuming closes another that never paused', () {
      // Without this, a missing pause event would leave the first app running
      // for the rest of the window.
      final totals = UsageStatsService.foldEvents(
        [
          (ts: min(0), type: resumed, pkg: 'a'),
          (ts: min(10), type: resumed, pkg: 'b'),
          (ts: min(20), type: paused, pkg: 'b'),
        ],
        start,
        end,
      );

      expect(totals, {'a': min(10), 'b': min(10)});
    });

    test('screen off ends the session', () {
      // A phone put down on an open app is not screen time.
      final totals = UsageStatsService.foldEvents(
        [
          (ts: min(0), type: resumed, pkg: 'a'),
          (ts: min(5), type: screenOff, pkg: 'a'),
        ],
        start,
        end,
      );

      expect(totals, {'a': min(5)});
    });

    test('a session still open at the end stops at the window edge', () {
      // For "today" the edge is now, which is what makes a live total correct
      // rather than open-ended.
      final totals = UsageStatsService.foldEvents(
        [(ts: min(50), type: resumed, pkg: 'a')],
        start,
        end,
      );

      expect(totals, {'a': min(10)});
    });

    test('time before the window is clipped away', () {
      final totals = UsageStatsService.foldEvents(
        [
          (ts: -min(30), type: resumed, pkg: 'a'),
          (ts: min(10), type: paused, pkg: 'a'),
        ],
        start,
        end,
      );

      // Only the in-window portion counts, not the half hour before it.
      expect(totals, {'a': min(10)});
    });

    test('time after the window is clipped away', () {
      final totals = UsageStatsService.foldEvents(
        [
          (ts: min(55), type: resumed, pkg: 'a'),
          (ts: min(90), type: paused, pkg: 'a'),
        ],
        start,
        end,
      );

      expect(totals, {'a': min(5)});
    });

    test('stopped closes a session just like paused', () {
      final totals = UsageStatsService.foldEvents(
        [
          (ts: min(0), type: resumed, pkg: 'a'),
          (ts: min(7), type: stopped, pkg: 'a'),
        ],
        start,
        end,
      );

      expect(totals, {'a': min(7)});
    });

    test('a pause with no matching resume is ignored', () {
      final totals = UsageStatsService.foldEvents(
        [(ts: min(10), type: paused, pkg: 'a')],
        start,
        end,
      );

      expect(totals, isEmpty);
    });

    test('out-of-order events are still measured correctly', () {
      // The fold sorts defensively rather than trusting the platform's order.
      final totals = UsageStatsService.foldEvents(
        [
          (ts: min(20), type: paused, pkg: 'a'),
          (ts: min(5), type: resumed, pkg: 'a'),
        ],
        start,
        end,
      );

      expect(totals, {'a': min(15)});
    });

    test('an empty stream produces nothing', () {
      expect(UsageStatsService.foldEvents([], start, end), isEmpty);
    });

    test('a full day of one app never exceeds the day', () {
      // The regression guard: no combination of events can report more time
      // than the window physically contains.
      final events = <UsageEvent>[];
      for (var i = 0; i < 60; i += 2) {
        events.add((ts: min(i), type: resumed, pkg: 'a'));
        events.add((ts: min(i + 1), type: paused, pkg: 'a'));
      }
      final totals = UsageStatsService.foldEvents(events, start, end);

      expect(totals['a'], min(30));
      expect(totals['a']!, lessThanOrEqualTo(end - start));
    });
  });

  group('foldSessions', () {
    test('each visit is its own session', () {
      final sessions = UsageStatsService.foldSessions(
        [
          (ts: min(0), type: resumed, pkg: 'a'),
          (ts: min(5), type: paused, pkg: 'a'),
          (ts: min(20), type: resumed, pkg: 'a'),
          (ts: min(35), type: paused, pkg: 'a'),
        ],
        start,
        end,
      );

      expect(sessions['a'], hasLength(2));
      expect(sessions['a']![0], (start: min(0), end: min(5)));
      expect(sessions['a']![1], (start: min(20), end: min(35)));
    });

    test('a repeated resume stays one session, not three', () {
      // The count feeds "times opened", so this must not inflate either.
      final sessions = UsageStatsService.foldSessions(
        [
          (ts: min(0), type: resumed, pkg: 'a'),
          (ts: min(2), type: resumed, pkg: 'a'),
          (ts: min(4), type: resumed, pkg: 'a'),
          (ts: min(10), type: paused, pkg: 'a'),
        ],
        start,
        end,
      );

      expect(sessions['a'], hasLength(1));
      expect(sessions['a']!.first.end, min(10));
    });

    test('sessions sum to the same total foldEvents reports', () {
      final events = <UsageEvent>[
        (ts: min(1), type: resumed, pkg: 'a'),
        (ts: min(9), type: paused, pkg: 'a'),
        (ts: min(9), type: resumed, pkg: 'b'),
        (ts: min(29), type: paused, pkg: 'b'),
        (ts: min(40), type: resumed, pkg: 'a'),
      ];
      final totals = UsageStatsService.foldEvents(events, start, end);
      final sessions = UsageStatsService.foldSessions(events, start, end);

      for (final pkg in totals.keys) {
        final summed = sessions[pkg]!.fold<int>(
          0,
          (s, x) => s + (x.end - x.start),
        );
        expect(summed, totals[pkg], reason: pkg);
      }
    });

    test('an unclosed session is reported up to the window edge', () {
      final sessions = UsageStatsService.foldSessions(
        [(ts: min(58), type: resumed, pkg: 'a')],
        start,
        end,
      );

      expect(sessions['a'], hasLength(1));
      expect(sessions['a']!.first.end, end);
    });
  });
}

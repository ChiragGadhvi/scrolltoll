import 'package:flutter_test/flutter_test.dart';
import 'package:scrolltoll/utils/format_utils.dart';

void main() {
  group('formatDuration', () {
    test('under an hour reads as plain minutes', () {
      expect(formatDuration(0), '0m');
      expect(formatDuration(1), '1m');
      expect(formatDuration(59), '59m');
    });

    test('a whole hour drops the minutes entirely', () {
      expect(formatDuration(60), '1h');
      expect(formatDuration(120), '2h');
    });

    test('hours carry their remainder', () {
      expect(formatDuration(61), '1h 1m');
      expect(formatDuration(90), '1h 30m');
      expect(formatDuration(1439), '23h 59m');
    });

    test('a full day is still expressed in hours', () {
      // Nothing in the app rolls up to days, so 24hr is the honest reading.
      expect(formatDuration(1440), '24h');
    });
  });

  // A known Monday, so every weekday-derived assertion below has a fixed,
  // unambiguous answer.
  const monday = '2026-08-24';

  group('weekdayName', () {
    test('gives the full name by default', () {
      expect(weekdayName(monday), 'Monday');
    });

    test('gives the three-letter form when short', () {
      expect(weekdayName(monday, short: true), 'Mon');
    });

    test('falls back to the raw key on an unparseable date', () {
      expect(weekdayName('not-a-date'), 'not-a-date');
    });
  });

  group('weekdayInitial', () {
    test('gives a single letter', () {
      expect(weekdayInitial(monday), 'M');
    });

    test('falls back to empty on an unparseable date', () {
      expect(weekdayInitial('not-a-date'), '');
    });
  });

  group('monthDayLabel', () {
    test('gives month and day', () {
      expect(monthDayLabel(monday), 'Aug 24');
    });

    test('falls back to the raw key on an unparseable date', () {
      expect(monthDayLabel('not-a-date'), 'not-a-date');
    });
  });

  group('weekdayAndDay', () {
    test('gives the full weekday name and the day number, no month', () {
      expect(weekdayAndDay(monday), 'Monday 24');
    });

    test('falls back to the raw key on an unparseable date', () {
      expect(weekdayAndDay('not-a-date'), 'not-a-date');
    });
  });
}

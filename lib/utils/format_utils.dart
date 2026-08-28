import 'package:intl/intl.dart';

/// Renders a duration the way the app talks about time: compact `h`/`m`.
///
/// Deliberately never rolls up to days — a screen-time figure over 24h reads
/// more honestly in hours.
String formatDuration(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// A `yyyy-MM-dd` date key's weekday name, via `intl` rather than a hand-rolled
/// lookup table — every screen that labels a day by its weekday goes through
/// this one function.
///
/// [short] gives `Mon`; otherwise the full `Monday`. Falls back to the raw key
/// on a malformed date rather than throwing, since callers pass dates straight
/// from Hive rather than user input.
String weekdayName(String dateKey, {bool short = false}) {
  try {
    final date = DateTime.parse(dateKey);
    return DateFormat(short ? 'EEE' : 'EEEE').format(date);
  } catch (_) {
    return dateKey;
  }
}

/// A date key's single-letter weekday initial (`M`, `T`, `W`, ...), for the
/// coin chart's and calendar's compact axis labels.
String weekdayInitial(String dateKey) {
  try {
    // DateFormat has no single-letter pattern; the first character of the
    // short name is exactly what every call site already wants.
    return DateFormat('EEE').format(DateTime.parse(dateKey))[0];
  } catch (_) {
    return '';
  }
}

/// A date key as `Jan 5` — the month/day label used in headings and dialogs.
String monthDayLabel(String dateKey) {
  try {
    return DateFormat('MMM d').format(DateTime.parse(dateKey));
  } catch (_) {
    return dateKey;
  }
}

/// A date key as `Monday 5` — the chart's selected-day heading, where the
/// month is already implied by context and would be redundant.
String weekdayAndDay(String dateKey) {
  try {
    final date = DateTime.parse(dateKey);
    return '${DateFormat('EEEE').format(date)} ${date.day}';
  } catch (_) {
    return dateKey;
  }
}

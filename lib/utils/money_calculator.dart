class MoneyCalculator {
  static const String rupeeSymbol = '\u20B9';

  static double moneyCost(int minutes) => minutes.toDouble();

  static String formatRupees(double amount) => '$rupeeSymbol${amount.toInt()}';

  static String formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}hr' : '${h}hr ${m}min';
  }
}

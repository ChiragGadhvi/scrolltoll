class MoneyCalculator {
  static const String rupeeSymbol = '\u20B9';

  static double hourlyRate(double monthlySalary) => monthlySalary / 160;

  static double minuteRate(double monthlySalary) => hourlyRate(monthlySalary) / 60;

  static double moneyCost(int minutes, double monthlySalary) =>
      (minutes * minuteRate(monthlySalary)).roundToDouble();

  static String formatRupees(double amount) => '$rupeeSymbol${amount.toInt()}';

  static String formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}hr' : '${h}hr ${m}min';
  }
}

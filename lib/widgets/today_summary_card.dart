import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../utils/money_calculator.dart';

class TodaySummaryCard extends StatelessWidget {
  final double totalMoney;
  final int totalMinutes;

  const TodaySummaryCard({
    super.key,
    required this.totalMoney,
    required this.totalMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today you wasted',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            MoneyCalculator.formatRupees(totalMoney),
            style: textTheme.displaySmall?.copyWith(
              color: totalMoney > 0 ? AppColors.danger : AppColors.safe,
              fontWeight: FontWeight.w800,
            ),
          )
          .animate()
          .fadeIn(duration: 600.ms)
          .slideY(begin: 0.2, end: 0),
          const SizedBox(height: 6),
          Text(
            'That\'s ${MoneyCalculator.formatDuration(totalMinutes)} on your phone today',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

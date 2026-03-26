import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import '../models/app_usage_model.dart';
import '../theme/app_theme.dart';
import '../utils/money_calculator.dart';

class AppUsageTile extends StatelessWidget {
  final AppUsageModel app;

  const AppUsageTile({super.key, required this.app});

  Color _barColor() {
    if (app.durationMinutes >= 60) return AppColors.danger;
    if (app.durationMinutes >= 30) return AppColors.warning;
    return AppColors.safe;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          FutureBuilder<Application?>(
            future: DeviceApps.getApp(app.packageName, true),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.data != null &&
                  snapshot.data is ApplicationWithIcon) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    (snapshot.data as ApplicationWithIcon).icon,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                );
              }
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.appName,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  MoneyCalculator.formatDuration(app.durationMinutes),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            MoneyCalculator.formatRupees(app.moneyCost),
            style: textTheme.titleSmall?.copyWith(
              color: _barColor(),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

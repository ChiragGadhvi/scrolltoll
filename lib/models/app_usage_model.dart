import 'package:hive/hive.dart';

part 'app_usage_model.g.dart';

@HiveType(typeId: 0)
class AppUsageModel extends HiveObject {
  @HiveField(0)
  String appName;

  @HiveField(1)
  String packageName;

  @HiveField(2)
  int durationMinutes;

  @HiveField(3)
  double moneyCost;

  AppUsageModel({
    required this.appName,
    required this.packageName,
    required this.durationMinutes,
    required this.moneyCost,
  });
}

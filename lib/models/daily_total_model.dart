import 'package:hive/hive.dart';

part 'daily_total_model.g.dart';

@HiveType(typeId: 1)
class DailyTotalModel extends HiveObject {
  @HiveField(0)
  String date; // yyyy-MM-dd

  @HiveField(1)
  double totalMoney;

  @HiveField(2)
  int totalMinutes;

  DailyTotalModel({
    required this.date,
    required this.totalMoney,
    required this.totalMinutes,
  });
}

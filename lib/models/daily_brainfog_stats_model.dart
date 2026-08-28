import 'package:hive/hive.dart';

part 'daily_brainfog_stats_model.g.dart';

@HiveType(typeId: 2)
class DailyBrainfogStats extends HiveObject {
  @HiveField(0)
  String date; // yyyy-MM-dd

  @HiveField(1)
  int totalMinutes;

  // Index 2 held `estimatedVideos` before that concept was removed. The index
  // is deliberately left unused rather than reassigned: Hive matches fields by
  // index, so renumbering would make already-written records decode an old
  // video count as a different field. Records written before the removal
  // simply have an ignored extra field.

  /// 0-100 restatement of the day's fog intensity, from `RottoScore.score`.
  @HiveField(3)
  int brainfogScore;

  /// Which packages were tracked when this record was written. Preserved so
  /// a later change to today's tracked-app selection can never silently
  /// reinterpret an already-saved past day.
  @HiveField(4)
  List<String> trackedPackagesSnapshot;

  DailyBrainfogStats({
    required this.date,
    required this.totalMinutes,
    required this.brainfogScore,
    required this.trackedPackagesSnapshot,
  });
}

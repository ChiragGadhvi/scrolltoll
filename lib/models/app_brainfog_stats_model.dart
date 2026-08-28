/// Per-app tracked time for a single day. Plain data class, not a HiveObject —
/// instances are manually (de)serialized to a Map.
class AppBrainfogStats {
  final String packageName;
  final String appName;
  final int minutes;

  AppBrainfogStats({
    required this.packageName,
    required this.appName,
    required this.minutes,
  });
}

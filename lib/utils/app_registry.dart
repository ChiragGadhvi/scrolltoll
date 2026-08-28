/// Broad category for a trackable app. Compile-time metadata only — never
/// stored in Hive.
enum AppCategory { shortVideo, social, video, other }

class RegisteredApp {
  final String packageName;
  final String displayName;
  final AppCategory category;

  const RegisteredApp(this.packageName, this.displayName, this.category);
}

/// Curated set of apps Rotto knows about out of the box. Drives the
/// onboarding app-selection suggestions and nothing else.
///
/// `TrackedAppsScreen` deliberately does NOT depend on this list — any
/// installed app can still be tracked there. Adding a new supported app here
/// is a one-line addition.
class AppRegistry {
  static const List<RegisteredApp> supportedApps = [
    RegisteredApp('com.instagram.android', 'Instagram', AppCategory.shortVideo),
    RegisteredApp(
      'com.google.android.youtube',
      'YouTube',
      AppCategory.shortVideo,
    ),
    RegisteredApp('com.zhiliaoapp.musically', 'TikTok', AppCategory.shortVideo),
  ];

  static bool isShortVideoApp(String packageName) {
    return supportedApps.any(
      (a) =>
          a.packageName == packageName && a.category == AppCategory.shortVideo,
    );
  }
}

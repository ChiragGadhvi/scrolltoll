# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Rotto** is a Flutter Android app — a friendly, game-like digital wellbeing tracker. It reads Android `UsageStatsManager` data for the apps the user chooses to track, adds up today's foreground time, and shows a cute character, Rotto, whose mood reflects that total. Fully offline, no backend, no login, no analytics. Not a medical app — the score and moods are for entertainment only.

It measures **only** time in user-selected apps. There is no estimation of content watched and no user-set allowance or budget — both concepts were removed. Do not reintroduce either.

## Common Commands

```bash
# Install dependencies
flutter pub get

# Run on connected Android device (USB debugging)
flutter run

# Analyze Dart code (linting)
flutter analyze

# Format code
dart format lib/ test/

# Run tests
flutter test

# Run a single test file
flutter test test/rotto_score_test.dart

# Regenerate the Hive adapter (only needed if you add/remove a @HiveField)
dart run build_runner build --delete-conflicting-outputs

# Release bundle for Play Store -> build/app/outputs/bundle/release/app-release.aab
flutter build appbundle --release

# Clean rebuild
flutter clean && flutter pub get
```

## Architecture

**Entry point:** `lib/main.dart` — initializes Hive + notifications, then routes to `OnboardingScreen` (first launch) or `HomeScreen`.

**Directory layout:**
- `lib/models/` — `AppBrainfogStats` (plain class, manually serialized, not a HiveObject) and `DailyBrainfogStats` (typeId 2, real typed Hive storage) with a build_runner-generated `.g.dart` adapter
- `lib/screens/` — `onboarding_screen.dart`, `home_screen.dart` (also owns the 3-tab shell: Today / Insights / Settings), `analytics_screen.dart` (the Insights tab), `app_detail_screen.dart` (per-app history, pushed by tapping any tracked-app tile), `settings_screen.dart`, `tracked_apps_screen.dart`
- `lib/services/` — `hive_service.dart` (storage), `usage_stats_service.dart` (Android screen time), `notification_service.dart` (daily reminders)
- `lib/widgets/` — `ui_kit.dart` (shared `SoftCard` / `SectionHeading` / `MetricStrip` / `TrendPill` / `AppIconAvatar` / `RottoLoader` / `RottoEmptyState`), `app_brainfog_tile.dart` (tappable, routes to `AppDetailScreen`), `rotto_coin_chart.dart` (Week + per-app: a native CustomPainter curve whose data points are circular coins, each holding that day's Rotto pose — always Rotto, never an app icon; `isPerApp` only suppresses the day-wide mood label in the tap popup), `rotto_coin_calendar.dart` (Month: the same coins in a 7-column grid), `day_detail_dialog.dart` (`showDayDetail` — the shared centred popup both views open on tap, showing the pose large, the total, the mood and that day's most-used app)
- `lib/utils/` — `rotto_score.dart` (score + moods), `rotto_character.dart` (art/name/caption/colour per mood), `app_registry.dart`, `format_utils.dart`
- `lib/theme/app_theme.dart` — light Material 3 theme; color constants in `AppColors`

**Key packages:** `hive_flutter` (local storage), `usage_stats` (reads Android UsageStatsManager), `flutter_local_notifications` + `timezone` + `flutter_timezone` (notifications), `flutter_animate` (Rotto's idle bob and page animations), `home_widget` (home screen widget bridge), `device_apps` (installed-app list + icons). Poppins is vendored, not pulled via `google_fonts` — see Design below.

**Naming:** the user-facing name is **Rotto** (was ScrollToll, then Brainfog). Only display strings changed. The Dart package is still `scrolltoll` (pubspec `name:`), so every internal import is `package:scrolltoll/...`, and the Android `applicationId`/`namespace` stays `com.chirag.scrolltoll` — renaming it would break Play Store continuity for existing installs. Many identifiers (`AppBrainfogStats`, `DailyBrainfogStats`, `BrainfogWidgetProvider`, `brainfog_*` resource names) likewise keep their Brainfog-era names on purpose; only user-visible text was rebranded. Release signing reads `android/key.properties` if present, otherwise falls back to debug keys.

## Rotto score and moods

`lib/utils/rotto_score.dart` holds the **only** severity ladder in the app. `RottoScore(trackedMinutes)` produces:

- `score` — **100 down to 0, where 100 is good.** Starts full each day and drains as tracked time climbs, hitting 0 at `drainedAtMinutes`.
- `state` — one of five `RottoState` values in even 20-point bands.
- `drainedFraction` — 0.0-1.0, the mirror of the score.
- `minutesUntilNextState` — null once at `noEnergy`; never zero or negative.

`drainedAtMinutes` (240) is the single tunable knob; it fixes every boundary:

| Score | Mood | Starts at |
|---|---|---|
| 100-80 | energetic | 0m |
| 79-60 | scrolling | 50m |
| 59-40 | tired | 1h 38m |
| 39-20 | bingeMode | 2h 26m |
| 19-0 | noEnergy | 3h 14m |

Those minute figures are *derived*, not configured — `test/rotto_score_test.dart` probes boundaries relative to the constant instead of hardcoding them, and `RottoScore.moodStartMinutes` derives the per-mood start minutes the Settings mood list renders — so what the app tells the user cannot drift from what it computes, so retuning the knob does not break the suite. Anything quoting minutes to the user (the Settings FAQ, README) does need updating by hand.

`lib/utils/rotto_character.dart` is the presentation layer for a `RottoState`: mascot asset, display name, caption, and the green → red colour. Home, the day strip, the mood calendar, the tracked-app tiles and the Android widget all read from it, so a mood's look is defined once.

**Progress bars fill on the score, not on time spent** — full-and-green always means "good", like a game energy bar. `RottoCharacter.colorFor` walks `safe → safeDim → warning → bingeOrange → danger`. Note the fourth rung is `AppColors.bingeOrange`, **not** `AppColors.primary` — `primary` is the purple brand colour and is not on the ramp at all.

**Art:** `RottoCharacter._assets` maps all five moods to their own pose (`assets/rotto_{energetic,scrolling,tired,bingemode,noenergy}.png`). The same five poses are mirrored as Android drawables at every density for the home widget, plus `rotto_base.png` (neutral), `rotto_face.png` (small logo), `rotto_empty.png` (the shrug used by `RottoEmptyState`) and `rotto_waiting.png` (the sitting pose used by `RottoLoader`). There are no `CircularProgressIndicator`s left in `lib/` — every wait shows Rotto instead.

## Data storage (Hive boxes)

- `settings` — tracked apps, notification prefs, onboarding flag, `last_notified_mood`, `data_version`

`HiveService.init()` compares `data_version` against `_dataVersion` and, on a mismatch, **clears the daily and per-app usage boxes**. v2 exists because everything written by the old bucket-summing code was inflated; those rows could not be corrected in place (per-session detail was never stored) and the write-once backfill guard meant they would never be overwritten. Bump it again only for the same class of problem — it discards history.
- `daily_brainfog_stats` — date key → `DailyBrainfogStats` (typed, typeId 2; 30 days kept)
- `app_brainfog_usage` — date key → serialized list of per-app usage maps

`DailyBrainfogStats` uses `@HiveField` indices **0, 1, 3, 4** — index 2 is deliberately vacant. It held `estimatedVideos`; when that concept was removed the index was left unassigned rather than renumbered, because Hive matches fields by index and reusing 2 would make already-written records decode an old video count as another field. Records written before the removal simply carry an ignored extra field. Never reuse index 2.

`brainfogScore` is written on every record (from `RottoScore.score`, so 100 = good) but nothing currently reads it back — it is retained deliberately as history for future analytics, not because a screen needs it. Note the stored field name predates the Rotto rename; renaming it would mean another adapter migration for no user-visible gain.

`DailyBrainfogStats` stores a `trackedPackagesSnapshot` alongside every day's totals — the exact tracked-app list in effect when that record was written. Combined with the existing write-once backfill guard (`if (getDailyBrainfogStats(pastKey) == null) { …write… }` in `home_screen.dart`), this means **a later change to today's tracked-app selection can never silently reinterpret an already-saved past day** — only "today" is ever mutable.

Two legacy boxes from the app's previous life as a money/budget tracker (`daily_totals`, `app_usage`) are intentionally abandoned in place, not migrated — there's no honest way to map old ₹-based totals onto video-count totals.

## Android specifics

- `minSdk = flutter.minSdkVersion`, `compileSdk 36`, `targetSdk 36`
- Release builds run R8 (`isMinifyEnabled` + `isShrinkResources`, `android/app/build.gradle.kts`), with keep rules in `android/app/proguard-rules.pro` for the plugins that need them (`flutter_local_notifications`, `home_widget`, `device_apps`, `usage_stats`, this app's own Kotlin classes referenced by name from the manifest/widget-info XML rather than only from traceable Dart calls). This has not been through an actual release build in development — the environment that set it up could not run Gradle at all — so treat the first real release build after this as the one that needs a full device smoke test (notifications, the home widget, tracked-app icons, usage reading) before wider rollout.
- Permissions: `PACKAGE_USAGE_STATS`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, plus `QUERY_ALL_PACKAGES` for the app picker
- Home widget: `BrainfogWidgetProvider.kt` + `res/xml/scrolltoll_widget_info.xml` + `res/layout/scrolltoll_widget_layout.xml` (resource filenames kept from the old ScrollToll era; only their contents changed — renaming them has no user-visible benefit). Sized as a small **2x1** cell (`targetCellWidth/Height` in `scrolltoll_widget_info.xml`). Shows **only** the pose and the score — no "/100", no label, no progress bar, no busiest app. At widget size the pose carries the mood and the number carries the rest. Renders the matching pose from `res/drawable-*dpi/rotto_{energetic,scrolling,tired,bingemode,noenergy}.png`. Home pushes `tracked_minutes`, `rotto_score`, `rotto_state` and `top_app` through `home_widget`; the provider renders only what it is given. Its colour/name/threshold mirrors of the Dart side are marked with sync comments.

  The provider sticks to definitely-remotable `RemoteViews` calls (`setTextViewText`, `setTextColor`, `setProgressBar`, `setImageViewResource`) plus `setColorStateList` guarded behind an API 31 check. Reflection-based `setInt(..., "setColorFilter", ...)` was tried and removed — it only works on `@RemotableViewMethod` targets and cannot be verified in a sandbox where Gradle will not run.
- Notification receivers declared in `AndroidManifest.xml` for `flutter_local_notifications`

**Notifications** (`notification_service.dart`) — two channels:

  - **Daily report** (`scheduleDailyReminder`) repeats at the user's chosen time and carries **no figures on purpose**. It repeats via `DateTimeComponents.time`, so a body baked with today's numbers would be re-shown verbatim tomorrow, stating yesterday's total as today's.
  - **Rotto's mood** (`notifyMoodChange`) fires the moment the mood band changes, with real numbers and a `BigPictureStyleInformation` of the pose, using the same `rotto_*` Android drawables as the widget. Guarded by `HiveService.lastNotifiedMood` so each change is announced once; the first refresh only records (no "you are now Energetic" on install) and the midnight rollover clears it.

  `init()` **must** call `tz.setLocalLocation` from `flutter_timezone` — without it `tz.local` is UTC and every reminder was scheduled for its hour in UTC, i.e. the middle of the night. That was the reason notifications appeared not to work at all. Exact alarms are deliberately not used (`inexactAllowWhileIdle`), so no `SCHEDULE_EXACT_ALARM` permission.

**Usage data refresh:** On every app open / foreground resume (`WidgetsBindingObserver`), a 1-minute periodic check for midnight rollover, and whenever `HiveService.trackedAppsRevision` fires. That notifier is the fix for a real bug: returning from `TrackedAppsScreen` never triggers a lifecycle resume and `IndexedStack` keeps Home alive, so a newly tracked app used to stay invisible until the app was backgrounded. Any writer of `HiveService.trackedApps` bumps it. Home additionally lists tracked apps with no time today under "Also tracked", so adding an app always shows something.

  `HiveService.statsRevision` is the matching fix for Insights. It is built inside Home's `IndexedStack`, so it is constructed *before* Home's first async read has written anything, and it used to render an empty week until the app was restarted. Home fires `notifyStatsChanged()` once after its writes finish — deliberately not from the save methods, since the backfill writes a dozen days in a loop and would rebuild Insights on each one.

**Usage measurement** (`usage_stats_service.dart`) — read this before touching it. It walks the raw **event stream** (`UsageStats.queryEvents`) and pairs ACTIVITY_RESUMED with PAUSED/STOPPED to measure real foreground intervals, clamped to the requested window. It deliberately does **not** call `queryUsageStats`: that asks Android with `INTERVAL_BEST`, which returns one row per interval bucket, each carrying its whole bucket's total, and buckets can extend outside the window. Summing those rows (the old implementation) inflated every figure — single days reported 30h. `queryAndAggregateUsageStats` has the same bucket problem and was removed as a fallback for the same reason.

  Session rules: screen-off (`SCREEN_NON_INTERACTIVE`) and shutdown end every open session, so a phone put down on an open app is not screen time; a resume for another package closes any session that never got its pause event. A per-app total is finally clamped to the window length, so nothing impossible can escape. The fold is exposed as `foldEvents` (`@visibleForTesting`) and covered by `test/usage_events_test.dart` — **that suite is the guard against the inflation bug returning.**

  Filtering gates: the public `excludedPackages` set drops launchers/system UI/dialers; `DeviceApps.getInstalledApplications(includeSystemApps: true, onlyAppsWithLaunchIntent: true)` drops background-only processes. **`includeSystemApps` must stay `true`** — YouTube, Chrome, Gmail and every OEM-preinstalled app are system apps, and `false` silently made them impossible to track. `TrackedAppsScreen` filters through the same set. Anything under 5s is a momentary switch. `getRawUsageForOnboarding` passes `onlyTracked: false` to skip the tracked-apps gate.

  **History horizon:** Android only retains raw events for roughly a week, so days older than that cannot be reconstructed — Home backfills 13 days and everything before that exists only if Rotto recorded it live. The charts draw a missing day as a hollow coin and print "N of M days recorded so far", rather than implying a quiet day.

**Supported-app registry:** `lib/utils/app_registry.dart` lists apps Rotto knows about out of the box (Instagram, YouTube, TikTok) with a category enum (`AppCategory.shortVideo`, etc.). This is compile-time metadata only — never stored in Hive — and drives onboarding's app-selection page only. `TrackedAppsScreen` itself stays fully generic and lets the user track any installed app, registered or not.

**Design:** Light Material 3 — `AppTheme.light` is the only theme, there is no dark variant. Primary `#7C5CBF` (Rotto's own purple), background `#FAF9FC`, cards `#FFFFFF`; palette in `AppColors`, all `const`.

  **Poppins is vendored** under `assets/fonts/` and declared in pubspec, *not* pulled via `google_fonts`. That package fetches the font over the network at runtime, and the release manifest has no INTERNET permission (deliberately — it matches the privacy promise), so the shipped app silently fell back to the platform font while debug builds looked fine. Never reintroduce `google_fonts`. Licence in `assets/fonts/OFL.txt`; `test/theme_test.dart` asserts the family is the bundled `Poppins`.

  Bottom navigation is M3 `NavigationBar`; the Insights period switch is `SegmentedButton`. Both themed in `AppTheme` rather than styled per-use. Every rendered measurement uses `tabularFigures` so animating counters don't jitter.

  Weekday/month labels (chart axes, the day-detail popup, the app-detail "busiest day" row) all go through `lib/utils/format_utils.dart`'s `weekdayName` / `weekdayInitial` / `monthDayLabel` / `weekdayAndDay`, which wrap `intl`'s `DateFormat` rather than each call site keeping its own hand-rolled name array. Add a new one there rather than a fifth local array if a screen needs another day-label shape.

## Testing

`test/flutter_test_config.dart` runs before every test and sets `GoogleFonts.config.allowRuntimeFetching = false` — without it, widget tests fail the framework's "no pending timers" check because `google_fonts` tries to fetch Poppins over HTTP. Keep it.

Hive-touching tests (`hive_service_test.dart`, `daily_brainfog_stats_immutability_test.dart`, `home_screen_empty_test.dart`) each `Hive.init()` a fresh `Directory.systemTemp.createTemp()` and guard adapter registration with `if (!Hive.isAdapterRegistered(2))`, since adapters are process-global. `home_screen_empty_test.dart` also mocks the `usage_stats` `MethodChannel` — there's no Android platform under `flutter test`.

`daily_brainfog_stats_immutability_test.dart` is the regression test for the past-day-mutation bug described under Data storage; it asserts the backfill guard, so don't relax that guard without reading it first.

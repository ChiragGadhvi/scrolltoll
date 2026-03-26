# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ScrollToll** is a Flutter Android app — a Screen Time Money Waster Calculator. It reads Android `UsageStatsManager` data, calculates how much money the user wastes based on their hourly rate (monthly salary ÷ 160), and shows it per-app. Fully offline, no backend, no login.

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
flutter test test/widget_test.dart

# Clean rebuild
flutter clean && flutter pub get
```

## Architecture

**Entry point:** `lib/main.dart` — initializes Hive + notifications, then routes to `OnboardingScreen` (first launch) or `HomeScreen`.

**Directory layout:**
- `lib/models/` — `AppUsageModel` (typeId 0), `DailyTotalModel` (typeId 1) with hand-written `.g.dart` adapters
- `lib/screens/` — `onboarding_screen.dart`, `home_screen.dart`, `weekly_report_screen.dart`, `settings_screen.dart`
- `lib/services/` — `hive_service.dart` (storage), `usage_stats_service.dart` (Android screen time), `notification_service.dart` (daily reminders)
- `lib/widgets/` — `app_usage_tile.dart`, `today_summary_card.dart`, `weekly_chart.dart`
- `lib/theme/app_theme.dart` — dark Material 3 theme; color constants in `AppColors`
- `lib/utils/money_calculator.dart` — `hourlyRate`, `minuteRate`, `moneyCost`, formatting helpers

**Key packages:** `hive_flutter` (local storage), `usage_stats` (reads Android UsageStatsManager), `flutter_local_notifications` + `timezone` (daily notifications), `fl_chart` (bar chart), `flutter_animate` (number animations), `share_plus` (weekly report sharing), `home_widget` (4×1 home screen widget), `google_fonts` (Poppins).

**Money formula:** `monthlySalary / 160 / 60 * appUsageMinutes`, rounded to nearest ₹1.

**Data storage (Hive boxes):**
- `settings` — salary, notification prefs, onboarding flag
- `daily_totals` — date key → `DailyTotalModel` (30 days kept)
- `app_usage` — date key → serialized list of app usage maps

**Android specifics:**
- `minSdk = 21` (required by `usage_stats` package)
- Permissions: `PACKAGE_USAGE_STATS`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`
- Home widget: `ScrollTollWidgetProvider.kt` + `res/xml/scrolltoll_widget_info.xml` + `res/layout/scrolltoll_widget_layout.xml`
- Notification receivers declared in `AndroidManifest.xml` for `flutter_local_notifications`

**Design:** Dark-first, Material 3. Primary `#FF6B35` (orange), background `#0D0D0D`, cards `#1A1A1A`. Font: Poppins.

**Usage data refresh:** On every app open / foreground resume (`WidgetsBindingObserver`).

**System apps excluded:** Hardcoded set in `usage_stats_service.dart` (`_excludedPackages`) filters launchers, system UI, dialer, etc.

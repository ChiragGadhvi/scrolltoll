# Repository Guidelines

## Project Structure & Module Organization

This is a Flutter app (package name: `scrolltoll`; user-facing name: Rotto). Application code lives in `lib/`: `screens/` contains full pages, `widgets/` reusable UI, `services/` platform and persistence integrations, `models/` Hive data types, and `utils/` pure calculations and registries. Theme constants are in `lib/theme/app_theme.dart`. Tests mirror behavior in `test/`. Native Android integration, including usage access and the live overlay, is under `android/`; platform runner projects are in `ios/`, `web/`, `linux/`, `macos/`, and `windows/`. Keep image assets in `assets/`.

## Build, Test, and Development Commands

Run from the repository root:

```bash
flutter pub get                         # install dependencies
flutter run                             # run on a connected device/emulator
flutter analyze                         # apply configured Dart/Flutter lints
dart format lib/ test/                  # format Dart sources
flutter test                            # run the full test suite
flutter test test/rotto_score_test.dart # run one test file
dart run build_runner build --delete-conflicting-outputs # regenerate Hive adapters
flutter build appbundle --release       # create the Android release bundle
```

## Coding Style & Naming Conventions

Use the Dart formatter (two-space indentation); do not hand-format around it. Follow `flutter_lints` from `analysis_options.yaml`. Name files with `snake_case.dart`, classes and enums in `PascalCase`, and members in `camelCase`. Keep the score model and mood thresholds in `lib/utils/rotto_score.dart`; widgets should render supplied values rather than recompute them. Preserve `package:scrolltoll/...` imports and the existing Android application ID unless a coordinated migration is intended.

## Testing Guidelines

Write focused Flutter tests in `test/*_test.dart`, naming test descriptions for observable behavior. Run `flutter test` and `flutter analyze` before submitting. `test/flutter_test_config.dart` disables Google Fonts runtime fetching—keep it enabled. Hive tests must use isolated temporary storage and guard global adapter registration; widget tests touching usage data must mock the platform channel.

## Commit & Pull Request Guidelines

Recent history uses short version-style subjects (for example, `Version1.6`). Use a concise imperative subject, optionally with a version prefix when releasing. Keep commits scoped. Pull requests should explain the behavior change, identify Android permission/native impacts, link the relevant issue when available, and include screenshots or a short recording for visible UI changes. Note any manual device testing, especially Usage Access or overlay permission flows.

## Configuration & Data Safety

Do not commit signing credentials such as `android/key.properties`, and keep the Kie.ai API key out of the repo (`.mcp.json` reads it from the `KIE_AI_API_KEY` environment variable). Usage data is local: Rotto measures foreground time in user-selected apps and nothing else — it makes no estimates and infers no content, so keep wording free of inferred counts. Changes to Hive fields require adapter regeneration and a storage compatibility review.

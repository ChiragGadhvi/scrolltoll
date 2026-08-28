import 'dart:async';

/// Runs before every test file.
///
/// This used to disable `google_fonts` runtime fetching, without which widget
/// tests failed the framework's "no pending timers" check. Poppins is now
/// bundled under `assets/fonts/`, so there is nothing to fetch and no hook
/// needed — the file stays because Flutter looks for it by name and future
/// global setup belongs here.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Independent: notifications touch no Hive state, so there is no reason to
  // block one on the other before the first frame.
  await Future.wait([HiveService.init(), NotificationService.init()]);
  runApp(const RottoApp());
}

class RottoApp extends StatelessWidget {
  const RottoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rotto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: HiveService.onboardingDone
          ? const HomeScreen()
          : const OnboardingScreen(),
    );
  }
}

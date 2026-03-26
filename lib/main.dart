import 'package:flutter/material.dart';
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  await NotificationService.init();
  runApp(const ScrollTollApp());
}

class ScrollTollApp extends StatelessWidget {
  const ScrollTollApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScrollToll',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: HiveService.onboardingDone
          ? const HomeScreen()
          : const OnboardingScreen(),
    );
  }
}

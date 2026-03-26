import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/hive_service.dart';
import '../services/usage_stats_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/money_calculator.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final PageController _pageController = PageController();
  double _salary = 0;
  bool _isRequesting = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && _isRequesting) {
      final hasPermission = await UsageStatsService.checkPermission();
      if (hasPermission) {
        _finishOnboarding();
      } else {
        setState(() => _isRequesting = false);
      }
    }
  }


  void _onNext() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid salary'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    HiveService.monthlySalary = value;
    FocusScope.of(context).unfocus();
    setState(() => _salary = value);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 600),
      curve: Curves.fastOutSlowIn,
    );
  }

  Future<void> _onGrantAccess() async {
    // Request notification permissions cleanly during onboarding first
    await NotificationService.requestPermission();
    
    setState(() => _isRequesting = true);
    // This will open Android Settings
    await UsageStatsService.requestPermission();
  }

  void _finishOnboarding() {
    HiveService.onboardingDone = true;
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Sleek premium true black
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildSalaryPage(),
          _buildPermissionPage(),
        ],
      ),
    );
  }

  Widget _buildSalaryPage() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const Spacer(flex: 2),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    spreadRadius: 8,
                    blurRadius: 30,
                  ),
                ],
              ),
              child: const Icon(
                Icons.attach_money_rounded,
                size: 50,
                color: Colors.white,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 48),
            Text(
              "How much do you value your time?",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
            const SizedBox(height: 16),
            Text(
              "We use your monthly income to calculate exactly what your scrolling is costing you.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.5,
                  ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
            const SizedBox(height: 48),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    MoneyCalculator.rupeeSymbol,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '50000',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _salary = double.tryParse(val) ?? 0;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
            if (_salary > 0)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  'That means your time costs\n${MoneyCalculator.formatRupees(MoneyCalculator.hourlyRate(_salary))} per hour',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ).animate().fadeIn().moveY(begin: -10),
              ),
            const Spacer(flex: 3),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionPage() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const Spacer(flex: 2),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.warning,
                    AppColors.warning.withOpacity(0.4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.warning.withOpacity(0.2),
                    spreadRadius: 8,
                    blurRadius: 30,
                  ),
                ],
              ),
              child: const Icon(
                Icons.privacy_tip_rounded,
                size: 50,
                color: Colors.white,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 48),
            Text(
              "One Final Step",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
            const SizedBox(height: 16),
            Text(
              "We need permission to see your screen time.\nEverything happens locally on this device. We don't collect or send your data anywhere.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.5,
                  ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
            const Spacer(flex: 3),
            if (_isRequesting)
              const CircularProgressIndicator(color: AppColors.warning)
            else
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _onGrantAccess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Grant Permission",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                HiveService.onboardingDone = true;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              },
              child: Text(
                'Skip for now',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:typed_data';
import 'package:device_apps/device_apps.dart';
import '../services/hive_service.dart';
import '../services/usage_stats_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/money_calculator.dart';
import '../models/app_usage_model.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final PageController _pageController = PageController();
  double _budget = 0;
  bool _isRequesting = false;
  
  List<AppUsageModel> _topApps = [];
  Map<String, Uint8List?> _appIcons = {};
  Set<String> _selectedApps = {};
  bool _isLoadingApps = false;

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
        _moveToAppSelection();
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
          content: const Text('Please enter a valid budget limit'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    HiveService.dailyBudget = value;
    FocusScope.of(context).unfocus();
    setState(() => _budget = value);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 600),
      curve: Curves.fastOutSlowIn,
    );
  }

  Future<void> _checkPermissionAndProceed() async {
    await NotificationService.requestPermission();
    
    setState(() => _isRequesting = true);
    final hasPermission = await UsageStatsService.checkPermission();
    if (hasPermission) {
      _moveToAppSelection();
    } else {
      await UsageStatsService.requestPermission();
    }
  }

  void _moveToAppSelection() async {
    setState(() {
      _isRequesting = false;
      _isLoadingApps = true;
    });
    
    _pageController.nextPage(
      duration: const Duration(milliseconds: 600),
      curve: Curves.fastOutSlowIn,
    );

    final apps = await UsageStatsService.getRawUsageForOnboarding();
    final topApps = apps.take(15).toList();
    
    final icons = <String, Uint8List?>{};
    final selected = <String>{};
    for (var i = 0; i < topApps.length; i++) {
       final app = topApps[i];
       // Pre-select top 5 automatically
       if (i < 5) selected.add(app.packageName);
       try {
         final dApp = await DeviceApps.getApp(app.packageName, true);
         if (dApp is ApplicationWithIcon) {
           icons[app.packageName] = dApp.icon;
         }
       } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _topApps = topApps;
        _appIcons = icons;
        _selectedApps = selected;
        _isLoadingApps = false;
      });
    }
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
          _buildWelcomePage(),
          _buildBudgetPage(),
          _buildPermissionPage(),
          _buildTopAppsSelectionPage(),
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const Text(
              "TIME\nIS\nMONEY.",
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w900,
                height: 0.95,
                letterSpacing: -2,
                color: Colors.white,
              ),
            ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.1, curve: Curves.easeOutQuart),
            const SizedBox(height: 24),
            const Text(
              "ScrollToll tracks exactly how much value you're throwing away every day through mindless screen time.",
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
                height: 1.4,
              ),
            ).animate().fadeIn(delay: 500.ms, duration: 600.ms).slideY(begin: 0.2),
            const Spacer(flex: 2),
            SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.fastOutSlowIn,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Get Started",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ).animate().fadeIn(delay: 900.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetPage() {
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
              "Set your daily Time Value Budget.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
            const SizedBox(height: 16),
            Text(
              "How many total points are you allowing yourself to spend daily? Each tracked minute on your phone will cost exactly 1 point from your Jar.",
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '150',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _budget = double.tryParse(val) ?? 0;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
            if (_budget > 0)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  'You have exactly ${_budget.toInt()} points to burn today!',
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
                  onPressed: _checkPermissionAndProceed,
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
                _moveToAppSelection(); // If they stubbornly refuse they'll see an empty list
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

  Widget _buildTopAppsSelectionPage() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "Select Apps to Limit",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Here are the apps you use most. Select the ones you want to track to drain from your Budget Quota.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.5,
                  ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingApps
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _topApps.length,
                    itemBuilder: (context, index) {
                      final app = _topApps[index];
                      final isSelected = _selectedApps.contains(app.packageName);
                      final icon = _appIcons[app.packageName];
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppColors.danger.withOpacity(0.1) 
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected 
                              ? Border.all(color: AppColors.danger.withOpacity(0.5)) 
                              : Border.all(color: Colors.transparent),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          secondary: icon != null 
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(icon, width: 40, height: 40, fit: BoxFit.cover),
                                )
                              : const SizedBox(width: 40, height: 40),
                          title: Text(
                            app.appName,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isSelected ? AppColors.danger : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          value: isSelected,
                          activeColor: AppColors.danger,
                          onChanged: (val) {
                            setState(() {
                              if (val) {
                                _selectedApps.add(app.packageName);
                              } else {
                                _selectedApps.remove(app.packageName);
                              }
                            });
                          },
                        ),
                      ).animate().fadeIn(delay: Duration(milliseconds: 300 + (index * 50)));
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  HiveService.trackedApps = _selectedApps.toList();
                  _finishOnboarding();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Finish Setup",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ).animate().fadeIn(delay: 500.ms),
          ),
        ],
      ),
    );
  }
}

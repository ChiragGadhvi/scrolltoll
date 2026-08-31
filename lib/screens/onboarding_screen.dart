import 'dart:typed_data';

import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../services/usage_stats_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_registry.dart';
import '../utils/format_utils.dart';
import '../utils/rotto_character.dart';
import '../utils/rotto_score.dart';
import '../widgets/ui_kit.dart';
import 'home_screen.dart';

/// First-run flow: meet the character, explain Usage Access, then choose
/// which apps count.
///
/// The app picker works whether or not Usage Access was granted — skipping the
/// permission only means the list is sorted alphabetically instead of by
/// recent usage.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();

  bool _isRequesting = false;
  bool _isLoadingApps = false;
  bool _appsLoaded = false;

  List<_CandidateApp> _candidates = [];
  final Set<String> _selectedApps = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_isRequesting) return;
    // Returning from the system Usage Access screen.
    UsageStatsService.checkPermission().then((granted) {
      if (!mounted) return;
      setState(() => _isRequesting = false);
      if (granted) _moveToAppSelection();
    });
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );
  }

  Future<void> _requestUsageAccess() async {
    await NotificationService.requestPermission();
    if (!mounted) return;

    setState(() => _isRequesting = true);
    if (await UsageStatsService.checkPermission()) {
      if (!mounted) return;
      setState(() => _isRequesting = false);
      _moveToAppSelection();
      return;
    }
    // Sends the user to system settings; didChangeAppLifecycleState picks the
    // flow back up when they return.
    await UsageStatsService.requestPermission();
  }

  /// Advances to the app picker and loads its list.
  ///
  /// Guarded against a double load: the lifecycle observer and the "maybe
  /// later" button can both land here if the user grants access and returns
  /// quickly.
  void _moveToAppSelection() {
    _nextPage();
    if (_appsLoaded || _isLoadingApps) return;
    _loadCandidateApps();
  }

  Future<void> _loadCandidateApps() async {
    setState(() => _isLoadingApps = true);

    // Filtered through the same set as TrackedAppsScreen. Without this the
    // picker offered the launcher, System UI and the keyboard as trackable —
    // and usage_stats_service then refuses to ever count them, so anything
    // selected here would sit at zero forever with no explanation.
    final installed = (await DeviceApps.getInstalledApplications(
      includeSystemApps: true,
      onlyAppsWithLaunchIntent: true,
      includeAppIcons: true,
    )).where((a) => !excludedPackages.contains(a.packageName)).toList();

    // Recent usage is only available once Usage Access is granted; without it
    // this is an empty map and the list simply falls back to alphabetical.
    final rawUsage = await UsageStatsService.getRawUsageForOnboarding();
    final minutesByPkg = {for (final a in rawUsage) a.packageName: a.minutes};

    final candidates = installed
        .map(
          (app) => _CandidateApp(
            packageName: app.packageName,
            displayName: app.appName,
            icon: app is ApplicationWithIcon ? app.icon : null,
            recentMinutes: minutesByPkg[app.packageName] ?? 0,
            isSuggested: AppRegistry.isShortVideoApp(app.packageName),
          ),
        )
        .toList();

    // Rotto's known short-video apps first, then whatever the phone
    // actually used this week, then everything else by name.
    candidates.sort((a, b) {
      if (a.isSuggested != b.isSuggested) return a.isSuggested ? -1 : 1;
      if (a.recentMinutes != b.recentMinutes) {
        return b.recentMinutes.compareTo(a.recentMinutes);
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    if (!mounted) return;
    setState(() {
      _candidates = candidates;
      // Preselect only the short-video apps Rotto already knows, so the
      // default is never "every app on the phone".
      _selectedApps
        ..clear()
        ..addAll(
          candidates.where((c) => c.isSuggested).map((c) => c.packageName),
        );
      _isLoadingApps = false;
      _appsLoaded = true;
    });
  }

  void _finishOnboarding() {
    HiveService.trackedApps = _selectedApps.toList();
    HiveService.onboardingDone = true;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildMeetRottoPage(),
          _buildPermissionPage(),
          _buildAppSelectionPage(),
        ],
      ),
    );
  }

  // 1. Meet Rotto
  Widget _buildMeetRottoPage() {
    // Sized against the screen rather than fixed: a fixed 300 pushed the "Say
    // hello" button below the fold on shorter devices, which is the one thing
    // a welcome screen cannot afford.
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.34).clamp(
      170.0,
      300.0,
    );

    return _CenteredPage(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stands on the same purple hill as Home's hero, so the first screen
        // and the app proper look like one place. The idle loop is baked
        // into the WebP now, so no hand-rolled bob animation here.
        SizedBox(
              height: heroHeight,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    height: heroHeight * 0.56,
                    decoration: BoxDecoration(
                      color: AppColors.hill,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(150),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: heroHeight * 0.07),
                    child: Image.asset(
                      'assets/rotto_base.webp',
                      height: heroHeight * 0.89,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 650.ms)
            .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
        const SizedBox(height: 26),
        Text(
              'MEET\nROTTO.',
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                height: 0.95,
                letterSpacing: -2,
                color: AppColors.textPrimary,
              ),
            )
            .animate()
            .fadeIn(duration: 800.ms)
            .slideX(begin: -0.1, curve: Curves.easeOutQuart),
        const SizedBox(height: 18),
        Text(
          'A little companion that reacts to how much you scroll — and '
          'cheers you on when you take a break.',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ).animate().fadeIn(delay: 450.ms, duration: 600.ms).slideY(begin: 0.2),
        const SizedBox(height: 34),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _nextPage,
            child: const Text(
              'Say hello',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ).animate().fadeIn(delay: 800.ms),
      ],
    );
  }

  // 2. Usage Access, and why the data stays put
  Widget _buildPermissionPage() {
    final textTheme = Theme.of(context).textTheme;
    return _CenteredPage(
      children: [
        Container(
              height: (MediaQuery.sizeOf(context).height * 0.24).clamp(
                140.0,
                210.0,
              ),
              width: (MediaQuery.sizeOf(context).height * 0.24).clamp(
                140.0,
                210.0,
              ),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primarySoft,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: ClipOval(
                child: Transform.scale(
                  scale: 1.15,
                  child: Image.asset(
                    RottoCharacter.assetFor(RottoState.energetic),
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 650.ms)
            .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
        const SizedBox(height: 26),
        Text(
          'Stays on your phone',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
        const SizedBox(height: 14),
        Text(
          'Android’s Usage Access lets Rotto measure how long you spend in '
          'the apps you pick.\n\nThere is no account and no server — nothing '
          'ever leaves this device.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
        const SizedBox(height: 30),
        if (_isRequesting)
          const Center(child: RottoLoader(size: 90))
        else
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _requestUsageAccess,
              child: const Text(
                'Allow Usage Access',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ).animate().fadeIn(delay: 400.ms),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _moveToAppSelection,
          child: Text(
            'Maybe later',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ).animate().fadeIn(delay: 500.ms),
      ],
    );
  }

  // 3. Choose the apps that count
  Widget _buildAppSelectionPage() {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              'What should count?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Pick any apps you want Rotto to count. Short-video apps '
              'are suggested first, but anything on your phone works, and you '
              'can change this later.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingApps
                ? const Center(
                    child: RottoLoader(message: 'Looking through your apps…'),
                  )
                : _candidates.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No launchable apps were found on this device. You can '
                        'add apps later from Settings › Apps to Track.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _candidates.length,
                    itemBuilder: (context, index) =>
                        _appRow(_candidates[index], textTheme),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _finishOnboarding,
                child: Text(
                  _selectedApps.isEmpty
                      ? 'Skip for now'
                      : 'Track ${_selectedApps.length} '
                            'app${_selectedApps.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appRow(_CandidateApp app, TextTheme textTheme) {
    final selected = _selectedApps.contains(app.packageName);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.10)
            : AppColors.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? BorderSide(color: AppColors.primary)
              : BorderSide(color: AppColors.divider),
        ),
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          secondary: app.icon != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    app.icon!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                )
              : const SizedBox(width: 40, height: 40),
          title: Text(
            app.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyLarge?.copyWith(
              color: selected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          subtitle: app.recentMinutes > 0
              ? Text(
                  '${formatDuration(app.recentMinutes)} in the last 7 days',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              : null,
          value: selected,
          activeThumbColor: AppColors.primary,
          onChanged: (on) => setState(() {
            if (on) {
              _selectedApps.add(app.packageName);
            } else {
              _selectedApps.remove(app.packageName);
            }
          }),
        ),
      ),
    );
  }
}

/// A single onboarding page: vertically centred when it fits, scrollable when
/// it does not.
///
/// Deliberately no `Spacer`s — a flex child inside a scroll view has no bounded
/// height to expand into. Explicit gaps keep short screens and large system
/// font sizes from overflowing.
class _CenteredPage extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  const _CenteredPage({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// One row in the onboarding app picker.
class _CandidateApp {
  final String packageName;
  final String displayName;
  final Uint8List? icon;
  final int recentMinutes;

  /// True for apps in [AppRegistry]'s short-video list, which sort first and
  /// start preselected.
  final bool isSuggested;

  const _CandidateApp({
    required this.packageName,
    required this.displayName,
    required this.icon,
    required this.recentMinutes,
    required this.isSuggested,
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../models/app_usage_model.dart';
import '../models/daily_total_model.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../services/usage_stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/time_value_jar.dart';
import '../utils/money_calculator.dart';
import '../widgets/app_usage_tile.dart';
import '../widgets/today_summary_card.dart';
import 'settings_screen.dart';
import 'analytics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  List<AppUsageModel> _apps = [];
  bool _loading = true;
  bool _permissionMissing = false;
  String _lastLoadedDate = '';
  late final Stream<int> _clockStream;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastLoadedDate = HiveService.todayKey;
    _loadData();
    _startMidnightChecker();
  }

  void _startMidnightChecker() {
    // Check every minute if the day has changed
    Stream.periodic(const Duration(minutes: 1)).listen((_) {
      final now = HiveService.todayKey;
      if (now != _lastLoadedDate) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = HiveService.todayKey;
      if (now != _lastLoadedDate) {
        // Date changed while app was in background
        _loadData();
      } else {
        // Just refresh the data for today
        _loadData();
      }
    }
  }

  Future<void> _loadData() async {
    _lastLoadedDate = HiveService.todayKey;
    setState(() => _loading = true);

    final hasPermission = await UsageStatsService.checkPermission();
    if (!hasPermission) {
      setState(() {
        _permissionMissing = true;
        _loading = false;
      });
      return;
    }

    final apps = await UsageStatsService.getTodayUsage();
    final totalMoney = apps.fold(0.0, (s, a) => s + a.moneyCost);
    final totalMinutes = apps.fold(0, (s, a) => s + a.durationMinutes);

    final today = HiveService.todayKey;
    HiveService.saveAppUsageForDate(today, apps);
    HiveService.saveDailyTotal(DailyTotalModel(
      date: today,
      totalMoney: totalMoney,
      totalMinutes: totalMinutes,
    ));

    // Backfill past 6 days if missing
    final now = DateTime.now();
    for (int i = 1; i <= 6; i++) {
      final pastDate = now.subtract(Duration(days: i));
      final pastKey =
          '${pastDate.year}-${pastDate.month.toString().padLeft(2, '0')}-${pastDate.day.toString().padLeft(2, '0')}';
      if (HiveService.getDailyTotal(pastKey) == null) {
        final pastApps = await UsageStatsService.getUsageForDate(pastDate);
        final cost = pastApps.fold(0.0, (s, a) => s + a.moneyCost);
        final mins = pastApps.fold(0, (s, a) => s + a.durationMinutes);
        HiveService.saveAppUsageForDate(pastKey, pastApps);
        HiveService.saveDailyTotal(DailyTotalModel(
          date: pastKey,
          totalMoney: cost,
          totalMinutes: mins,
        ));
      }
    }

    if (HiveService.notificationsEnabled && apps.isNotEmpty) {
      NotificationService.scheduleDailyNotification(
        hour: HiveService.notificationHour,
        minute: HiveService.notificationMinute,
        todayAmount: totalMoney,
        topApp: apps.first.appName,
      );
    }

    _updateHomeWidget(totalMoney);

    setState(() {
      _apps = apps;
      _loading = false;
      _permissionMissing = false;
    });
  }

  Future<void> _updateHomeWidget(double todayAmount) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yk =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final yTotal = HiveService.getDailyTotal(yk);
      await HomeWidget.saveWidgetData<String>('today_amount', todayAmount.toString());
      await HomeWidget.saveWidgetData<String>('daily_budget', HiveService.dailyBudget.toString());
      await HomeWidget.saveWidgetData<String>(
        'yesterday_amount',
        (yTotal?.totalMoney ?? 0.0).toString(),
      );
      await HomeWidget.updateWidget(androidName: 'ScrollTollWidgetProvider');
    } catch (_) {}
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0D0D0D),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _DashboardTab(
              apps: _apps,
              loading: _loading,
              permissionMissing: _permissionMissing,
              greeting: _greeting(),
              weekTotal: HiveService.getLast7Days()
                  .fold(0.0, (s, d) => s + d.totalMoney),
              onRequestPermission: () async {
                await UsageStatsService.requestPermission();
              },
              onRefresh: _loadData,
              onWeeklyTap: () => setState(() => _selectedIndex = 1),
            ),
            AnalyticsScreen(embedded: true),
            SettingsScreen(embedded: true),
          ],
        ),
        bottomNavigationBar: _BottomNavBar(
          selectedIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
        ),
      ),
    );
  }
}

// ─── Bottom Nav Bar ───────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: const Border(
          top: BorderSide(color: Color(0xFF222222), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.donut_large_rounded,
                label: 'Today',
                selected: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.bar_chart_rounded,
                label: 'Analytics',
                selected: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                selected: selectedIndex == 2,
                onTap: () => onTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color:
                    selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dashboard Tab ────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final List<AppUsageModel> apps;
  final bool loading;
  final bool permissionMissing;
  final String greeting;
  final double weekTotal;
  final VoidCallback onRequestPermission;
  final Future<void> Function() onRefresh;
  final VoidCallback onWeeklyTap;

  const _DashboardTab({
    required this.apps,
    required this.loading,
    required this.permissionMissing,
    required this.greeting,
    required this.weekTotal,
    required this.onRequestPermission,
    required this.onRefresh,
    required this.onWeeklyTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final totalMoney = apps.fold(0.0, (s, a) => s + a.moneyCost);
    final totalMinutes = apps.fold(0, (s, a) => s + a.durationMinutes);

    return SafeArea(
      child: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.card,
              onRefresh: onRefresh,
              child: CustomScrollView(
                slivers: [
                  // ── Header ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/ic_launcher.png',
                            width: 32,
                            height: 32,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                'ScrollToll',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Premium Jar Header ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: permissionMissing
                          ? _PermissionBanner(onGrant: onRequestPermission)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "Today's Time Value",
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF8A8A8A),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 1200),
                                  curve: Curves.easeOutExpo,
                                  tween: Tween<double>(begin: 0, end: totalMoney),
                                  builder: (context, value, child) {
                                    return Text(
                                      "₹${value.toInt()}",
                                      style: textTheme.displaySmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -1,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF8A8A8A)),
                                    const SizedBox(width: 4),
                                    Text(
                                      MoneyCalculator.formatDuration(totalMinutes),
                                      style: textTheme.bodySmall?.copyWith(color: const Color(0xFF8A8A8A)),
                                    ),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Color(0xFF8A8A8A)),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Budget: ₹${HiveService.dailyBudget.toInt()}",
                                      style: textTheme.bodySmall?.copyWith(color: const Color(0xFF8A8A8A)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                TimeValueJar(
                                  percentageRemaining: (1.0 - (totalMoney / HiveService.dailyBudget)).clamp(0.0, 1.0),
                                  size: 240,
                                ),
                                const SizedBox(height: 24),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    _getJarCaption(totalMoney, HiveService.dailyBudget),
                                    key: ValueKey(totalMoney),
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF8A8A8A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  if (!permissionMissing) ...[
                    // ── Section title ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                        child: Text(
                          'Where your money went today',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),

                    // ── App list ──
                    if (apps.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              'No app usage recorded yet today',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => AppUsageTile(app: apps[i]),
                            childCount: apps.length,
                          ),
                        ),
                      ),


                  ],
                ],
              ),
            ),
    );
  }

  String _getJarCaption(double current, double budget) {
    if (current == 0) return "A perfect blank slate. Keep it up.";
    final ratio = current / budget;
    if (ratio < 0.2) return "You're doing great. Stay focused.";
    if (ratio < 0.5) return "Value is draining, but you're in control.";
    if (ratio < 0.8) return "Jar is getting low. Time to wrap up.";
    if (ratio < 1.0) return "Critical limits. Close the apps.";
    return "Budget exceeded. You've wasted your value today.";
  }
}

// ─── Permission Banner ────────────────────────────────────────────────────────

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onGrant;
  const _PermissionBanner({required this.onGrant});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Usage Access Required',
            style: textTheme.titleSmall?.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ScrollToll needs Usage Access permission to track screen time.',
            style: textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.black,
            ),
            onPressed: onGrant,
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }
}

class _WeekSummaryCard extends StatelessWidget {
  final double weekTotal;
  final VoidCallback onTap;
  const _WeekSummaryCard({required this.weekTotal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This week you\'ve wasted',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  MoneyCalculator.formatRupees(weekTotal),
                  style: textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  'Weekly Report',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward,
                    color: AppColors.primary, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

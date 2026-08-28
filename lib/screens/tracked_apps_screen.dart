import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';

import '../services/hive_service.dart';
import '../services/usage_stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class TrackedAppsScreen extends StatefulWidget {
  const TrackedAppsScreen({super.key});

  @override
  State<TrackedAppsScreen> createState() => _TrackedAppsScreenState();
}

class _TrackedAppsScreenState extends State<TrackedAppsScreen> {
  List<Application> _apps = [];
  bool _loading = true;
  Set<String> _trackedSet = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _trackedSet = HiveService.trackedApps.toSet();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final installed = (await DeviceApps.getInstalledApplications(
      includeSystemApps: true,
      onlyAppsWithLaunchIntent: true,
      includeAppIcons: true,
    )).where((a) => !excludedPackages.contains(a.packageName)).toList();
    installed.sort(
      (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
    );

    if (mounted) {
      setState(() {
        _apps = installed;
        _loading = false;
      });
    }
  }

  void _toggleTracked(String packageName, bool isTracked) {
    setState(() {
      if (isTracked) {
        _trackedSet.add(packageName);
      } else {
        _trackedSet.remove(packageName);
      }
    });
    HiveService.trackedApps = _trackedSet.toList();
  }

  /// Tracked apps float to the top, so the current selection is never buried
  /// in a long alphabetical list.
  List<Application> get _visibleApps {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? List<Application>.of(_apps)
        : _apps.where((a) => a.appName.toLowerCase().contains(q)).toList();
    filtered.sort((a, b) {
      final aTracked = _trackedSet.contains(a.packageName);
      final bTracked = _trackedSet.contains(b.packageName);
      if (aTracked != bTracked) return aTracked ? -1 : 1;
      return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final visible = _visibleApps;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Apps to Track'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_trackedSet.length} on',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: RottoLoader(message: 'Finding your apps…'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Only the apps you switch on count towards your daily '
                        'total.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          hintText: 'Search apps',
                          prefixIcon: Icon(Icons.search_rounded, size: 20),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? RottoEmptyState(
                          title: 'No matches',
                          message:
                              'No installed app matches '
                              '"${_query.trim()}".',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final app = visible[index];
                            final isTracked = _trackedSet.contains(
                              app.packageName,
                            );

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              // Material so the row's ink splash stays
                              // visible — see _SettingsGroup for the same
                              // reason.
                              child: Material(
                                color: isTracked
                                    ? AppColors.primarySoft
                                    : AppColors.card,
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: isTracked
                                        ? AppColors.primary.withValues(
                                            alpha: 0.35,
                                          )
                                        : AppColors.divider,
                                  ),
                                ),
                                child: SwitchListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 4,
                                  ),
                                  secondary: AppIconAvatar(
                                    packageName: app.packageName,
                                    appName: app.appName,
                                    size: 42,
                                  ),
                                  title: Text(
                                    app.appName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: isTracked
                                          ? AppColors.primaryDeep
                                          : AppColors.textPrimary,
                                      fontWeight: isTracked
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  value: isTracked,
                                  activeThumbColor: AppColors.card,
                                  activeTrackColor: AppColors.primary,
                                  onChanged: (val) =>
                                      _toggleTracked(app.packageName, val),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

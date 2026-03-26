import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import '../services/hive_service.dart';
import '../theme/app_theme.dart';

class TrackedAppsScreen extends StatefulWidget {
  const TrackedAppsScreen({super.key});

  @override
  State<TrackedAppsScreen> createState() => _TrackedAppsScreenState();
}

class _TrackedAppsScreenState extends State<TrackedAppsScreen> {
  List<Application> _apps = [];
  bool _loading = true;
  Set<String> _trackedSet = {};

  @override
  void initState() {
    super.initState();
    _trackedSet = HiveService.trackedApps.toSet();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final installed = await DeviceApps.getInstalledApplications(
      includeSystemApps: false,
      onlyAppsWithLaunchIntent: true,
      includeAppIcons: true,
    );
    installed.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
    
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Apps to Limit'),
        backgroundColor: AppColors.card,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "Select the exact apps (like Instagram, TikTok) you want to track. If an app isn't selected, it won't drain your Time Value Jar.",
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _apps.length,
                    itemBuilder: (context, index) {
                      final app = _apps[index];
                      final isTracked = _trackedSet.contains(app.packageName);
                      
                      Widget iconWidget;
                      if (app is ApplicationWithIcon) {
                        iconWidget = ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            app.icon,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        );
                      } else {
                        iconWidget = Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
                              style: textTheme.titleMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isTracked 
                              ? AppColors.danger.withOpacity(0.1) 
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: isTracked 
                              ? Border.all(color: AppColors.danger.withOpacity(0.5)) 
                              : Border.all(color: Colors.transparent),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          secondary: iconWidget,
                          title: Text(
                            app.appName,
                            style: textTheme.bodyLarge?.copyWith(
                              color: isTracked ? AppColors.danger : AppColors.textPrimary,
                              fontWeight: isTracked ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          value: isTracked,
                          activeColor: AppColors.danger,
                          onChanged: (val) => _toggleTracked(app.packageName, val),
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

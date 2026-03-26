import 'package:flutter/material.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/money_calculator.dart';
import 'tracked_apps_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool embedded;
  const SettingsScreen({super.key, this.embedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _budgetController;
  late bool _notificationsEnabled;
  late TimeOfDay _notifTime;

  @override
  void initState() {
    super.initState();
    _budgetController = TextEditingController(
      text: HiveService.dailyBudget > 0
          ? HiveService.dailyBudget.toStringAsFixed(0)
          : '150',
    );
    _notificationsEnabled = HiveService.notificationsEnabled;
    _notifTime = TimeOfDay(
      hour: HiveService.notificationHour,
      minute: HiveService.notificationMinute,
    );
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  void _saveBudget() {
    final val = double.tryParse(_budgetController.text.trim());
    if (val != null && val > 0) {
      HiveService.dailyBudget = val;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Budget updated')),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notifTime,
    );
    if (picked != null) {
      setState(() => _notifTime = picked);
      HiveService.notificationHour = picked.hour;
      HiveService.notificationMinute = picked.minute;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final budget = double.tryParse(_budgetController.text) ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.embedded ? null : AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: widget.embedded,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, widget.embedded ? 16 : 0, 16, 16),
          children: [
          _sectionHeader('Rules', textTheme),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _budgetController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        'Daily Budget Quota (${MoneyCalculator.rupeeSymbol})',
                    prefixText: '${MoneyCalculator.rupeeSymbol}  ',
                  ),
                  onChanged: (v) => setState(() {}),
                  onSubmitted: (_) => _saveBudget(),
                ),
                const SizedBox(height: 10),
                Text(
                  '1 minute spent = 1 point drained.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveBudget,
                    child: const Text('Save Budget'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionHeader('Rules', textTheme),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(Icons.ads_click, color: AppColors.danger),
              title: Text('Apps to Limit', style: textTheme.bodyMedium),
              subtitle: Text(
                'Select exactly which addicting apps drain your Jar',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrackedAppsScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader('Notifications', textTheme),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Daily Evening Report', style: textTheme.bodyMedium),
                  subtitle: Text(
                    'Receive a daily summary notification',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  value: _notificationsEnabled,
                  activeColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() => _notificationsEnabled = v);
                    HiveService.notificationsEnabled = v;
                    if (!v) NotificationService.cancel();
                  },
                ),
                if (_notificationsEnabled) ...[
                  const Divider(color: AppColors.divider, height: 1),
                  ListTile(
                    title: Text('Notification Time', style: textTheme.bodyMedium),
                    trailing: Text(
                      _notifTime.format(context),
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: _pickTime,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader('About ScrollToll', textTheme),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _faqTile(
                  'What is the Time Value Jar?',
                  'The premium jar on your home screen visualizes your daily budget. It starts completely full each day and aggressively drains dynamically based on the exact money value you waste on non-productive apps.',
                  textTheme,
                ),
                const Divider(color: AppColors.divider),
                _faqTile(
                  'How is the toll calculated?',
                  'Each minute you spend inside your specifically "Tracked Apps" instantly subtracts exactly 1 point from your daily Budget Quota.',
                  textTheme,
                ),
                const Divider(color: AppColors.divider),
                _faqTile(
                  'Why are some apps zero cost?',
                  'Unless you explicitly add an app to your "Apps to Limit" list above, the app ignores it. Read books or use Maps without penalty!',
                  textTheme,
                ),
                const Divider(color: AppColors.divider),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'App Version',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '1.0.0 (Launch Edition)',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: textTheme.labelLarge?.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _faqTile(String question, String answer, TextTheme textTheme) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        question,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      iconColor: AppColors.primary,
      collapsedIconColor: AppColors.textSecondary,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            answer,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

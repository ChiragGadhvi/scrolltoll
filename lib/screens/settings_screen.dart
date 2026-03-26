import 'package:flutter/material.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/money_calculator.dart';

class SettingsScreen extends StatefulWidget {
  final bool embedded;
  const SettingsScreen({super.key, this.embedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _salaryController;
  late bool _notificationsEnabled;
  late TimeOfDay _notifTime;

  @override
  void initState() {
    super.initState();
    _salaryController = TextEditingController(
      text: HiveService.monthlySalary > 0
          ? HiveService.monthlySalary.toStringAsFixed(0)
          : '',
    );
    _notificationsEnabled = HiveService.notificationsEnabled;
    _notifTime = TimeOfDay(
      hour: HiveService.notificationHour,
      minute: HiveService.notificationMinute,
    );
  }

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }

  void _saveSalary() {
    final val = double.tryParse(_salaryController.text.trim());
    if (val != null && val > 0) {
      HiveService.monthlySalary = val;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salary updated')),
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
    final salary = double.tryParse(_salaryController.text) ?? 0;
    final hourly = salary > 0 ? MoneyCalculator.hourlyRate(salary) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.embedded ? null : AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: widget.embedded,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, widget.embedded ? 16 : 0, 16, 16),
          children: [
          _sectionHeader('Salary', textTheme),
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
                  controller: _salaryController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        'Monthly Salary (${MoneyCalculator.rupeeSymbol})',
                    prefixText: '${MoneyCalculator.rupeeSymbol}  ',
                  ),
                  onChanged: (v) => setState(() {}),
                  onSubmitted: (_) => _saveSalary(),
                ),
                if (hourly > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Your time is worth ${MoneyCalculator.formatRupees(hourly)} per hour',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveSalary,
                    child: const Text('Save Salary'),
                  ),
                ),
              ],
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
          _sectionHeader('About', textTheme),
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
                  'How is this calculated?',
                  'We take your monthly salary, divide by 160 working hours to get your hourly rate, then multiply by time spent on each app.',
                  textTheme,
                ),
                const Divider(color: AppColors.divider),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Version',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '1.0.0',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
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

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/models/reminder_model.dart';
import '../screens/alarm_ringing_screen.dart';
import '../theme/app_colors.dart';

class SystemShieldDialog extends StatefulWidget {
  const SystemShieldDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const SystemShieldDialog(),
    );
  }

  @override
  State<SystemShieldDialog> createState() => _SystemShieldDialogState();
}

class _SystemShieldDialogState extends State<SystemShieldDialog> {
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  PermissionStatus _exactAlarmStatus = PermissionStatus.denied;
  PermissionStatus _batteryOptStatus = PermissionStatus.denied;
  PermissionStatus _locationStatus = PermissionStatus.denied;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);

    if (kIsWeb || (!kIsWeb && !Platform.isAndroid)) {
      setState(() {
        _notificationStatus = PermissionStatus.granted;
        _exactAlarmStatus = PermissionStatus.granted;
        _batteryOptStatus = PermissionStatus.granted;
        _locationStatus = PermissionStatus.granted;
        _isLoading = false;
      });
      return;
    }

    final notif = await Permission.notification.status;
    final alarm = await Permission.scheduleExactAlarm.status;
    final battery = await Permission.ignoreBatteryOptimizations.status;
    final location = await Permission.location.status;

    setState(() {
      _notificationStatus = notif;
      _exactAlarmStatus = alarm;
      _batteryOptStatus = battery;
      _locationStatus = location;
      _isLoading = false;
    });
  }

  Future<void> _requestAllReliabilityPermissions() async {
    if (!kIsWeb && Platform.isAndroid) {
      if (!_notificationStatus.isGranted) {
        await Permission.notification.request();
      }
      if (!_exactAlarmStatus.isGranted) {
        await Permission.scheduleExactAlarm.request();
      }
      if (!_batteryOptStatus.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
      if (!_locationStatus.isGranted) {
        await Permission.location.request();
      }
    }
    await _checkPermissions();
  }

  bool get _allReliable =>
      _notificationStatus.isGranted &&
      _exactAlarmStatus.isGranted &&
      _batteryOptStatus.isGranted;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.accent, size: 20),
          SizedBox(width: 10),
          Text(
            'System Reliability Shield',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 2,
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const Text(
                    'To ensure your reminders trigger to the second even under Android Doze mode and locked screens, grant the required background execution shields.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildStatusTile(
                    title: 'System Notifications',
                    subtitle: 'Allows showing alerts and banners',
                    isGranted: _notificationStatus.isGranted,
                    onTapRequest: () async {
                      await Permission.notification.request();
                      await _checkPermissions();
                    },
                  ),
                  const Divider(color: AppColors.cardBorder, height: 16),

                  _buildStatusTile(
                    title: 'Exact Alarm Scheduling',
                    subtitle: 'Required for to-the-second precision',
                    isGranted: _exactAlarmStatus.isGranted,
                    onTapRequest: () async {
                      await Permission.scheduleExactAlarm.request();
                      await _checkPermissions();
                    },
                  ),
                  const Divider(color: AppColors.cardBorder, height: 16),

                  _buildStatusTile(
                    title: 'Battery Optimization Shield',
                    subtitle: 'Prevents Android OS from killing alarms',
                    isGranted: _batteryOptStatus.isGranted,
                    onTapRequest: () async {
                      await Permission.ignoreBatteryOptimizations.request();
                      await _checkPermissions();
                    },
                  ),
                  const Divider(color: AppColors.cardBorder, height: 16),

                  _buildStatusTile(
                    title: 'Location Triggers (Geofencing)',
                    subtitle: 'Required for arrival and departure alerts',
                    isGranted: _locationStatus.isGranted,
                    onTapRequest: () async {
                      await Permission.location.request();
                      await _checkPermissions();
                    },
                  ),
                  const SizedBox(height: 20),

                  if (!_allReliable)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _requestAllReliabilityPermissions,
                        icon: const Icon(Icons.bolt, size: 18),
                        label: const Text(
                          'Enable Reliable Background Alarms',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'All system shields active. Background reminders are 100% reliable.',
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
      ),
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.cardBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              AlarmRingingScreen.route(
                reminder: Reminder(
                  title: 'Critical Standup Alarm',
                  notes: 'Sync with executive design leads on Phase 4 launch.',
                  alertSeverity: ReminderAlertSeverity.strongFullscreen,
                  dueDatetime: DateTime.now(),
                  createdAt: DateTime.now(),
                ),
              ),
            );
          },
          icon: const Icon(Icons.alarm, size: 14),
          label: const Text(
            'Test Alarm Screen',
            style: TextStyle(fontSize: 12),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildStatusTile({
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTapRequest,
  }) {
    return Row(
      children: [
        Icon(
          isGranted ? Icons.check_circle : Icons.warning_amber_rounded,
          color: isGranted ? AppColors.success : AppColors.warning,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (!isGranted)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onTapRequest,
            child: const Text('Grant'),
          ),
      ],
    );
  }
}

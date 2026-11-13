import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/models/reminder_model.dart';
import '../screens/alarm_ringing_screen.dart';

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
        _isLoading = false;
      });
      return;
    }

    final notif = await Permission.notification.status;
    final alarm = await Permission.scheduleExactAlarm.status;
    final battery = await Permission.ignoreBatteryOptimizations.status;

    setState(() {
      _notificationStatus = notif;
      _exactAlarmStatus = alarm;
      _batteryOptStatus = battery;
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
    }
    await _checkPermissions();
  }

  bool get _allReliable =>
      _notificationStatus.isGranted &&
      _exactAlarmStatus.isGranted &&
      _batteryOptStatus.isGranted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Colors.blue),
          SizedBox(width: 10),
          Text('System Reliability Shield'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To ensure your reminders trigger on time even when the device is locked, asleep, or in Doze mode, ensure all system permissions are granted.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Notifications status item
                  _buildStatusTile(
                    title: 'System Notifications',
                    subtitle: 'Allows showing alerts and banners',
                    isGranted: _notificationStatus.isGranted,
                    onTapRequest: () async {
                      await Permission.notification.request();
                      await _checkPermissions();
                    },
                  ),
                  const Divider(height: 16),

                  // Exact Alarms status item
                  _buildStatusTile(
                    title: 'Exact Alarm Scheduling',
                    subtitle: 'Required for to-the-second precision',
                    isGranted: _exactAlarmStatus.isGranted,
                    onTapRequest: () async {
                      await Permission.scheduleExactAlarm.request();
                      await _checkPermissions();
                    },
                  ),
                  const Divider(height: 16),

                  // Battery Optimization Shield item
                  _buildStatusTile(
                    title: 'Battery Optimization Shield',
                    subtitle: 'Prevents Android OS from killing alarms',
                    isGranted: _batteryOptStatus.isGranted,
                    onTapRequest: () async {
                      await Permission.ignoreBatteryOptimizations.request();
                      await _checkPermissions();
                    },
                  ),
                  const SizedBox(height: 20),

                  // Big Action Button
                  if (!_allReliable)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _requestAllReliabilityPermissions,
                        icon: const Icon(Icons.bolt),
                        label: const Text(
                          'Enable Reliable Background Alarms',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'All system shields active. Background reminders are 100% reliable.',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        OutlinedButton.icon(
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
          icon: const Icon(Icons.alarm, size: 16),
          label: const Text('Test Alarm Screen'),
        ),
        TextButton(
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
          color: isGranted ? Colors.green : Colors.amber.shade800,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (!isGranted)
          TextButton(
            onPressed: onTapRequest,
            child: const Text('Grant'),
          ),
      ],
    );
  }
}

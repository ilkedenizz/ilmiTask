import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';

class SystemShieldBanner extends StatefulWidget {
  final VoidCallback onOpenShieldDialog;

  const SystemShieldBanner({
    super.key,
    required this.onOpenShieldDialog,
  });

  @override
  State<SystemShieldBanner> createState() => _SystemShieldBannerState();
}

class _SystemShieldBannerState extends State<SystemShieldBanner> {
  bool _isShieldActive = true;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (kIsWeb || (!kIsWeb && !Platform.isAndroid)) {
      setState(() => _isShieldActive = true);
      return;
    }

    final notif = await Permission.notification.isGranted;
    final alarm = await Permission.scheduleExactAlarm.isGranted;
    final battery = await Permission.ignoreBatteryOptimizations.isGranted;

    if (mounted) {
      setState(() {
        _isShieldActive = notif && alarm && battery;
      });
    }
  }

  Future<void> _requestOptimizationFix() async {
    if (!kIsWeb && Platform.isAndroid) {
      await Permission.notification.request();
      await Permission.scheduleExactAlarm.request();
      await Permission.ignoreBatteryOptimizations.request();
      await _checkStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isShieldActive || _isDismissed) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentAmber.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.battery_alert,
                color: AppColors.accentAmber,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Battery Optimization is Active',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.accentAmber,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                onPressed: () => setState(() => _isDismissed = true),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Your device may delay alarms in sleep mode. Allow background execution so scheduled reminders always wake your screen.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentAmber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _requestOptimizationFix,
                child: const Text(
                  'Enable Reliable Background Alarms',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: widget.onOpenShieldDialog,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

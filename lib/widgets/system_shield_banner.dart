import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.battery_alert,
                color: Colors.amber.shade900,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Battery Optimization is Active',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.close, size: 18, color: Colors.amber.shade900),
                onPressed: () => setState(() => _isDismissed = true),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Your device may delay alarms when in sleep mode. Allow background execution so scheduled reminders always wake your screen.',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.brown.shade800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade200,
                  foregroundColor: Colors.brown.shade900,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _requestOptimizationFix,
                child: const Text(
                  'Enable Reliable Background Alarms',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: widget.onOpenShieldDialog,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
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

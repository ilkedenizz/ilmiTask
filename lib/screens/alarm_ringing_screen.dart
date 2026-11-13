import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/reminder_model.dart';
import '../data/models/subtask_model.dart';
import '../data/repositories/reminder_repository.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class AlarmRingingScreen extends StatefulWidget {
  final int? reminderId;
  final Reminder? reminder;
  final ReminderRepository? repository;

  const AlarmRingingScreen({
    super.key,
    this.reminderId,
    this.reminder,
    this.repository,
  });

  static MaterialPageRoute route({
    int? reminderId,
    Reminder? reminder,
    ReminderRepository? repository,
  }) {
    return MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => AlarmRingingScreen(
        reminderId: reminderId,
        reminder: reminder,
        repository: repository,
      ),
    );
  }

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen>
    with SingleTickerProviderStateMixin {
  late final ReminderRepository _repository;
  Reminder? _reminder;
  bool _isLoading = true;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ReminderRepository();

    // Subtle pulsing animation for status pill dot
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Live clock timer
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });

    _loadReminder();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _clockTimer = null;
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadReminder() async {
    if (widget.reminder != null) {
      if (!mounted) return;
      setState(() {
        _reminder = widget.reminder;
        _isLoading = false;
      });
      return;
    }

    if (widget.reminderId != null) {
      final fetched = await _repository.getReminderById(widget.reminderId!);
      if (!mounted) return;
      setState(() {
        _reminder = fetched;
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _toggleSubtask(Subtask subtask) async {
    if (subtask.id == null || _reminder == null) return;
    final newDone = !subtask.isDone;
    await _repository.toggleSubtaskCompletion(subtask.id!, newDone);

    if (mounted) {
      setState(() {
        final updatedSubtasks = _reminder!.subtasks.map((st) {
          if (st.id == subtask.id) {
            return st.copyWith(isDone: newDone);
          }
          return st;
        }).toList();
        _reminder = _reminder!.copyWith(subtasks: updatedSubtasks);
      });
    }
  }

  Future<void> _snoozeTenMinutes() async {
    if (_reminder == null || _reminder!.id == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    await NotificationService.instance
        .cancelReminderNotification(_reminder!.id!);

    final snoozedDue = DateTime.now().add(const Duration(minutes: 10));
    final updatedReminder = _reminder!.copyWith(
      dueDatetime: snoozedDue,
      isCompleted: false,
    );

    await _repository.updateReminder(updatedReminder, syncSubtasks: false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alarm snoozed for 10 minutes'),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _dismissAndComplete() async {
    if (_reminder != null && _reminder!.id != null) {
      await _repository.toggleReminderCompletion(_reminder!.id!, true);
    } else if (widget.reminderId != null) {
      await _repository.toggleReminderCompletion(widget.reminderId!, true);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm:ss').format(_currentTime);
    final dateStr = DateFormat('EEE, MMM d').format(_currentTime).toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2,
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // Minimal status pill (● ALARM ACTIVE)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1416),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FadeTransition(
                            opacity: _pulseAnimation,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Text(
                            'ALARM ACTIVE',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Massive Editorial Monospace Clock
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 60,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -2.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Structured Matte Card for Task & Checklist
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _reminder?.title ?? 'Alarm Alert',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (_reminder?.notes != null &&
                                  _reminder!.notes!.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _reminder!.notes!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],

                              // Attached Photo Preview
                              if (_reminder?.imagePath != null &&
                                  File(_reminder!.imagePath!).existsSync()) ...[
                                const SizedBox(height: 14),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(_reminder!.imagePath!),
                                    width: double.infinity,
                                    height: 150,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],

                              // Interactive Monospace Checklist Container
                              if (_reminder != null &&
                                  _reminder!.subtasks.isNotEmpty) ...[
                                const SizedBox(height: 18),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.subtaskContainer,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.cardBorder,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'CHECKLIST (${_reminder!.subtasks.where((s) => s.isDone).length}/${_reminder!.subtasks.length})',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textMuted,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ..._reminder!.subtasks.map((st) {
                                        return InkWell(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          onTap: () => _toggleSubtask(st),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                              horizontal: 4,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 16,
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                    border: Border.all(
                                                      color: st.isDone
                                                          ? AppColors.accent
                                                          : AppColors
                                                              .textMuted,
                                                      width: 1.2,
                                                    ),
                                                    color: st.isDone
                                                        ? AppColors.accent
                                                        : Colors.transparent,
                                                  ),
                                                  child: st.isDone
                                                      ? const Icon(
                                                          Icons.check,
                                                          size: 11,
                                                          color: Colors.black,
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    st.title,
                                                    style: TextStyle(
                                                      fontSize: 13.5,
                                                      color: st.isDone
                                                          ? AppColors.textMuted
                                                          : AppColors
                                                              .textPrimary,
                                                      decoration: st.isDone
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Architectural Action Buttons
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Snooze Outlined Slate Button
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.borderInteractive,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                foregroundColor: AppColors.textSecondary,
                              ),
                              onPressed: _snoozeTenMinutes,
                              child: const Text(
                                'Snooze (+10m)',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Dismiss Solid High-Contrast Off-White Button
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.textPrimary,
                                foregroundColor: AppColors.canvas,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _dismissAndComplete,
                              child: const Text(
                                'Dismiss / Done',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
      ),
    );
  }
}

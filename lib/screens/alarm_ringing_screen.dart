import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/reminder_model.dart';
import '../data/models/subtask_model.dart';
import '../data/repositories/reminder_repository.dart';
import '../services/notification_service.dart';

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

    // Pulse animation for alarm icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
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

    // Cancel current ringing notification sound/heads-up
    await NotificationService.instance.cancelReminderNotification(_reminder!.id!);

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
      // Mark as completed in SQLite and stop notification
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
    final timeStr = DateFormat('HH:mm').format(_currentTime);
    final dateStr = DateFormat('EEEE, MMMM d').format(_currentTime);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115), // Deep dark high-contrast
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // Live digital clock & date
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        letterSpacing: -1.5,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Pulsing animated alarm badge
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.6),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.alarm,
                          size: 42,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Reminder Details & Interactive Checklist Container
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Title
                            Text(
                              _reminder?.title ?? 'Alarm Alert',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (_reminder?.notes != null &&
                                _reminder!.notes!.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                _reminder!.notes!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],

                            // Attached Image Preview
                            if (_reminder?.imagePath != null &&
                                File(_reminder!.imagePath!).existsSync()) ...[
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  File(_reminder!.imagePath!),
                                  width: double.infinity,
                                  height: 170,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],

                            // Interactive Checklist Items
                            if (_reminder != null &&
                                _reminder!.subtasks.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.checklist,
                                          color: Colors.white70,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'CHECKLIST (${_reminder!.subtasks.where((s) => s.isDone).length}/${_reminder!.subtasks.length})',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ..._reminder!.subtasks.map((st) {
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => _toggleSubtask(st),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                            horizontal: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                st.isDone
                                                    ? Icons.check_box
                                                    : Icons
                                                        .check_box_outline_blank,
                                                color: st.isDone
                                                    ? Colors.greenAccent
                                                    : Colors.white60,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  st.title,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: st.isDone
                                                        ? Colors.white38
                                                        : Colors.white,
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

                    // Action Buttons (Snooze + Dismiss)
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Snooze Button
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Colors.white54,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _snoozeTenMinutes,
                              icon: const Icon(Icons.snooze, size: 22),
                              label: const Text(
                                'Snooze (+10m)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Dismiss & Complete Button
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.redAccent.shade400,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              onPressed: _dismissAndComplete,
                              icon: const Icon(Icons.check, size: 22),
                              label: const Text(
                                'Dismiss / Done',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
      ),
    );
  }
}

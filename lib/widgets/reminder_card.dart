import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models/reminder_model.dart';
import '../data/models/subtask_model.dart';
import '../theme/app_colors.dart';

class ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final ValueChanged<bool> onToggleComplete;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final ValueChanged<Subtask> onToggleSubtask;

  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onToggleComplete,
    required this.onTogglePin,
    required this.onDelete,
    required this.onTap,
    required this.onToggleSubtask,
  });

  Color _parseCategoryColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.accent;
    try {
      final formatted = hex.replaceFirst('#', '');
      return Color(int.parse('FF$formatted', radix: 16));
    } catch (_) {
      return AppColors.accent;
    }
  }

  String _formatDueDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(dt.year, dt.month, dt.day);
    final timeStr = DateFormat('HH:mm').format(dt);

    if (reminderDate == today) {
      return 'Today $timeStr';
    } else if (reminderDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow $timeStr';
    } else if (reminderDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday $timeStr';
    } else if (dt.year == now.year) {
      return DateFormat('MMM d • HH:mm').format(dt);
    } else {
      return DateFormat('yyyy.MM.dd • HH:mm').format(dt);
    }
  }

  String? _extractFirstUrl(String? text) {
    if (text == null || text.isEmpty) return null;
    final urlRegExp = RegExp(r'https?://[^\s<>"]+');
    final match = urlRegExp.firstMatch(text);
    return match?.group(0);
  }

  bool get _isOverdue {
    if (reminder.dueDatetime == null || reminder.isCompleted) return false;
    return reminder.dueDatetime!.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _parseCategoryColor(reminder.category?.colorHex);

    return Dismissible(
      key: Key('reminder_${reminder.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0F291E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(
              reminder.isCompleted
                  ? Icons.replay
                  : Icons.check_circle_outline,
              color: AppColors.success,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              reminder.isCompleted ? 'REOPEN' : 'COMPLETE',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1012),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.danger.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'DELETE',
              style: TextStyle(
                fontFamily: 'monospace',
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onToggleComplete(!reminder.isCompleted);
          return false;
        }
        return true;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: reminder.isPinned
                ? AppColors.accent.withValues(alpha: 0.5)
                : AppColors.cardBorder,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 3px category color accent bar
                Container(
                  width: 3.5,
                  color: catColor,
                ),

                // Main Card Content
                Expanded(
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Custom circular checkbox, Title, Pin badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sleek circular checkbox
                              GestureDetector(
                                onTap: () =>
                                    onToggleComplete(!reminder.isCompleted),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  margin: const EdgeInsets.only(top: 2, right: 12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: reminder.isCompleted
                                          ? AppColors.accent
                                          : AppColors.textMuted,
                                      width: 1.5,
                                    ),
                                    color: reminder.isCompleted
                                        ? AppColors.accent
                                        : Colors.transparent,
                                  ),
                                  child: reminder.isCompleted
                                      ? const Icon(
                                          Icons.check,
                                          size: 13,
                                          color: Colors.black,
                                        )
                                      : null,
                                ),
                              ),

                              // Title and Notes
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            reminder.title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -0.3,
                                              color: reminder.isCompleted
                                                  ? AppColors.textMuted
                                                  : AppColors.textPrimary,
                                              decoration: reminder.isCompleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        if (reminder.isPinned)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 6),
                                            child: Icon(
                                              Icons.push_pin,
                                              size: 14,
                                              color: AppColors.accent,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (reminder.notes != null &&
                                        reminder.notes!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        reminder.notes!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: reminder.isCompleted
                                              ? AppColors.textMuted
                                                  .withValues(alpha: 0.6)
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                    if (_extractFirstUrl(reminder.notes) !=
                                        null) ...[
                                      const SizedBox(height: 5),
                                      GestureDetector(
                                        onTap: () async {
                                          final url = _extractFirstUrl(
                                              reminder.notes);
                                          if (url != null) {
                                            final uri = Uri.tryParse(url);
                                            if (uri != null) {
                                              await launchUrl(
                                                uri,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            }
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceInteractive,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: AppColors.borderInteractive,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.open_in_new,
                                                size: 10,
                                                color: AppColors.accent,
                                              ),
                                              const SizedBox(width: 4),
                                              const Text(
                                                '[ ↗ OPEN LINK ]',
                                                style: TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.accent,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Flexible(
                                                child: Text(
                                                  _extractFirstUrl(
                                                          reminder.notes) ??
                                                      '',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 9.5,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Optional thumbnail preview
                              if (reminder.imagePath != null &&
                                  File(reminder.imagePath!).existsSync()) ...[
                                const SizedBox(width: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    File(reminder.imagePath!),
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Indented Minimal Subtasks Checklist
                          if (reminder.subtasks.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              margin: const EdgeInsets.only(left: 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.subtaskContainer,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.cardBorder.withValues(alpha: 0.6),
                                  width: 0.8,
                                ),
                              ),
                              child: Column(
                                children: reminder.subtasks.map((st) {
                                  return InkWell(
                                    onTap: () => onToggleSubtask(st),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 3.5,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              border: Border.all(
                                                color: st.isDone
                                                    ? AppColors.accent
                                                    : AppColors.textMuted,
                                                width: 1.2,
                                              ),
                                              color: st.isDone
                                                  ? AppColors.accent
                                                  : Colors.transparent,
                                            ),
                                            child: st.isDone
                                                ? const Icon(
                                                    Icons.check,
                                                    size: 10,
                                                    color: Colors.black,
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              st.title,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: st.isDone
                                                    ? AppColors.textMuted
                                                    : AppColors.textSecondary,
                                                decoration: st.isDone
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],

                          // Precision Monospace Metadata Row
                          const SizedBox(height: 9),
                          Padding(
                            padding: const EdgeInsets.only(left: 32),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Due date in monospace
                                if (reminder.dueDatetime != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        size: 12,
                                        color: _isOverdue
                                            ? AppColors.danger
                                            : AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDueDate(reminder.dueDatetime!),
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          letterSpacing: -0.2,
                                          fontWeight: FontWeight.w500,
                                          color: _isOverdue
                                              ? AppColors.danger
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),

                                // Pre-Alert tag
                                if (reminder.earlyAlertMinutes > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.hourglass_top,
                                        size: 11,
                                        color: AppColors.accentAmber,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '-${reminder.earlyAlertMinutes}m',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.accentAmber,
                                        ),
                                      ),
                                    ],
                                  ),

                                // Repeat rule
                                if (reminder.repeatRule !=
                                    ReminderRepeatRule.none)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.repeat,
                                        size: 11,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        reminder.repeatRule,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),

                                // Alarm indicator
                                if (reminder.alertSeverity ==
                                    ReminderAlertSeverity.strongFullscreen)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.alarm,
                                        size: 11,
                                        color: AppColors.danger,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'ALARM',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.danger,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),

                                // Location badge
                                if (reminder.locationLat != null &&
                                    reminder.locationLng != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        size: 11,
                                        color: AppColors.accent,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '📍 ${(reminder.locationTriggerType ?? "arrive").toUpperCase()} • ${reminder.locationRadius?.toInt() ?? 250}m',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.accent,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),

                                // Category text indicator
                                if (reminder.category != null)
                                  Text(
                                    reminder.category!.name.toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: catColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

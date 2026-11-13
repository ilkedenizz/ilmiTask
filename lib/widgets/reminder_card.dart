import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/reminder_model.dart';
import '../data/models/subtask_model.dart';

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

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF2196F3);
    try {
      final formatted = hex.replaceFirst('#', '');
      return Color(int.parse('FF$formatted', radix: 16));
    } catch (_) {
      return const Color(0xFF2196F3);
    }
  }

  String _formatDueDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(dt.year, dt.month, dt.day);
    final timeStr = DateFormat('HH:mm').format(dt);

    if (reminderDate == today) {
      return 'Today, $timeStr';
    } else if (reminderDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow, $timeStr';
    } else if (reminderDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $timeStr';
    } else if (dt.year == now.year) {
      return DateFormat('EEE, MMM d • HH:mm').format(dt);
    } else {
      return DateFormat('MMM d, y • HH:mm').format(dt);
    }
  }

  bool get _isOverdue {
    if (reminder.dueDatetime == null || reminder.isCompleted) return false;
    return reminder.dueDatetime!.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = _parseColor(reminder.category?.colorHex);

    return Dismissible(
      key: Key('reminder_${reminder.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: reminder.isPinned ? Colors.blueGrey : Colors.amber.shade700,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(
              reminder.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              reminder.isPinned ? 'Unpin' : 'Pin',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white, size: 26),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right: Toggle Pin (do not dismiss card)
          onTogglePin();
          return false;
        } else {
          // Swipe left: Delete
          onDelete();
          return true;
        }
      },
      child: Card(
        elevation: reminder.isPinned ? 2 : 0.8,
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: reminder.isPinned
              ? BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  width: 1.5,
                )
              : BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: 1,
                ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Checkbox, Title, Category Badge, Pin Icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Completion checkbox
                    Transform.scale(
                      scale: 1.1,
                      child: Checkbox(
                        value: reminder.isCompleted,
                        shape: const CircleBorder(),
                        activeColor: theme.colorScheme.primary,
                        onChanged: (val) {
                          if (val != null) onToggleComplete(val);
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Title and Notes
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (reminder.category != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: categoryColor.withValues(alpha: 0.6),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    reminder.category!.name,
                                    style: TextStyle(
                                      color: categoryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (reminder.isPinned)
                                Icon(
                                  Icons.push_pin,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reminder.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: reminder.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: reminder.isCompleted
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          if (reminder.notes != null &&
                              reminder.notes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              reminder.notes!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: reminder.isCompleted
                                    ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Optional image thumbnail
                    if (reminder.imagePath != null &&
                        File(reminder.imagePath!).existsSync()) ...[
                      const SizedBox(width: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(reminder.imagePath!),
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ],
                ),

                // Interactive Subtasks Checklist
                if (reminder.subtasks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.only(left: 36),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: reminder.subtasks.map((st) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => onToggleSubtask(st),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 3.0,
                              horizontal: 2.0,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  st.isDone
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  size: 19,
                                  color: st.isDone
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    st.title,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: st.isDone
                                          ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                          : theme.colorScheme.onSurface,
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

                // Metadata Badges Row (Due date, Early alert, Repeat, Severity, Image icon)
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Due date badge
                      if (reminder.dueDatetime != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _isOverdue
                                ? Colors.red.withValues(alpha: 0.12)
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_filled,
                                size: 14,
                                color: _isOverdue
                                    ? Colors.red
                                    : theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDueDate(reminder.dueDatetime!),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: _isOverdue
                                      ? Colors.red
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Early alert pre-notification badge
                      if (reminder.earlyAlertMinutes > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.hourglass_top,
                                size: 13,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '-${reminder.earlyAlertMinutes}m',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Repeat badge
                      if (reminder.repeatRule != ReminderRepeatRule.none)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.repeat,
                                size: 13,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                reminder.repeatRule,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Strong / Full-screen Alarm badge
                      if (reminder.alertSeverity ==
                          ReminderAlertSeverity.strongFullscreen)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.alarm, size: 13, color: Colors.red),
                              SizedBox(width: 3),
                              Text(
                                'Alarm',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Image attachment indicator if not already thumbnail
                      if (reminder.imagePath != null &&
                          !File(reminder.imagePath!).existsSync())
                        Icon(
                          Icons.image,
                          size: 15,
                          color: theme.colorScheme.outline,
                        ),
                    ],
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

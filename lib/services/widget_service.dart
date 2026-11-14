import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/models/reminder_model.dart';

class WidgetService {
  static const MethodChannel _channel = MethodChannel('com.samsung.reminder/widget');

  /// Updates the native Android Home Screen Widget with today's reminder count and top 2 tasks
  static Future<void> syncWidgetData(List<Reminder> reminders) async {
    if (kIsWeb) return;

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Filter active (uncompleted) reminders due today
      final todayTasks = reminders.where((r) {
        if (r.isCompleted || r.dueDatetime == null) return false;
        return r.dueDatetime!.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
            r.dueDatetime!.isBefore(todayEnd);
      }).toList();

      todayTasks.sort((a, b) => a.dueDatetime!.compareTo(b.dueDatetime!));

      String? task1;
      String? task2;

      if (todayTasks.isNotEmpty) {
        final t = todayTasks[0];
        final timeStr = DateFormat('HH:mm').format(t.dueDatetime!);
        task1 = '$timeStr • ${t.title}';
      }

      if (todayTasks.length > 1) {
        final t = todayTasks[1];
        final timeStr = DateFormat('HH:mm').format(t.dueDatetime!);
        task2 = '$timeStr • ${t.title}';
      }

      await _channel.invokeMethod('updateWidgetData', {
        'todayCount': todayTasks.length,
        'task1': task1,
        'task2': task2,
      });
    } catch (e) {
      debugPrint('Widget sync error: $e');
    }
  }

  /// Sets up a callback to open the editor if user tapped quick-add '+' on widget
  static void listenForQuickAdd(VoidCallback onQuickAdd) {
    if (kIsWeb) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onQuickAddRequested') {
        onQuickAdd();
      }
    });

    // Check if app was initially cold-started by quick-add button
    _channel.invokeMethod<bool>('checkQuickAddIntent').then((isQuickAdd) {
      if (isQuickAdd == true) {
        onQuickAdd();
      }
    }).catchError((_) {});
  }
}

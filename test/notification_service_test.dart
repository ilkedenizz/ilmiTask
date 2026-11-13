import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/data/models/reminder_model.dart';
import 'package:reminder_app/services/notification_service.dart';

class RecordingNotificationService extends NotificationService {
  final List<Reminder> scheduledReminders = [];
  final List<int> cancelledReminderIds = [];

  RecordingNotificationService();

  @override
  Future<void> scheduleReminderNotification(Reminder reminder) async {
    if (reminder.dueDatetime == null || reminder.isCompleted) {
      await cancelReminderNotification(reminder.id!);
      return;
    }
    scheduledReminders.add(reminder);
  }

  @override
  Future<void> cancelReminderNotification(int reminderId) async {
    cancelledReminderIds.add(reminderId);
    cancelledReminderIds.add(reminderId + NotificationService.earlyAlertIdOffset);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Tier & Channel Definitions', () {
    test('Notification channels match alert severities', () {
      expect(NotificationService.lightChannelId, 'light_channel');
      expect(NotificationService.shortChannelId, 'short_channel');
      expect(NotificationService.strongFullscreenChannelId, 'strong_fullscreen_channel');
      expect(NotificationService.earlyAlertIdOffset, 100000);
    });

    test('Early alert ID calculation is offset by 100,000', () {
      const reminderId = 42;
      const expectedEarlyId = 100042;
      expect(reminderId + NotificationService.earlyAlertIdOffset, expectedEarlyId);
    });

    test('Schedule and cancel tracking via RecordingNotificationService', () async {
      final service = RecordingNotificationService();
      final now = DateTime.now();

      final reminder = Reminder(
        id: 7,
        title: 'Standup Meeting',
        dueDatetime: now.add(const Duration(minutes: 30)),
        earlyAlertMinutes: 10,
        alertSeverity: ReminderAlertSeverity.strongFullscreen,
        repeatRule: ReminderRepeatRule.daily,
        createdAt: now,
      );

      await service.scheduleReminderNotification(reminder);
      expect(service.scheduledReminders.length, 1);
      expect(service.scheduledReminders.first.id, 7);
      expect(service.scheduledReminders.first.alertSeverity, 'strong_fullscreen');

      await service.cancelReminderNotification(7);
      expect(service.cancelledReminderIds, containsAll([7, 100007]));
    });

    test('Completed reminder cancels notification instead of scheduling', () async {
      final service = RecordingNotificationService();
      final now = DateTime.now();

      final reminder = Reminder(
        id: 12,
        title: 'Finished Task',
        isCompleted: true,
        dueDatetime: now.add(const Duration(hours: 1)),
        createdAt: now,
      );

      await service.scheduleReminderNotification(reminder);
      expect(service.scheduledReminders, isEmpty);
      expect(service.cancelledReminderIds, contains(12));
    });

    test('Reminder with null dueDatetime cancels notifications', () async {
      final service = RecordingNotificationService();
      final now = DateTime.now();

      final reminder = Reminder(
        id: 15,
        title: 'No Alert Task',
        dueDatetime: null,
        createdAt: now,
      );

      await service.scheduleReminderNotification(reminder);
      expect(service.scheduledReminders, isEmpty);
      expect(service.cancelledReminderIds, contains(15));
    });
  });
}

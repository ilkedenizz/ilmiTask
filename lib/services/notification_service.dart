import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../data/models/reminder_model.dart';

class NotificationService {
  static const String lightChannelId = 'light_channel';
  static const String lightChannelName = 'Light Notifications';
  static const String lightChannelDesc = 'Silent low-priority reminder alerts';

  static const String shortChannelId = 'short_channel';
  static const String shortChannelName = 'Standard Reminders';
  static const String shortChannelDesc =
      'Default sound and vibration reminder alerts';

  static const String strongFullscreenChannelId = 'strong_fullscreen_channel';
  static const String strongFullscreenChannelName =
      'Critical / Full-Screen Alarms';
  static const String strongFullscreenChannelDesc =
      'High urgency full-screen alarms with looping sound and heavy vibration';

  /// Offset applied to create unique notification IDs for early alerts
  static const int earlyAlertIdOffset = 100000;

  /// Action IDs for interactive notification buttons
  static const String actionComplete = 'action_complete';
  static const String actionSnooze = 'action_snooze';

  // Singleton instance
  static NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isInitialized = false;

  NotificationService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notificationsPlugin =
            notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  NotificationService._internal({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notificationsPlugin =
            notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin get plugin => _notificationsPlugin;
  bool get isInitialized => _isInitialized;

  /// Initializes the local notification plugin, creates channels, and sets up timezones
  Future<void> initialize({
    void Function(NotificationResponse)? onNotificationResponse,
  }) async {
    if (_isInitialized) return;

    _setupTimeZone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open reminder',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: onNotificationResponse,
      );
    } catch (e) {
      debugPrint('Warning: Notification plugin primary init failed: $e');
      try {
        const fallbackSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: darwinSettings,
          macOS: darwinSettings,
          linux: linuxSettings,
        );
        await _notificationsPlugin.initialize(
          settings: fallbackSettings,
          onDidReceiveNotificationResponse: onNotificationResponse,
        );
      } catch (fallbackError) {
        debugPrint('Warning: Notification plugin fallback init failed: $fallbackError');
      }
    }

    try {
      await _createNotificationChannels();
    } catch (e) {
      debugPrint('Warning: Notification channel creation failed: $e');
    }

    _isInitialized = true;
  }

  void _setupTimeZone() {
    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Warning: Timezone initialization error: $e');
    }

    try {
      final String timeZoneName = DateTime.now().timeZoneName;
      if (tz.timeZoneDatabase.locations.containsKey(timeZoneName)) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        return;
      }
      // Match by timezone offset (Duration)
      final currentOffset = DateTime.now().timeZoneOffset;
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (location.currentTimeZone.offset == currentOffset) {
          tz.setLocalLocation(location);
          return;
        }
      }
    } catch (e) {
      debugPrint('Warning: Local timezone resolution error: $e');
    }

    try {
      tz.setLocalLocation(tz.UTC);
    } catch (_) {}
  }

  Future<void> _createNotificationChannels() async {
    // Channels are an Android platform feature
    if (kIsWeb || (!kIsWeb && !Platform.isAndroid)) {
      return;
    }

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Channel 1: Light (Silent, no vibration, drops into notification shade)
    const lightChannel = AndroidNotificationChannel(
      lightChannelId,
      lightChannelName,
      description: lightChannelDesc,
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    // Channel 2: Short (Standard sound and vibration)
    const shortChannel = AndroidNotificationChannel(
      shortChannelId,
      shortChannelName,
      description: shortChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Channel 3: Strong / Full Screen (Max priority, alarm audio usage, looping insistent alert, heavy vibration)
    final strongFullscreenChannel = AndroidNotificationChannel(
      strongFullscreenChannelId,
      strongFullscreenChannelName,
      description: strongFullscreenChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    await androidPlugin.createNotificationChannel(lightChannel);
    await androidPlugin.createNotificationChannel(shortChannel);
    await androidPlugin.createNotificationChannel(strongFullscreenChannel);
  }

  /// Returns Android notification details matching the alert severity tier
  NotificationDetails _buildNotificationDetails({
    required String alertSeverity,
    required String title,
    required String body,
  }) {
    AndroidNotificationDetails androidDetails;

    const actions = <AndroidNotificationAction>[
      AndroidNotificationAction(
        actionComplete,
        '✓ Tamamla / Done',
        showsUserInterface: false,
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        actionSnooze,
        '🕒 Ertele / Snooze (+10m)',
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ];

    switch (alertSeverity) {
      case ReminderAlertSeverity.light:
        androidDetails = const AndroidNotificationDetails(
          lightChannelId,
          lightChannelName,
          channelDescription: lightChannelDesc,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          color: Color(0xFFFF5500),
          category: AndroidNotificationCategory.reminder,
        );
        break;

      case ReminderAlertSeverity.strongFullscreen:
        androidDetails = AndroidNotificationDetails(
          strongFullscreenChannelId,
          strongFullscreenChannelName,
          channelDescription: strongFullscreenChannelDesc,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern:
              Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
          // Flag 4 = FLAG_INSISTENT: keeps alarm sound looping until user responds
          additionalFlags: Int32List.fromList([4]),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          fullScreenIntent: true,
          color: const Color(0xFFFF5500),
          colorized: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          actions: actions,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: 'CRITICAL ALARM',
          ),
        );
        break;

      case ReminderAlertSeverity.short:
      default:
        androidDetails = AndroidNotificationDetails(
          shortChannelId,
          shortChannelName,
          channelDescription: shortChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          color: const Color(0xFFFF5500),
          category: AndroidNotificationCategory.reminder,
          actions: actions,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: 'ilmi Task',
          ),
        );
        break;
    }

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  /// Shows an immediate test notification for a specified alert severity
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    required String alertSeverity,
  }) async {
    final details = _buildNotificationDetails(
      alertSeverity: alertSeverity,
      title: title,
      body: body,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: 'immediate_test_$id',
    );
  }

  /// Triggers an immediate notification for location geofence arrival or departure
  Future<void> showGeofenceNotification({
    required Reminder reminder,
    required String triggerType,
  }) async {
    if (reminder.id == null) return;
    final details = _buildNotificationDetails(
      alertSeverity: reminder.alertSeverity,
      title: reminder.title,
      body: reminder.notes ?? '',
    );

    final actionText = triggerType == 'leave' ? 'Left area' : 'Arrived at area';
    final bodyText = (reminder.notes != null && reminder.notes!.isNotEmpty)
        ? '$actionText • ${reminder.notes}'
        : 'Location trigger ($actionText): ${reminder.title}';

    await _notificationsPlugin.show(
      id: reminder.id!,
      title: '📍 ${reminder.title}',
      body: bodyText,
      notificationDetails: details,
      payload: 'reminder_${reminder.id}',
    );
  }

  /// Schedules main notification and early pre-alert notification for a reminder
  Future<void> scheduleReminderNotification(Reminder reminder) async {
    if (reminder.id == null) return;

    // If due_datetime is null or reminder is completed, cancel existing alarms and exit
    if (reminder.dueDatetime == null || reminder.isCompleted) {
      await cancelReminderNotification(reminder.id!);
      return;
    }

    final reminderId = reminder.id!;
    final earlyAlertId = reminderId + earlyAlertIdOffset;
    final due = reminder.dueDatetime!;

    // 1. Calculate main notification scheduled time in local tz
    tz.TZDateTime scheduledDate = tz.TZDateTime.from(due, tz.local);
    final now = tz.TZDateTime.now(tz.local);

    DateTimeComponents? matchComponents;
    switch (reminder.repeatRule) {
      case ReminderRepeatRule.daily:
        matchComponents = DateTimeComponents.time;
        while (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
        break;
      case ReminderRepeatRule.weekdays:
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
        while (scheduledDate.isBefore(now) ||
            scheduledDate.weekday == DateTime.saturday ||
            scheduledDate.weekday == DateTime.sunday) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
        break;
      case ReminderRepeatRule.weekly:
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
        while (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 7));
        }
        break;
      case ReminderRepeatRule.monthly:
        matchComponents = DateTimeComponents.dayOfMonthAndTime;
        while (scheduledDate.isBefore(now)) {
          scheduledDate = tz.TZDateTime(
            tz.local,
            scheduledDate.month == 12
                ? scheduledDate.year + 1
                : scheduledDate.year,
            scheduledDate.month == 12 ? 1 : scheduledDate.month + 1,
            scheduledDate.day,
            scheduledDate.hour,
            scheduledDate.minute,
            scheduledDate.second,
          );
        }
        break;
      case ReminderRepeatRule.none:
      default:
        matchComponents = null;
        break;
    }

    // If non-repeating and date is already in the past, cancel and return
    if (matchComponents == null && scheduledDate.isBefore(now)) {
      await cancelReminderNotification(reminderId);
      return;
    }

    final mainDetails = _buildNotificationDetails(
      alertSeverity: reminder.alertSeverity,
      title: reminder.title,
      body: reminder.notes ?? 'Reminder due now',
    );

    // Schedule main notification
    await _notificationsPlugin.zonedSchedule(
      id: reminderId,
      title: reminder.title,
      body: reminder.notes ?? 'Reminder due now',
      scheduledDate: scheduledDate,
      notificationDetails: mainDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: matchComponents,
      payload: 'reminder_$reminderId',
    );

    // 2. Early Alert Pre-Notification Logic
    if (reminder.earlyAlertMinutes > 0) {
      final earlyAlertTime = due.subtract(
        Duration(minutes: reminder.earlyAlertMinutes),
      );
      var earlyScheduledDate = tz.TZDateTime.from(earlyAlertTime, tz.local);

      if (matchComponents != null) {
        while (earlyScheduledDate.isBefore(now)) {
          if (reminder.repeatRule == ReminderRepeatRule.daily) {
            earlyScheduledDate =
                earlyScheduledDate.add(const Duration(days: 1));
          } else if (reminder.repeatRule == ReminderRepeatRule.weekly) {
            earlyScheduledDate =
                earlyScheduledDate.add(const Duration(days: 7));
          } else {
            break;
          }
        }
      }

      if (earlyScheduledDate.isAfter(now)) {
        final earlyDetails = _buildNotificationDetails(
          alertSeverity: ReminderAlertSeverity.short,
          title: 'Upcoming: ${reminder.title}',
          body: 'Due in ${reminder.earlyAlertMinutes} minutes',
        );

        await _notificationsPlugin.zonedSchedule(
          id: earlyAlertId,
          title: 'Upcoming: ${reminder.title}',
          body: 'Due in ${reminder.earlyAlertMinutes} minutes',
          scheduledDate: earlyScheduledDate,
          notificationDetails: earlyDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: matchComponents,
          payload: 'early_reminder_$reminderId',
        );
      } else {
        await _notificationsPlugin.cancel(id: earlyAlertId);
      }
    } else {
      // Cancel any pre-existing early alert
      await _notificationsPlugin.cancel(id: earlyAlertId);
    }
  }

  /// Cancels both main and early alert notifications for a reminder ID
  Future<void> cancelReminderNotification(int reminderId) async {
    await _notificationsPlugin.cancel(id: reminderId);
    await _notificationsPlugin.cancel(id: reminderId + earlyAlertIdOffset);
  }

  /// Cancels all notifications managed by the app
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}

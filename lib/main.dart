import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'data/database_helper.dart';
import 'data/models/reminder_model.dart';
import 'data/repositories/reminder_repository.dart';
import 'l10n/app_strings.dart';
import 'screens/alarm_ringing_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reminder_editor_sheet.dart';
import 'services/app_events.dart';
import 'services/notification_service.dart';
import 'theme/app_colors.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (_) {}
  }
  // Background isolate: plugin is already initialized by the main isolate,
  // only timezone data must be prepared before any zonedSchedule call.
  NotificationService.instance.ensureTimeZoneReady();
  final actionId = response.actionId;
  final payload = response.payload;
  if (actionId != null && actionId.isNotEmpty && payload != null) {
    try {
      await handleNotificationAction(actionId, payload);
    } catch (e, stack) {
      debugPrint('Background notification action failed: $e\n$stack');
    }
  }
}

/// Extracts the reminder ID from any notification payload variant.
/// Order matters: 'early_reminder_' must be checked before 'reminder_'.
int? parseReminderIdFromPayload(String payload) {
  const prefixes = ['early_reminder_', 'reminder_'];
  for (final p in prefixes) {
    if (payload.startsWith(p)) {
      return int.tryParse(payload.substring(p.length));
    }
  }
  return null;
}

final Set<String> _inFlightActions = <String>{};

Future<void> handleNotificationAction(
  String actionId,
  String payload, {
  ReminderRepository? repository,
  NotificationService? notificationService,
}) async {
  final reminderId = parseReminderIdFromPayload(payload);
  if (reminderId == null) return;

  // Idempotency guard: ignore rapid duplicate taps for the same action.
  final key = '$actionId:$reminderId';
  if (!_inFlightActions.add(key)) return;

  try {
    final service = notificationService ?? NotificationService.instance;
    final repo = repository ?? ReminderRepository(notificationService: service);

    if (actionId == NotificationService.actionComplete) {
      // Mark done in SQLite; repository cancels main/early/snooze alarms.
      await repo.toggleReminderCompletion(reminderId, true);
      await service.cancelReminderNotification(reminderId);
    } else if (actionId == NotificationService.actionSnooze) {
      final reminder = await repo.getReminderById(reminderId);
      if (reminder == null) return;

      if (reminder.repeatRule == ReminderRepeatRule.none) {
        // One-off reminder: move due time to now + 10m. updateReminder
        // cancels stale alarms and schedules the new exact alarm atomically.
        final updated = reminder.copyWith(
          dueDatetime: DateTime.now().add(NotificationService.snoozeDuration),
          isCompleted: false,
        );
        await repo.updateReminder(updated, syncSubtasks: false);
      } else {
        // Repeating reminder: keep the recurrence intact and add a one-off
        // snooze alert under its own notification ID.
        await service.scheduleSnoozeNotification(reminder);
      }
    }

    AppEvents.notifyRemindersChanged();
  } finally {
    _inFlightActions.remove(key);
  }
}

Future<void> handleNotificationPayload(
  String payload, {
  ReminderRepository? repository,
}) async {
  final repo = repository ?? ReminderRepository();

  if (payload.startsWith('reminder_')) {
    final idStr = payload.replaceFirst('reminder_', '');
    final reminderId = int.tryParse(idStr);
    if (reminderId == null) return;

    final reminder = await repo.getReminderById(reminderId);
    if (reminder == null) return;

    // Requirement: ONLY route to AlarmRingingScreen if alert_severity == 'strong_fullscreen' AND main trigger
    if (reminder.alertSeverity == ReminderAlertSeverity.strongFullscreen) {
      appNavigatorKey.currentState?.push(
        AlarmRingingScreen.route(reminder: reminder, repository: repo),
      );
    } else {
      // Light or Short severity: open editor/details sheet on HomeScreen
      final context = appNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        ReminderEditorSheet.show(context, reminder: reminder, repository: repo);
      }
    }
  } else if (payload.startsWith('early_reminder_')) {
    // Requirement: Early Alert tapped -> do NOT open AlarmRingingScreen!
    // Open ReminderEditorSheet so user can review details without prematurely completing task
    final idStr = payload.replaceFirst('early_reminder_', '');
    final reminderId = int.tryParse(idStr);
    if (reminderId == null) return;

    final reminder = await repo.getReminderById(reminderId);
    if (reminder == null) return;

    final context = appNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      ReminderEditorSheet.show(context, reminder: reminder, repository: repo);
    }
  } else if (payload.startsWith('immediate_test_')) {
    appNavigatorKey.currentState?.push(
      AlarmRingingScreen.route(
        reminder: Reminder(
          title: 'Critical Alarm Test',
          notes: 'Test full-screen alarm notification response.',
          alertSeverity: ReminderAlertSeverity.strongFullscreen,
          dueDatetime: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        repository: repo,
      ),
    );
  }
}

void main() async {
  // 1. Ensure Flutter bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Custom global error widget to avoid blank white screens on unhandled widget build errors
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: AppColors.canvas,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.accent, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Temporary Interface Error',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // 2. Desktop FFI initialization
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (e) {
      debugPrint('sqfliteFfiInit error: $e');
    }
  }

  // 3. Pre-initialize and warm up SQLite database safely
  try {
    await DatabaseHelper.instance.database;
  } catch (e, stack) {
    debugPrint('Database warm-up warning on cold start: $e\n$stack');
  }

  // 4. Initialize notification channels and timezone with safe catch
  try {
    await NotificationService.instance.initialize(
      onNotificationResponse: (response) {
        final payload = response.payload;
        final actionId = response.actionId;
        if (actionId != null && actionId.isNotEmpty && payload != null) {
          handleNotificationAction(actionId, payload);
        } else if (payload != null) {
          handleNotificationPayload(payload);
        }
      },
      onBackgroundNotificationResponse: notificationTapBackground,
    );
  } catch (e, stack) {
    debugPrint('Notification service initialization error on cold start: $e\n$stack');
  }

  // 5. Check if app was launched directly from an active notification
  try {
    final launchDetails = await NotificationService.instance.plugin
        .getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      final payload = launchDetails.notificationResponse?.payload;
      if (payload != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleNotificationPayload(payload);
        });
      }
    }
  } catch (e) {
    debugPrint('Launch details check warning: $e');
  }

  runApp(const SamsungReminderApp());
}

class SamsungReminderApp extends StatelessWidget {
  final ReminderRepository? repository;
  final Locale? initialLocale;

  const SamsungReminderApp({super.key, this.repository, this.initialLocale});

  @override
  Widget build(BuildContext context) {
    final isRunningTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    return AnimatedBuilder(
      animation: LocaleController.instance,
      builder: (context, _) {
        final currentLocale = initialLocale ??
            (isRunningTest
                ? const Locale('en')
                : LocaleController.instance.locale);

        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'ilmi Task',
          debugShowCheckedModeBanner: false,
          locale: currentLocale,
          supportedLocales: const [Locale('tr'), Locale('en')],
          themeMode: ThemeMode.dark, // Default to bespoke matte obsidian dark mode
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.canvas,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.card,
          onSurface: AppColors.textPrimary,
          surfaceContainerHighest: AppColors.surfaceInteractive,
          outline: AppColors.cardBorder,
          outlineVariant: AppColors.cardBorder,
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
        cardTheme: const CardThemeData(
          color: AppColors.card,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        dividerColor: AppColors.cardBorder,
        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.card,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: AppColors.cardBorder, width: 1),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.card,
          contentTextStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'monospace',
            fontSize: 12.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
        ),
        datePickerTheme: const DatePickerThemeData(
          backgroundColor: AppColors.card,
          surfaceTintColor: Colors.transparent,
          headerBackgroundColor: AppColors.card,
          headerForegroundColor: AppColors.accent,
        ),
        timePickerTheme: const TimePickerThemeData(
          backgroundColor: AppColors.card,
          hourMinuteColor: AppColors.surfaceInteractive,
          hourMinuteTextColor: AppColors.textPrimary,
          dialHandColor: AppColors.accent,
          dialBackgroundColor: AppColors.surfaceInteractive,
          dialTextColor: AppColors.textPrimary,
          entryModeIconColor: AppColors.accent,
        ),
      ),
      home: HomeScreen(repository: repository),
        );
      },
    );
  }
}

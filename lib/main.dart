import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'data/models/reminder_model.dart';
import 'data/repositories/reminder_repository.dart';
import 'screens/alarm_ringing_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reminder_editor_sheet.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

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
  WidgetsFlutterBinding.ensureInitialized();

  // If running on desktop platforms (Windows/Linux/macOS vm), initialize ffi factory
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize notification channels and timezone with refined response routing
  await NotificationService.instance.initialize(
    onNotificationResponse: (response) {
      final payload = response.payload;
      if (payload != null) {
        handleNotificationPayload(payload);
      }
    },
  );

  // Check if app was launched directly from an active notification
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
  } catch (_) {
    // Ignored in non-supported testing environments
  }

  runApp(const SamsungReminderApp());
}

class SamsungReminderApp extends StatelessWidget {
  final ReminderRepository? repository;

  const SamsungReminderApp({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    const primarySeed = Color(0xFF1976D2);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Samsung Reminder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primarySeed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primarySeed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: HomeScreen(repository: repository),
    );
  }
}

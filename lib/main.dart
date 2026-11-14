import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'data/database_helper.dart';
import 'data/models/reminder_model.dart';
import 'data/repositories/reminder_repository.dart';
import 'screens/alarm_ringing_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reminder_editor_sheet.dart';
import 'services/notification_service.dart';
import 'theme/app_colors.dart';

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
        if (payload != null) {
          handleNotificationPayload(payload);
        }
      },
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

  const SamsungReminderApp({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Samsung Reminder',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Default to bespoke matte obsidian dark mode
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.canvas,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.card,
          onSurface: AppColors.textPrimary,
          outline: AppColors.cardBorder,
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
        cardTheme: const CardThemeData(
          color: AppColors.card,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        dividerColor: AppColors.cardBorder,
      ),
      home: HomeScreen(repository: repository),
    );
  }
}

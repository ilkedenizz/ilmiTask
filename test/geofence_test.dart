import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/data/models/reminder_model.dart';
import 'package:reminder_app/services/geofence_service.dart';
import 'package:reminder_app/widgets/reminder_card.dart';
import 'package:reminder_app/widgets/system_shield_dialog.dart';

void main() {
  group('GeofenceMonitorService Deterministic Logic Tests', () {
    late GeofenceMonitorService geofenceService;

    setUp(() {
      geofenceService = GeofenceMonitorService();
      geofenceService.resetState();
    });

    test('Arrive Transition: Triggers when moving from outside to inside perimeter',
        () async {
      // Ankara Center: 39.9334, 32.8597, radius: 250m
      const targetLat = 39.9334;
      const targetLng = 32.8597;

      final reminder = Reminder(
        id: 101,
        title: 'Buy Groceries',
        locationLat: targetLat,
        locationLng: targetLng,
        locationRadius: 250.0,
        locationTriggerType: LocationTriggerType.arrive,
        alertSeverity: ReminderAlertSeverity.short,
        createdAt: DateTime.now(),
      );

      // Explicitly initialize state to outside
      geofenceService.setReminderState(101, wasInside: false);

      // 1. Current position is 5 km away (outside)
      final outsideLat = 39.9800;
      final outsideLng = 32.8597;
      final triggered1 = await geofenceService.evaluatePosition(
        outsideLat,
        outsideLng,
        [reminder],
        triggerNotification: false,
      );
      expect(triggered1, isEmpty);
      expect(geofenceService.wasInsideState[101], isFalse);

      // 2. User moves inside the 250m radius
      // ~50m from center
      const insideLat = 39.9336;
      const insideLng = 32.8599;
      final triggered2 = await geofenceService.evaluatePosition(
        insideLat,
        insideLng,
        [reminder],
        triggerNotification: false,
      );
      expect(triggered2, contains(101));
      expect(geofenceService.wasInsideState[101], isTrue);

      // 3. User remains inside -> should NOT trigger repeatedly
      final triggered3 = await geofenceService.evaluatePosition(
        insideLat,
        insideLng,
        [reminder],
        triggerNotification: false,
      );
      expect(triggered3, isEmpty);
      expect(geofenceService.wasInsideState[101], isTrue);
    });

    test('Leave Transition: Triggers when moving from inside to outside perimeter',
        () async {
      const targetLat = 39.9334;
      const targetLng = 32.8597;

      final reminder = Reminder(
        id: 202,
        title: 'Turn off Office Lights',
        locationLat: targetLat,
        locationLng: targetLng,
        locationRadius: 250.0,
        locationTriggerType: LocationTriggerType.leave,
        alertSeverity: ReminderAlertSeverity.short,
        createdAt: DateTime.now(),
      );

      // Start inside
      geofenceService.setReminderState(202, wasInside: true);

      // 1. Still inside: ~30m away
      const insideLat = 39.9335;
      const insideLng = 32.8598;
      final triggered1 = await geofenceService.evaluatePosition(
        insideLat,
        insideLng,
        [reminder],
        triggerNotification: false,
      );
      expect(triggered1, isEmpty);
      expect(geofenceService.wasInsideState[202], isTrue);

      // 2. Moves outside (2 km away)
      const outsideLat = 39.9500;
      const outsideLng = 32.8597;
      final triggered2 = await geofenceService.evaluatePosition(
        outsideLat,
        outsideLng,
        [reminder],
        triggerNotification: false,
      );
      expect(triggered2, contains(202));
      expect(geofenceService.wasInsideState[202], isFalse);

      // 3. Remains outside -> should NOT trigger again
      final triggered3 = await geofenceService.evaluatePosition(
        outsideLat,
        outsideLng,
        [reminder],
        triggerNotification: false,
      );
      expect(triggered3, isEmpty);
      expect(geofenceService.wasInsideState[202], isFalse);
    });

    test('Ignores completed reminders and reminders without location coordinates',
        () async {
      final completedReminder = Reminder(
        id: 301,
        title: 'Completed Task',
        locationLat: 39.9334,
        locationLng: 32.8597,
        locationRadius: 250.0,
        isCompleted: true,
        createdAt: DateTime.now(),
      );

      final noLocationReminder = Reminder(
        id: 302,
        title: 'No Location Task',
        locationLat: null,
        locationLng: null,
        createdAt: DateTime.now(),
      );

      geofenceService.setReminderState(301, wasInside: false);

      final triggered = await geofenceService.evaluatePosition(
        39.9334,
        32.8597,
        [completedReminder, noLocationReminder],
        triggerNotification: false,
      );

      expect(triggered, isEmpty);
    });
  });

  group('ReminderCard Phase 5 Widget Tests', () {
    testWidgets('Renders Location Badge with trigger type and radius',
        (tester) async {
      final reminder = Reminder(
        id: 401,
        title: 'Drop off Package',
        locationLat: 39.9334,
        locationLng: 32.8597,
        locationRadius: 500.0,
        locationTriggerType: LocationTriggerType.leave,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReminderCard(
              reminder: reminder,
              onTap: () {},
              onToggleComplete: (_) {},
              onTogglePin: () {},
              onDelete: () {},
              onToggleSubtask: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Drop off Package'), findsOneWidget);
      // Location badge text
      expect(find.textContaining('📍 LEAVE • 500m'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Extracts smart URL and renders [ ↗ OPEN LINK ] chip',
        (tester) async {
      final reminder = Reminder(
        id: 402,
        title: 'Review PR',
        notes: 'Check deployment doc at https://github.com/flutter/flutter for details',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReminderCard(
              reminder: reminder,
              onTap: () {},
              onToggleComplete: (_) {},
              onTogglePin: () {},
              onDelete: () {},
              onToggleSubtask: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Review PR'), findsOneWidget);
      expect(find.text('[ ↗ OPEN LINK ]'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
      expect(
        find.text('https://github.com/flutter/flutter'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('SystemShieldDialog includes Location Triggers diagnostic tile',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SystemShieldDialog(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('System Reliability Shield'), findsOneWidget);
      expect(find.text('Location Triggers (Geofencing)'), findsOneWidget);
      expect(
        find.text('Required for arrival and departure alerts'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
    });
  });
}

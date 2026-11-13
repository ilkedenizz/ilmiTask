import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../data/models/reminder_model.dart';
import '../data/repositories/reminder_repository.dart';
import 'notification_service.dart';

/// Service responsible for monitoring user location and evaluating geofence
/// transitions (arrive / leave) for active reminders.
class GeofenceMonitorService {
  static final GeofenceMonitorService _instance =
      GeofenceMonitorService._internal();

  factory GeofenceMonitorService() => _instance;

  GeofenceMonitorService._internal();

  final NotificationService _notificationService = NotificationService();
  StreamSubscription<Position>? _positionSubscription;
  ReminderRepository? _repository;

  /// Tracks whether the user was previously inside (true) or outside (false)
  /// the geofence perimeter for each reminder ID.
  final Map<int, bool> _wasInside = {};

  /// Read-only snapshot of current tracked geofence states.
  Map<int, bool> get wasInsideState => Map.unmodifiable(_wasInside);

  bool get isMonitoring => _positionSubscription != null;

  /// Sets an explicit previous state for a reminder ID (useful for deterministic tests).
  void setReminderState(int reminderId, {required bool wasInside}) {
    _wasInside[reminderId] = wasInside;
  }

  /// Clears tracked location states.
  void resetState() {
    _wasInside.clear();
  }

  /// Evaluates current position against a list of active reminders.
  /// Detects state transitions:
  /// - 'arrive': transition from outside (false) to inside (true)
  /// - 'leave': transition from inside (true) to outside (false)
  ///
  /// Returns a list of reminder IDs that triggered during this evaluation.
  Future<List<int>> evaluatePosition(
    double currentLat,
    double currentLng,
    List<Reminder> reminders, {
    bool triggerNotification = true,
  }) async {
    final List<int> triggeredIds = [];

    for (final reminder in reminders) {
      if (reminder.id == null || reminder.isCompleted) continue;
      if (reminder.locationLat == null || reminder.locationLng == null) continue;

      final reminderId = reminder.id!;
      final targetLat = reminder.locationLat!;
      final targetLng = reminder.locationLng!;
      final radius = reminder.locationRadius ?? 250.0;
      final triggerType =
          reminder.locationTriggerType ?? LocationTriggerType.arrive;

      final distance = Geolocator.distanceBetween(
        currentLat,
        currentLng,
        targetLat,
        targetLng,
      );

      final isInside = distance <= radius;
      final hasPriorState = _wasInside.containsKey(reminderId);
      final wasInside = _wasInside[reminderId] ?? !isInside;

      bool shouldTrigger = false;

      if (triggerType == LocationTriggerType.arrive) {
        if (hasPriorState) {
          if (!wasInside && isInside) {
            shouldTrigger = true;
          }
        } else {
          // If first reading and already inside the target area
          if (isInside) {
            shouldTrigger = true;
          }
        }
      } else if (triggerType == LocationTriggerType.leave) {
        if (hasPriorState) {
          if (wasInside && !isInside) {
            shouldTrigger = true;
          }
        }
      }

      // Always update tracked state to the latest
      _wasInside[reminderId] = isInside;

      if (shouldTrigger) {
        triggeredIds.add(reminderId);
        if (triggerNotification) {
          try {
            await _notificationService.showGeofenceNotification(
              reminder: reminder,
              triggerType: triggerType,
            );
          } catch (e) {
            debugPrint('Failed to trigger geofence notification: $e');
          }
        }
      }
    }

    return triggeredIds;
  }

  /// Starts monitoring user position via Geolocator.
  Future<void> startMonitoring({ReminderRepository? repository}) async {
    _repository = repository ?? ReminderRepository();

    if (_positionSubscription != null) {
      return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('GeofenceMonitorService: Location services are disabled.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('GeofenceMonitorService: Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
            'GeofenceMonitorService: Location permissions are permanently denied.');
        return;
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25, // updates every 25 meters
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) async {
          if (_repository == null) return;
          try {
            final activeReminders = await _repository!.getAllReminders();
            final locationReminders = activeReminders
                .where((r) =>
                    !r.isCompleted &&
                    r.locationLat != null &&
                    r.locationLng != null)
                .toList();

            await evaluatePosition(
              position.latitude,
              position.longitude,
              locationReminders,
            );
          } catch (e) {
            debugPrint('GeofenceMonitorService onLocationChanged error: $e');
          }
        },
        onError: (e) {
          debugPrint('GeofenceMonitorService stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('GeofenceMonitorService startMonitoring error: $e');
    }
  }

  /// Stops monitoring user position.
  Future<void> stopMonitoring() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}

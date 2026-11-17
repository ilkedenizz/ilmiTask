import 'package:flutter/foundation.dart';

/// Lightweight in-process event bus for reminder data changes that happen
/// outside the HomeScreen (e.g. notification action buttons tapped while the
/// app is in the foreground). Listeners reload from SQLite when it ticks.
class AppEvents {
  AppEvents._();

  static final ValueNotifier<int> reminderDataRevision = ValueNotifier<int>(0);

  static void notifyRemindersChanged() {
    reminderDataRevision.value++;
  }
}

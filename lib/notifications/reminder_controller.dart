import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme_controller.dart';
import '../data/events_providers.dart';
import '../domain/event.dart';
import 'reminder_service.dart';

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(),
);

/// The set of event ids the user wants to be reminded about.
final remindersProvider =
    NotifierProvider<RemindersController, Set<String>>(RemindersController.new);

/// The outcome of asking for a reminder, so the UI can say what happened.
enum ReminderResult {
  scheduled,
  removed,

  /// The reminder would have fired in the past — the event is too close.
  tooLate,

  /// The user declined the notification permission.
  denied,

  /// This platform cannot schedule local notifications.
  unsupported,
}

class RemindersController extends Notifier<Set<String>> {
  static const _key = 'event_reminders';

  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  bool isSet(Event event) => state.contains(event.id);

  /// Turns the reminder for [event] on or off.
  Future<ReminderResult> toggle(Event event) async {
    final service = ref.read(reminderServiceProvider);

    if (isSet(event)) {
      await service.cancel(event);
      await _persist(state.difference({event.id}));
      return ReminderResult.removed;
    }

    if (!ReminderService.isSupported) return ReminderResult.unsupported;

    final granted = await service.requestPermission();
    if (!granted) return ReminderResult.denied;

    final leadTime = ref.read(appConfigProvider).reminderLeadTime;
    final scheduled = await service.schedule(event, leadTime: leadTime);
    if (!scheduled) return ReminderResult.tooLate;

    await _persist({...state, event.id});
    return ReminderResult.scheduled;
  }

  /// Re-schedules everything the user asked for and forgets the rest.
  ///
  /// Reminders live in the OS, and the OS drops them on reboot, on an app
  /// reinstall, and when an event's date moves in Notion. Reconciling against
  /// the current agenda on launch is what keeps the bell icons honest.
  Future<void> reconcile() async {
    if (state.isEmpty || !ReminderService.isSupported) return;

    final agenda = ref.read(agendaProvider).valueOrNull;
    if (agenda == null) return;

    final service = ref.read(reminderServiceProvider);
    final leadTime = ref.read(appConfigProvider).reminderLeadTime;
    final byId = {for (final event in agenda) event.id: event};

    final stillValid = <String>{};
    for (final id in state) {
      final event = byId[id];
      // Dropped from the agenda, or now too close to warn about.
      if (event == null) continue;
      if (await service.schedule(event, leadTime: leadTime)) {
        stillValid.add(id);
      }
    }

    if (stillValid.length != state.length) await _persist(stillValid);
  }

  Future<void> _persist(Set<String> ids) async {
    state = ids;
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_key, ids.toList(growable: false));
  }
}

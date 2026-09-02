import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme_controller.dart';
import '../data/events_providers.dart';
import '../domain/calendar_date.dart';
import '../domain/event.dart';
import '../domain/event_filters.dart';
import 'reminder_plan.dart';
import 'reminder_service.dart';
import 'reminder_tier.dart';

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(),
);

/// The events the user said they are going to.
///
/// Marking an event is deliberately not behind a login: it is the action people
/// take most often, and a sign-in wall in front of "remind me" is how an app
/// like this loses the people it is for. An account, when there is one, only
/// makes these durable across devices.
final subscriptionsProvider =
    NotifierProvider<SubscriptionsController, Set<String>>(
  SubscriptionsController.new,
);

/// What to tell the user after they tap.
enum SubscriptionResult {
  /// Marked, and every reminder tier is scheduled.
  subscribed,

  /// Marked, but the event is close enough that some tiers already passed.
  subscribedPartially,

  /// Marked, but the event starts in under five minutes — nothing to schedule.
  subscribedTooLate,

  /// Marked, but this device already holds reminders for as many events as the
  /// OS allows, so the reminders start once a nearer event has passed.
  subscribedQueued,

  unsubscribed,

  /// The user declined the notification permission.
  denied,

  /// This platform cannot schedule local notifications.
  unsupported,
}

class SubscriptionsController extends Notifier<Set<String>> {
  /// Kept separate from the Expo-era key: that one held reminder ids under a
  /// different meaning, and mixing them would resurrect stale entries.
  static const _key = 'event_subscriptions';

  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  bool isSubscribed(Event event) => state.contains(event.id);

  /// How many events this device is holding reminders for.
  int get scheduledCount => state.length.clamp(0, ReminderService.eventBudget);

  /// Marks or unmarks [event].
  Future<SubscriptionResult> toggle(Event event) async {
    if (isSubscribed(event)) {
      await ref.read(reminderServiceProvider).cancelFor(event);
      await _persist(state.difference({event.id}));
      // Freeing a slot may let a queued event's reminders through.
      await reconcile();
      return SubscriptionResult.unsubscribed;
    }

    if (!ReminderService.isSupported) {
      // Still record the interest: it is what the organizer counts, and it
      // syncs to a phone that can notify.
      await _persist({...state, event.id});
      return SubscriptionResult.unsupported;
    }

    final service = ref.read(reminderServiceProvider);
    if (!await service.requestPermission()) return SubscriptionResult.denied;

    await _persist({...state, event.id});

    // Reconciling rather than scheduling this one event directly, so the
    // budget is respected: on iOS the nearest events win the slots.
    final outcome = await reconcile();

    if (!outcome.contains(event.id)) return SubscriptionResult.subscribedQueued;

    final result = await service.scheduleFor(event);
    if (result.isEmpty) return SubscriptionResult.subscribedTooLate;
    if (result.skippedTooLate.isNotEmpty) {
      return SubscriptionResult.subscribedPartially;
    }
    return SubscriptionResult.subscribed;
  }

  /// Re-schedules everything the user marked, newest agenda first.
  ///
  /// Reminders live in the OS, and the OS forgets them on reboot and on
  /// reinstall. An event's date can also move in Notion, or the event can
  /// disappear. Reconciling on launch and after every agenda refresh is what
  /// keeps the scheduled reminders and the marks on screen honest.
  ///
  /// Returns the ids that actually hold reminders now — on iOS the budget can
  /// be smaller than the number of marked events.
  Future<Set<String>> reconcile() async {
    if (state.isEmpty || !ReminderService.isSupported) return const {};

    final agenda = ref.read(agendaProvider).valueOrNull;
    if (agenda == null) return const {};

    final service = ref.read(reminderServiceProvider);
    final byId = {for (final event in agenda) event.id: event};

    // Marked events that are still upcoming, soonest first.
    final live = state
        .map((id) => byId[id])
        .whereType<Event>()
        .toList()
        .upcomingFrom(today());

    // Drop marks for events that left the agenda or already happened.
    final liveIds = live.map((event) => event.id).toSet();
    if (liveIds.length != state.length) await _persist(liveIds);

    // Clearing first means a moved date cannot leave a stale alarm behind.
    await service.cancelAll();

    final plan = buildReminderPlan(
      live,
      eventBudget: ReminderService.eventBudget,
      now: DateTime.now(),
    );

    for (final entry in plan.entries) {
      await service.scheduleFor(entry.event);
    }
    return plan.entries.map((entry) => entry.event.id).toSet();
  }

  Future<void> _persist(Set<String> ids) async {
    state = ids;
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_key, ids.toList(growable: false));
  }
}

/// The message to show for a [SubscriptionResult].
String subscriptionMessage(SubscriptionResult result) => switch (result) {
      SubscriptionResult.subscribed =>
        'Pronto! Avisamos 1 hora, 30 e 5 minutos antes.',
      SubscriptionResult.subscribedPartially =>
        'Marcado. O evento está próximo, então alguns avisos já passaram.',
      SubscriptionResult.subscribedTooLate =>
        'Marcado, mas o evento começa agora — não dá tempo de avisar.',
      SubscriptionResult.subscribedQueued =>
        'Marcado. Os avisos entram quando um evento mais próximo passar.',
      SubscriptionResult.unsubscribed => 'Você não vai mais receber avisos.',
      SubscriptionResult.denied =>
        'Ative as notificações nos ajustes para receber os avisos.',
      SubscriptionResult.unsupported =>
        'Marcado. Os avisos chegam no app instalado no celular.',
    };

/// The tiers as a human sentence, for explaining the feature once.
String get reminderTiersDescription => ReminderTier.values
    .map((tier) => switch (tier) {
          ReminderTier.oneHour => '1 hora',
          ReminderTier.thirtyMinutes => '30 minutos',
          ReminderTier.fiveMinutes => '5 minutos',
        })
    .join(', ');

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme_controller.dart';
import '../data/events_providers.dart';
import '../domain/event.dart';
import 'reminder_plan.dart';
import 'reminder_scheduler.dart';
import 'reminder_service.dart';
import 'reminder_tier.dart';

final reminderServiceProvider = Provider<ReminderScheduler>(
  (ref) => ReminderService(),
);

/// Whether this platform can schedule local reminders at all.
///
/// A provider rather than a bare static so the widget tests can render the
/// reminder UI: the test VM is neither Android nor iOS, so the static answer
/// is always false and every control that depends on it would be untestable.
final remindersSupportedProvider = Provider<bool>(
  (ref) => ref.watch(reminderServiceProvider).isSupported,
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

  /// Presence recorded, but notifications are not allowed yet, so nothing is
  /// scheduled. The screen offers to enable them rather than prompting on the
  /// way out to WhatsApp.
  subscribedNeedsPermission,

  /// Already marked; nothing changed.
  alreadySubscribed,

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
  int get scheduledCount =>
      state.length.clamp(0, ref.read(reminderServiceProvider).eventBudget);

  /// Marks or unmarks [event].
  Future<SubscriptionResult> toggle(Event event) async {
    if (isSubscribed(event)) {
      await ref.read(reminderServiceProvider).cancelFor(event);
      await _persist(state.difference({event.id}));
      // Freeing a slot may let a queued event's reminders through.
      await reconcile();
      return SubscriptionResult.unsubscribed;
    }

    final service = ref.read(reminderServiceProvider);
    if (!service.isSupported) {
      // Still record the interest: it is what the organizer counts, and it
      // syncs to a phone that can notify.
      await _persist({...state, event.id});
      return SubscriptionResult.unsupported;
    }

    if (!await service.requestPermission()) return SubscriptionResult.denied;

    await _persist({...state, event.id});

    // Reconciling rather than scheduling this one event directly, so the
    // budget is respected: on iOS the nearest events win the slots.
    return _scheduleAndReport(event);
  }

  /// Records that the user is going, **without ever showing a dialog**.
  ///
  /// This is what the WhatsApp button calls. Signing up happens in the
  /// WhatsApp conversation, so tapping "Entrar em contato" is the moment the
  /// person commits — and it has to open WhatsApp immediately. A permission
  /// prompt in front of that would be the wrong thing at the wrong time, so
  /// when notifications are not allowed yet the presence is still recorded and
  /// the screen asks afterwards, with the reason visible.
  Future<SubscriptionResult> markGoing(Event event) async {
    if (isSubscribed(event)) return SubscriptionResult.alreadySubscribed;

    await _persist({...state, event.id});

    final service = ref.read(reminderServiceProvider);
    if (!service.isSupported) return SubscriptionResult.unsupported;

    if (!await service.areNotificationsEnabled()) {
      return SubscriptionResult.subscribedNeedsPermission;
    }

    return _scheduleAndReport(event);
  }

  /// Turns notifications on for someone who is already marked, and schedules
  /// everything that was waiting on the permission.
  Future<bool> enableReminders() async {
    final service = ref.read(reminderServiceProvider);
    if (!service.isSupported) return false;

    final granted = await service.requestPermission();
    if (granted) await reconcile();
    return granted;
  }

  /// Schedules [event] within the budget and says what came of it.
  Future<SubscriptionResult> _scheduleAndReport(Event event) async {
    final holding = await reconcile();
    if (!holding.contains(event.id)) return SubscriptionResult.subscribedQueued;

    final result = await ref.read(reminderServiceProvider).scheduleFor(event);
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
    final service = ref.read(reminderServiceProvider);
    if (state.isEmpty || !service.isSupported) return const {};

    final agenda = ref.read(agendaProvider).valueOrNull;
    if (agenda == null) return const {};
    final live = liveSubscriptions(state, agenda, now: DateTime.now());

    // Drop marks for events that left the agenda or already happened.
    final liveIds = live.map((event) => event.id).toSet();
    if (liveIds.length != state.length) await _persist(liveIds);

    // Clearing first means a moved date cannot leave a stale alarm behind.
    await service.cancelAll();

    final plan = buildReminderPlan(
      live,
      eventBudget: service.eventBudget,
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
      SubscriptionResult.subscribedNeedsPermission =>
        'Presença anotada. Ative as notificações para receber os avisos.',
      SubscriptionResult.alreadySubscribed =>
        'Você já está marcado neste evento.',
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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme_controller.dart';
import 'announcement_presenter.dart';
import 'interests_controller.dart';
import 'push_announcement.dart';
import 'push_gateway.dart';
import 'push_service.dart';

final pushGatewayProvider = Provider<PushGateway>((ref) => PushService());

final announcementPresenterProvider = Provider<AnnouncementPresenter>(
  (ref) => LocalAnnouncementPresenter(),
);

/// Whether this build can receive push at all. Mirrors
/// [remindersSupportedProvider] so the tests can render push-dependent UI.
final pushSupportedProvider = Provider<bool>(
  (ref) => ref.watch(pushGatewayProvider).isSupported,
);

/// An announcement the user tapped that has not been acted on yet.
///
/// Held rather than navigated from directly, because a tap can arrive before
/// there is anything to navigate to: launching from a cold start runs this
/// while the agenda is still being fetched, and the event the push names is
/// not in memory yet. Whoever can open it clears this once it has.
final pendingAnnouncementProvider = StateProvider<PushAnnouncement?>(
  (ref) => null,
);

/// Keeps this device's FCM topic subscriptions matching the chosen games.
///
/// The state is **what FCM has confirmed**, which is not the same as what the
/// user picked. Subscribing is a network call: it fails offline, and on iOS it
/// fails until APNs has handed over a token. Storing the confirmed set means a
/// failure costs one retry next launch instead of leaving the device quietly
/// subscribed to the wrong games forever — which is the failure mode that ends
/// with someone getting Magic announcements they turned off months ago.
final pushTopicsProvider =
    NotifierProvider<PushTopicsController, Set<String>>(
  PushTopicsController.new,
);

class PushTopicsController extends Notifier<Set<String>> {
  static const _key = 'push_synced_topics';

  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  /// Brings the subscriptions in line with the current interests.
  ///
  /// Sends only the difference, so the usual launch — nothing changed — costs
  /// no network at all. Returns the set actually held afterwards.
  Future<Set<String>> reconcile() async {
    final gateway = ref.read(pushGatewayProvider);
    if (!gateway.isSupported) return const {};

    final desired = ref.read(interestsProvider.notifier).topics;
    final confirmed = {...state};

    for (final topic in desired.difference(state)) {
      try {
        await gateway.subscribeToTopic(topic);
        confirmed.add(topic);
      } catch (error) {
        debugPrint('Tópico $topic não assinado, tenta de novo depois: $error');
      }
    }

    for (final topic in state.difference(desired)) {
      try {
        await gateway.unsubscribeFromTopic(topic);
        confirmed.remove(topic);
      } catch (error) {
        debugPrint('Tópico $topic não cancelado, tenta de novo depois: $error');
      }
    }

    if (!setEquals(confirmed, state)) await _persist(confirmed);
    return confirmed;
  }

  /// Drops every subscription. For a "pare de me avisar" switch.
  Future<void> unsubscribeAll() async {
    final gateway = ref.read(pushGatewayProvider);
    if (!gateway.isSupported) return;

    final confirmed = {...state};
    for (final topic in state) {
      try {
        await gateway.unsubscribeFromTopic(topic);
        confirmed.remove(topic);
      } catch (error) {
        debugPrint('Tópico $topic não cancelado: $error');
      }
    }
    await _persist(confirmed);
  }

  Future<void> _persist(Set<String> topics) async {
    state = topics;
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_key, topics.toList(growable: false));
  }
}

/// Wires the gateway's three delivery paths into the app.
///
/// Foreground messages get presented, taps get parked in
/// [pendingAnnouncementProvider], and a cold launch from a tap is read once.
/// Kept out of the widget tree so a rebuild cannot double-subscribe the
/// streams, and so the tests can drive it with a fake gateway.
class PushRouter {
  PushRouter(this._ref);

  final Ref _ref;
  final _subscriptions = <StreamSubscription<PushAnnouncement>>[];
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    final gateway = _ref.read(pushGatewayProvider);
    if (!gateway.isSupported) return;
    _started = true;

    await gateway.initialize();

    _subscriptions.add(gateway.onMessage.listen((announcement) {
      _ref.read(announcementPresenterProvider).present(announcement);
    }));

    _subscriptions.add(gateway.onOpened.listen(_park));

    _park(await gateway.initialMessage());
  }

  /// Only announcements that name an event are worth parking — there is
  /// nowhere to take someone for the rest, and leaving one parked would make
  /// the next agenda load try to open nothing.
  void _park(PushAnnouncement? announcement) {
    if (announcement == null || !announcement.opensEvent) return;
    _ref.read(pendingAnnouncementProvider.notifier).state = announcement;
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}

final pushRouterProvider = Provider<PushRouter>((ref) {
  final router = PushRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});

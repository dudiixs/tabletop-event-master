import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletop_events/core/theme/theme_controller.dart';
import 'package:tabletop_events/notifications/push_announcement.dart';
import 'package:tabletop_events/notifications/push_controller.dart';

import 'fake_push.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decoding a push', () {
    test('reads the type and the event out of the data map', () {
      final announcement = PushAnnouncement.fromData(const {
        'type': 'new_event',
        'eventId': 'abc-123',
        'category': 'pokemon',
      }, title: 'Novo evento', body: 'Liga Pokémon, sábado às 14h');

      expect(announcement.kind, AnnouncementKind.newEvent);
      expect(announcement.eventId, 'abc-123');
      expect(announcement.category, 'pokemon');
      expect(announcement.title, 'Novo evento');
      expect(announcement.body, 'Liga Pokémon, sábado às 14h');
      expect(announcement.opensEvent, isTrue);
    });

    test('a type the app does not know is shown, not dispatched', () {
      final announcement = PushAnnouncement.fromData(
        const {'type': 'promocao_relampago', 'eventId': 'abc'},
        title: 'Oferta',
      );

      // The server cannot invent behaviour by inventing a type. It renders,
      // and tapping it still opens the event it names -- nothing more.
      expect(announcement.kind, AnnouncementKind.unknown);
      expect(announcement.title, 'Oferta');
    });

    test('data wins over the notification block', () {
      // Only `data` survives every delivery mode intact, so it is the source
      // of truth when the two disagree.
      final announcement = PushAnnouncement.fromData(
        const {'type': 'event_cancelled', 'title': 'Cancelado'},
        title: 'Titulo do bloco notification',
      );

      expect(announcement.kind, AnnouncementKind.cancelled);
      expect(announcement.title, 'Cancelado');
    });

    test('an empty payload is dull instead of an exception', () {
      // This runs on a delivery path with no UI on screen. A malformed push
      // has to degrade, never throw.
      final announcement = PushAnnouncement.fromData(const {});

      expect(announcement.kind, AnnouncementKind.unknown);
      expect(announcement.title, 'TableTop Events');
      expect(announcement.body, isEmpty);
      expect(announcement.eventId, isNull);
      expect(announcement.opensEvent, isFalse);
    });

    test('a blank eventId does not count as an event to open', () {
      final announcement = PushAnnouncement.fromData(const {'eventId': '   '});

      expect(announcement.eventId, isNull);
      expect(announcement.opensEvent, isFalse);
    });

    test('survives fields that are not strings', () {
      final announcement = PushAnnouncement.fromData(const {
        'type': 'new_event',
        'eventId': 42,
      });

      expect(announcement.eventId, '42');
    });
  });

  group('topic subscriptions', () {
    late FakePushGateway gateway;

    Future<ProviderContainer> build(
      List<String> interests, {
      List<String> alreadySynced = const [],
    }) async {
      SharedPreferences.setMockInitialValues({
        'event_interests': interests,
        'push_synced_topics': alreadySynced,
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        pushGatewayProvider.overrideWithValue(gateway),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      gateway = FakePushGateway();
      addTearDown(gateway.dispose);
    });

    test('subscribes to the games the user follows', () async {
      final container = await build(['pokemon', 'rpg']);

      final held =
          await container.read(pushTopicsProvider.notifier).reconcile();

      expect(held, {'game_pokemon', 'game_rpg'});
      expect(gateway.subscribed, {'game_pokemon', 'game_rpg'});
    });

    test('sends nothing when the subscriptions already match', () async {
      final container = await build(
        ['pokemon'],
        alreadySynced: ['game_pokemon'],
      );

      await container.read(pushTopicsProvider.notifier).reconcile();

      // The usual launch. Every device calling FCM twice per game on every
      // cold start is a bill and a rate limit for no change at all.
      expect(gateway.calls, isEmpty);
    });

    test('drops a game the user stopped following', () async {
      final container = await build(
        ['pokemon'],
        alreadySynced: ['game_pokemon', 'game_magic'],
      );

      final held =
          await container.read(pushTopicsProvider.notifier).reconcile();

      expect(gateway.calls, ['unsubscribe:game_magic']);
      expect(held, {'game_pokemon'});
    });

    test('a failed call is not recorded as done', () async {
      gateway.failing.add('game_rpg');
      final container = await build(['pokemon', 'rpg']);

      final held =
          await container.read(pushTopicsProvider.notifier).reconcile();

      // Offline. Pokemon went through, RPG did not -- and crucially the state
      // says so, instead of claiming a subscription the server never got.
      expect(held, {'game_pokemon'});
      expect(container.read(pushTopicsProvider), {'game_pokemon'});
    });

    test('the next launch retries what failed', () async {
      gateway.failing.add('game_rpg');
      final container = await build(['pokemon', 'rpg']);
      await container.read(pushTopicsProvider.notifier).reconcile();

      gateway.failing.clear();
      gateway.calls.clear();
      final held =
          await container.read(pushTopicsProvider.notifier).reconcile();

      expect(gateway.calls, ['subscribe:game_rpg']);
      expect(held, {'game_pokemon', 'game_rpg'});
    });

    test('what was confirmed survives a restart', () async {
      final container = await build(['pokemon']);
      await container.read(pushTopicsProvider.notifier).reconcile();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('push_synced_topics'), ['game_pokemon']);
    });

    test('does nothing at all where push cannot work', () async {
      gateway.isSupported = false;
      final container = await build(['pokemon']);

      final held =
          await container.read(pushTopicsProvider.notifier).reconcile();

      expect(held, isEmpty);
      expect(gateway.calls, isEmpty);
    });

    test('unsubscribeAll clears the device', () async {
      final container = await build(
        ['pokemon', 'rpg'],
        alreadySynced: ['game_pokemon', 'game_rpg'],
      );

      await container.read(pushTopicsProvider.notifier).unsubscribeAll();

      expect(container.read(pushTopicsProvider), isEmpty);
      expect(
        gateway.calls,
        containsAll(['unsubscribe:game_pokemon', 'unsubscribe:game_rpg']),
      );
    });
  });

  group('what happens when a push arrives', () {
    late FakePushGateway gateway;
    late FakePresenter presenter;

    Future<ProviderContainer> build() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        pushGatewayProvider.overrideWithValue(gateway),
        announcementPresenterProvider.overrideWithValue(presenter),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      gateway = FakePushGateway();
      presenter = FakePresenter();
      addTearDown(gateway.dispose);
    });

    test('a foreground message is drawn by the app', () async {
      final container = await build();
      await container.read(pushRouterProvider).start();

      gateway.deliver(const PushAnnouncement(
        kind: AnnouncementKind.newEvent,
        title: 'Novo evento',
        body: 'Liga de Magic na sexta',
        eventId: 'evt-1',
      ));
      await pumpEventQueue();

      // The OS does not draw a message that arrives with the app in front, so
      // without this the announcement would be silently dropped.
      expect(presenter.presented, hasLength(1));
      expect(presenter.presented.single.title, 'Novo evento');
    });

    test('a tap parks the event for whoever can open it', () async {
      final container = await build();
      await container.read(pushRouterProvider).start();

      gateway.tap(const PushAnnouncement(
        kind: AnnouncementKind.newEvent,
        title: 'Novo evento',
        body: '',
        eventId: 'evt-1',
      ));
      await pumpEventQueue();

      expect(container.read(pendingAnnouncementProvider)?.eventId, 'evt-1');
      // A tap is not a second notification.
      expect(presenter.presented, isEmpty);
    });

    test('a tap with no event to open parks nothing', () async {
      final container = await build();
      await container.read(pushRouterProvider).start();

      gateway.tap(const PushAnnouncement(
        kind: AnnouncementKind.unknown,
        title: 'A loja abre mais cedo no sábado',
        body: '',
      ));
      await pumpEventQueue();

      // Leaving this parked would make the next agenda load try to open an
      // event that was never named.
      expect(container.read(pendingAnnouncementProvider), isNull);
    });

    test('a cold launch from a tap is picked up', () async {
      gateway.launchMessage = const PushAnnouncement(
        kind: AnnouncementKind.newEvent,
        title: 'Novo evento',
        body: '',
        eventId: 'evt-cold',
      );
      final container = await build();

      await container.read(pushRouterProvider).start();

      expect(container.read(pendingAnnouncementProvider)?.eventId, 'evt-cold');
    });

    test('starting twice does not double-subscribe the streams', () async {
      final container = await build();
      final router = container.read(pushRouterProvider);
      await router.start();
      await router.start();

      gateway.deliver(const PushAnnouncement(
        kind: AnnouncementKind.newEvent,
        title: 'Novo evento',
        body: '',
      ));
      await pumpEventQueue();

      expect(presenter.presented, hasLength(1));
      expect(gateway.initializeCalls, 1);
    });

    test('does nothing at all where push cannot work', () async {
      gateway.isSupported = false;
      final container = await build();

      await container.read(pushRouterProvider).start();

      expect(gateway.initializeCalls, 0);
      expect(gateway.initialMessageReads, 0);
    });
  });
}

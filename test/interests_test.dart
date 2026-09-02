import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletop_events/core/theme/theme_controller.dart';
import 'package:tabletop_events/domain/event_category.dart';
import 'package:tabletop_events/notifications/interests_controller.dart';

Future<ProviderContainer> containerWith(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(preferences),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('defaults', () {
    test('a fresh install follows every game', () async {
      // Otherwise the first announcement — the reason someone installed the
      // app — would not reach them.
      final container = await containerWith({});

      expect(
        container.read(interestsProvider),
        InterestsController.selectable.toSet(),
      );
      expect(container.read(interestsProvider.notifier).hasChosen, isFalse);
    });

    test('the catch-all category is not offered', () async {
      // "Evento Especial" is where the detector lands when it recognises
      // nothing; nobody would choose to follow it.
      expect(
        InterestsController.selectable,
        isNot(contains(EventCategory.other)),
      );
      expect(
        InterestsController.selectable.length,
        EventCategory.values.length - 1,
      );
    });
  });

  group('choosing', () {
    test('toggling off leaves the rest followed', () async {
      final container = await containerWith({});
      final controller = container.read(interestsProvider.notifier);

      await controller.toggle(EventCategory.digimon);

      expect(container.read(interestsProvider), isNot(contains(EventCategory.digimon)));
      expect(container.read(interestsProvider), contains(EventCategory.pokemon));
      expect(controller.hasChosen, isTrue);
    });

    test('toggling twice returns to followed', () async {
      final container = await containerWith({});
      final controller = container.read(interestsProvider.notifier);

      await controller.toggle(EventCategory.magic);
      await controller.toggle(EventCategory.magic);

      expect(container.read(interestsProvider), contains(EventCategory.magic));
    });

    test('following none is recorded as a real choice', () async {
      // An empty selection has to be distinguishable from "never asked",
      // otherwise the next launch would re-follow everything.
      final container = await containerWith({});
      final controller = container.read(interestsProvider.notifier);

      await controller.followNone();

      expect(container.read(interestsProvider), isEmpty);
      expect(controller.hasChosen, isTrue);
    });

    test('a stored empty selection stays empty on relaunch', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final first = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ]);
      addTearDown(first.dispose);

      await first.read(interestsProvider.notifier).followNone();

      final relaunched = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ]);
      addTearDown(relaunched.dispose);

      expect(relaunched.read(interestsProvider), isEmpty);
    });

    test('followAll re-follows everything', () async {
      final container = await containerWith({});
      final controller = container.read(interestsProvider.notifier);

      await controller.followNone();
      await controller.followAll();

      expect(controller.followsEverything, isTrue);
    });

    test('restores a stored selection', () async {
      final container = await containerWith({
        'event_interests': ['pokemon', 'magic'],
        'event_interests_answered': true,
      });

      expect(container.read(interestsProvider), {
        EventCategory.pokemon,
        EventCategory.magic,
      });
    });

    test('ignores a stored category that no longer exists', () async {
      // A category removed from the enum in a later version must not crash
      // the app for someone who had it selected.
      final container = await containerWith({
        'event_interests': ['pokemon', 'jogo_que_nao_existe_mais'],
        'event_interests_answered': true,
      });

      expect(container.read(interestsProvider), {EventCategory.pokemon});
    });
  });

  group('FCM topics', () {
    test('names a topic per followed game', () async {
      final container = await containerWith({
        'event_interests': ['pokemon', 'rpg'],
        'event_interests_answered': true,
      });
      final controller = container.read(interestsProvider.notifier);

      expect(controller.topics, {'game_pokemon', 'game_rpg'});
    });

    test('also names the topics to unsubscribe from', () async {
      // FCM has no "replace my subscriptions" call, so a change has to say
      // both what to add and what to drop.
      final container = await containerWith({
        'event_interests': ['pokemon'],
        'event_interests_answered': true,
      });
      final controller = container.read(interestsProvider.notifier);

      expect(controller.topics, {'game_pokemon'});
      expect(controller.unsubscribedTopics, contains('game_magic'));
      expect(controller.unsubscribedTopics, isNot(contains('game_pokemon')));
      expect(
        controller.topics.length + controller.unsubscribedTopics.length,
        InterestsController.selectable.length,
        reason: 'todo jogo cai em exatamente um dos dois conjuntos',
      );
    });

    test('every topic name is valid for FCM', () async {
      final container = await containerWith({});
      final controller = container.read(interestsProvider.notifier);

      // FCM accepts [a-zA-Z0-9-_.~%]+ only.
      final valid = RegExp(r'^[a-zA-Z0-9\-_.~%]+$');
      for (final topic in controller.topics) {
        expect(valid.hasMatch(topic), isTrue, reason: 'topic inválido: $topic');
      }
    });
  });
}

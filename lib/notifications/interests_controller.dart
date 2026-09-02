import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme_controller.dart';
import '../domain/event_category.dart';

/// The games the user follows.
///
/// These become FCM topic subscriptions, so a new Magic event only wakes the
/// phones of people who play Magic. Sending every new event to every device is
/// how an app trains people to turn its notifications off.
///
/// Stored on the device, not behind a login: choosing your games should not
/// require an account. When an account exists it mirrors these so they survive
/// a new phone.
final interestsProvider =
    NotifierProvider<InterestsController, Set<EventCategory>>(
  InterestsController.new,
);

class InterestsController extends Notifier<Set<EventCategory>> {
  static const _key = 'event_interests';

  /// Marks that the user has been through the picker, so an empty selection
  /// means "nothing, deliberately" rather than "never asked".
  static const _answeredKey = 'event_interests_answered';

  /// The categories worth offering. [EventCategory.other] is the catch-all the
  /// detector falls back to, not something anyone would choose to follow.
  static List<EventCategory> get selectable => EventCategory.values
      .where((category) => category != EventCategory.other)
      .toList();

  @override
  Set<EventCategory> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getStringList(_key);

    if (stored == null) {
      // Never asked: follow everything, so a fresh install does not miss the
      // announcement it installed the app for.
      return selectable.toSet();
    }

    return stored
        .map((name) => EventCategory.values
            .where((category) => category.name == name)
            .firstOrNull)
        .whereType<EventCategory>()
        .toSet();
  }

  /// Whether the user has actually made a choice.
  bool get hasChosen =>
      ref.read(sharedPreferencesProvider).getBool(_answeredKey) ?? false;

  bool follows(EventCategory category) => state.contains(category);

  /// Whether every selectable game is followed.
  bool get followsEverything => state.length == selectable.length;

  Future<void> toggle(EventCategory category) async {
    final next = follows(category)
        ? state.difference({category})
        : {...state, category};
    await _persist(next);
  }

  Future<void> followAll() => _persist(selectable.toSet());

  Future<void> followNone() => _persist(const {});

  /// The FCM topic names for the current selection.
  ///
  /// A topic name must match `[a-zA-Z0-9-_.~%]+`, which every enum name does.
  /// Prefixed so topics from this app never collide with anything else in the
  /// Firebase project.
  Set<String> get topics =>
      state.map((category) => 'game_${category.name}').toSet();

  /// The topics that should be unsubscribed — everything not followed.
  ///
  /// FCM has no "replace my subscriptions" call, so a change has to say both
  /// what to add and what to drop.
  Set<String> get unsubscribedTopics => selectable
      .where((category) => !state.contains(category))
      .map((category) => 'game_${category.name}')
      .toSet();

  Future<void> _persist(Set<EventCategory> categories) async {
    state = categories;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(
      _key,
      categories.map((category) => category.name).toList(growable: false),
    );
    await prefs.setBool(_answeredKey, true);
  }
}

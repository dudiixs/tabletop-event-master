import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletop_events/core/theme/theme_controller.dart';
import 'package:tabletop_events/features/play/domain/match_controller.dart';
import 'package:tabletop_events/features/play/domain/mtg_format.dart';

/// Reading the saved match must never take the PLAY tab down.
///
/// Found by hand-seeding a match into the web build's storage: the value came
/// back as a map, `getString` threw a `TypeError` before any of the parsing
/// code ran, and the whole screen died on a red error page. Whatever is in
/// there, the worst outcome should be an empty table.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> containerWith(
    Map<String, Object> preferences,
  ) async {
    SharedPreferences.setMockInitialValues(preferences);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('no saved match means no table', () async {
    final container = await containerWith({});
    expect(container.read(matchProvider), isNull);
  });

  test('a truncated match is dropped, not thrown', () async {
    final container = await containerWith({'mtg_match': '{"format": "comm'});
    expect(container.read(matchProvider), isNull);
  });

  test('a match with no players is dropped', () async {
    final container = await containerWith({
      'mtg_match': '{"format": "commander", "players": []}',
    });
    expect(container.read(matchProvider), isNull);
  });

  test('a value of the wrong type is dropped', () async {
    // `getString` throws on this one before the parsing ever starts.
    final container = await containerWith({'mtg_match': 42});
    expect(container.read(matchProvider), isNull);
  });

  test('and a new game still starts afterwards', () async {
    final container = await containerWith({'mtg_match': 42});
    container
        .read(matchProvider.notifier)
        .start(format: MtgFormat.commander, playerCount: 3);

    expect(container.read(matchProvider)?.players, hasLength(3));
  });
}

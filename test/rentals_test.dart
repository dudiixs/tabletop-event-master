import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tabletop_events/core/format/formatters.dart';
import 'package:tabletop_events/data/rentals_data_source.dart';
import 'package:tabletop_events/domain/rental_game.dart';
import 'package:tabletop_events/domain/rental_quote.dart';
import 'package:tabletop_events/features/rentals/rental_cart.dart';

import 'fixture_data_source_test.dart' show StringBundle;

RentalGame game({
  String id = 'azul',
  String title = 'Azul',
  double dailyPrice = 15,
  double deposit = 100,
  bool available = true,
}) => RentalGame(
  id: id,
  title: title,
  tagline: 'Azulejos.',
  shelf: RentalShelf.family,
  minPlayers: 2,
  maxPlayers: 4,
  minMinutes: 30,
  maxMinutes: 45,
  minAge: 8,
  weight: 1.8,
  dailyPrice: dailyPrice,
  deposit: deposit,
  available: available,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => initializeDateFormatting(Fmt.locale));

  group('the bundled catalogue', () {
    test('parses, and every game is priced and seatable', () async {
      // Reads the real file, so a typo in the acervo fails here rather than in
      // front of a customer.
      final raw = await File('assets/fixtures/rentals.json').readAsString();
      final games = await RentalsDataSource(
        bundle: StringBundle({'assets/fixtures/rentals.json': raw}),
      ).fetchCatalogue();

      expect(games, isNotEmpty);
      for (final game in games) {
        expect(game.id, isNotEmpty);
        expect(game.title, isNotEmpty);
        expect(game.tagline, isNotEmpty, reason: game.title);
        expect(game.dailyPrice, greaterThan(0), reason: game.title);
        expect(
          game.minPlayers,
          lessThanOrEqualTo(game.maxPlayers),
          reason: game.title,
        );
      }

      expect(
        games.map((game) => game.id).toSet(),
        hasLength(games.length),
        reason: 'ids repetidos quebrariam a seleção do carrinho',
      );
    });

    test('a missing field falls back instead of throwing', () {
      final parsed = RentalGame.fromJson(
        jsonDecode('{"id": "x", "title": "Só o título"}')
            as Map<String, dynamic>,
      );

      expect(parsed.title, 'Só o título');
      expect(parsed.dailyPrice, 0);
      expect(parsed.available, isTrue);
    });
  });

  group('the quote', () {
    final pickup = DateTime(2026, 3, 6);

    test('charges one diária for a same-day rental', () {
      final quote = RentalQuote(
        games: [game(dailyPrice: 15)],
        pickup: pickup,
        dropoff: pickup,
      );

      expect(quote.days, 1);
      expect(quote.total, 15);
    });

    test('multiplies every game by the number of days', () {
      final quote = RentalQuote(
        games: [
          game(dailyPrice: 15),
          game(id: 'catan', dailyPrice: 18),
        ],
        pickup: pickup,
        dropoff: pickup.add(const Duration(days: 3)),
      );

      expect(quote.days, 3);
      expect(quote.total, (15 + 18) * 3);
      expect(quote.deposit, 200);
    });

    test('the WhatsApp message carries the dates, the games and the total', () {
      final quote = RentalQuote(
        games: [game(title: 'Wingspan', dailyPrice: 25, deposit: 180)],
        pickup: pickup,
        dropoff: pickup.add(const Duration(days: 2)),
      );

      final message = quote.whatsappMessage();

      expect(message, contains('Wingspan'));
      expect(message, contains(Fmt.fullDate(pickup)));
      expect(message, contains('2 diárias'));
      expect(message, contains(Fmt.money(50)));
      expect(message, contains(Fmt.money(180)));
    });
  });

  group('the cart', () {
    ProviderContainer cart() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container;
    }

    test('adds and removes the same game once', () {
      final container = cart();
      final notifier = container.read(rentalCartProvider.notifier);
      final azul = game();

      notifier
        ..toggle(azul)
        ..toggle(game(id: 'catan', title: 'Catan'));
      expect(container.read(rentalCartProvider).games, hasLength(2));

      notifier.toggle(azul);
      expect(container.read(rentalCartProvider).games.map((game) => game.id), [
        'catan',
      ]);
    });

    test('refuses a game that is already out', () {
      final container = cart();
      container
          .read(rentalCartProvider.notifier)
          .toggle(game(id: 'root', available: false));

      expect(container.read(rentalCartProvider).isEmpty, isTrue);
    });

    test('a return date before the pickup is pushed forward', () {
      final container = cart();
      final notifier = container.read(rentalCartProvider.notifier);

      notifier.setPeriod(
        pickup: DateTime(2026, 3, 10),
        dropoff: DateTime(2026, 3, 2),
      );

      final quote = container.read(rentalCartProvider);
      expect(quote.dropoff.isAfter(quote.pickup), isTrue);
      expect(quote.days, 1);
    });
  });
}

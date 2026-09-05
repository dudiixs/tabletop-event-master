import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/rental_game.dart';

/// The rental shelf, read from the bundled catalogue.
///
/// Same shape as [FixtureDataSource]: the file is the contract. When the
/// acervo moves to a Notion base behind the Worker, only this class changes —
/// it already returns the model the screens draw.
class RentalsDataSource {
  const RentalsDataSource({
    this.assetPath = 'assets/fixtures/rentals.json',
    this.bundle,
  });

  final String assetPath;

  /// Overridden in tests to serve the catalogue from memory.
  final AssetBundle? bundle;

  Future<List<RentalGame>> fetchCatalogue() async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Catálogo de locação mal formado.');
    }

    final games = decoded['games'];
    if (games is! List) {
      throw const FormatException('Catálogo de locação sem jogos.');
    }

    return games
        .whereType<Map>()
        .map((game) => RentalGame.fromJson(game.cast<String, dynamic>()))
        .where((game) => game.id.isNotEmpty)
        .toList(growable: false);
  }
}

final rentalsDataSourceProvider = Provider<RentalsDataSource>(
  (ref) => const RentalsDataSource(),
);

/// Everything the shop rents, sorted so what is available comes first.
final rentalCatalogueProvider = FutureProvider<List<RentalGame>>((ref) async {
  final games = await ref.watch(rentalsDataSourceProvider).fetchCatalogue();
  return [...games]..sort((a, b) {
    if (a.available != b.available) return a.available ? -1 : 1;
    return a.title.compareTo(b.title);
  });
});

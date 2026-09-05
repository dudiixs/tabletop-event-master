import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/rental_game.dart';
import '../../domain/rental_quote.dart';

/// What the customer has picked off the shelf, and for when.
///
/// Deliberately not persisted: a rental request is a single sitting, and a
/// cart that survives a week would quote yesterday's dates back at someone.
final rentalCartProvider = NotifierProvider<RentalCartController, RentalQuote>(
  RentalCartController.new,
);

class RentalCartController extends Notifier<RentalQuote> {
  @override
  RentalQuote build() {
    final today = DateTime.now();
    final pickup = DateTime(today.year, today.month, today.day);
    return RentalQuote(
      games: const [],
      pickup: pickup,
      // Two diárias is what a weekend actually costs, and it is the period
      // most people ask for.
      dropoff: pickup.add(const Duration(days: 2)),
    );
  }

  bool contains(RentalGame game) =>
      state.games.any((picked) => picked.id == game.id);

  void toggle(RentalGame game) {
    if (!game.available) return;
    state = state.copyWith(
      games: contains(game)
          ? state.games.where((picked) => picked.id != game.id).toList()
          : [...state.games, game],
    );
  }

  void remove(RentalGame game) {
    state = state.copyWith(
      games: state.games.where((picked) => picked.id != game.id).toList(),
    );
  }

  void clear() => state = state.copyWith(games: const []);

  /// Moves the period. The return date follows the pickup when it would end up
  /// in the past — a quote with a negative length is nobody's intention.
  void setPeriod({DateTime? pickup, DateTime? dropoff}) {
    final nextPickup = pickup ?? state.pickup;
    var nextDropoff = dropoff ?? state.dropoff;
    if (nextDropoff.isBefore(nextPickup)) {
      nextDropoff = nextPickup.add(const Duration(days: 1));
    }
    state = state.copyWith(pickup: nextPickup, dropoff: nextDropoff);
  }
}

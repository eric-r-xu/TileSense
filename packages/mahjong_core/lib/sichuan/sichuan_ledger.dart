/// The records a Sichuan hand keeps while it is played: each Hu in order, each
/// kong that earns a payment, and the payment lines the score screen lists.
/// Hu payments move points the moment they are declared; kong payments wait in
/// the ledger because the rules can still cancel them (a robbed kong, a kong
/// shot after, a declarer who finishes unready). See `Round._settleSichuan`.
library;

import '../scoring.dart';
import '../tile.dart';

/// One declared Hu, in the order they happened.
class SichuanHu {
  SichuanHu({
    required this.seat,
    required this.tile,
    required this.score,
    this.from,
    this.robbedKong = false,
  });

  final int seat;

  /// The winning tile: the discard claimed, or the tile drawn.
  final Tile tile;

  /// Fan in [HandScore.han], hand value in [HandScore.points].
  final HandScore score;

  /// Who paid: the discarder, or the kong declarer when the kong was robbed.
  /// Null on a self-draw, which every non-Hu seat pays.
  final int? from;
  final bool robbedKong;

  bool get selfDrawn => from == null;
}

enum SichuanKongKind { concealed, melded, added }

/// A kong that is owed a payment unless the rules cancel it.
class SichuanKong {
  SichuanKong({
    required this.seat,
    required this.kind,
    required this.type,
    required this.payers,
    required this.each,
    this.voided = false,
  });

  /// The seat that declared the kong (and collects).
  final int seat;
  final SichuanKongKind kind;
  final TileType type;

  /// The seats that owe [each] points. Fixed when the kong is declared.
  final List<int> payers;
  final int each;

  /// Cancelled: robbed, shot after, or an added kong on a tile held rather
  /// than just drawn.
  bool voided;
}

enum SichuanPaymentKind { hu, kong, ready, penalty }

/// One line of a hand's settlement, for the score screen.
class SichuanPayment {
  const SichuanPayment({
    required this.kind,
    required this.from,
    required this.to,
    required this.points,
    required this.label,
  });

  final SichuanPaymentKind kind;
  final int from;
  final int to;
  final int points;
  final String label;
}

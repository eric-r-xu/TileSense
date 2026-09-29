/// A posed riichi table as a made-up mjai history, since Mortal only reads
/// histories. Its engine (libriichi) checks only your seat: every tile you
/// cut or call with must be in your hand. So your pond tiles are drawn and
/// cut, each of your calls spends one pond tile, and your starting hand is
/// whatever that leaves.
///
/// Only your own draws are sent. The other seats' are never checked, and
/// leaving them out lets hidden filler draws set the wall to exactly the
/// posed count.
library;

import 'package:mahjong_core/meld.dart';
import 'package:mahjong_core/mjai.dart';
import 'package:mahjong_core/tile.dart';

import '../game/game_controller.dart' show kHumanSeat;
import 'scenario.dart';

/// The whole history, nothing hidden (see [mjaiView]); null when there is no
/// tile to read, your pond is too short to have made your calls, there are
/// more than four kans, or the wall runs dry before the end.
List<MjaiEvent>? scenarioMjaiEvents(Scenario sc) {
  String pai(TileType t) => mjaiTile(Tile(-1, t));
  const hidden = '?';
  if (!sc.isDiscardRead && sc.offered == null) return null;
  final hand =
      sc.isDiscardRead ? sc.hand.sublist(0, sc.hand.length - 1) : sc.hand;

  final start = [for (final t in hand) mjaiTile(t)];
  final turns = List.generate(4, (_) => <List<MjaiEvent>>[]);
  var draws = 0;
  List<MjaiEvent> draw(int seat, String tile) {
    if (seat != kHumanSeat) return const [];
    draws++;
    return [
      {'type': 'tsumo', 'actor': seat, 'pai': tile}
    ];
  }

  MjaiEvent dahai(int seat, String tile, {required bool tsumogiri}) =>
      {'type': 'dahai', 'actor': seat, 'pai': tile, 'tsumogiri': tsumogiri};

  for (final s in sc.seats) {
    final you = s.seat == kHumanSeat;
    var p = 0;

    List<MjaiEvent> cut({required bool drawn}) {
      final tile = mjaiTile(s.pond[p]);
      final riichi = s.riichi && p == s.riichiPondIndex;
      p++;
      return [
        if (drawn) ...draw(s.seat, tile),
        if (riichi) {'type': 'reach', 'actor': s.seat},
        dahai(s.seat, tile, tsumogiri: drawn && you),
        if (riichi) {'type': 'reach_accepted', 'actor': s.seat},
      ];
    }

    for (final m in s.melds) {
      final types = m.types.map(pai).toList();
      if (you && p >= s.pond.length) return null;
      final turn = <MjaiEvent>[];
      if (m.concealed) {
        // Three in the starting hand, the fourth drawn.
        if (you) start.addAll(types.take(3));
        turn
          ..addAll(draw(s.seat, types.first))
          ..add({'type': 'ankan', 'actor': s.seat, 'consumed': types});
      } else {
        final target = (s.seat + m.calledFromSeatOffset!) % 4;
        final consumed = types.skip(1).toList();
        if (you) start.addAll(consumed);
        turn
          ..addAll(draw(target, types.first))
          ..add(dahai(target, types.first, tsumogiri: target == kHumanSeat))
          ..add({
            'type': switch (m.kind) {
              MeldKind.sequence => 'chi',
              MeldKind.triplet => 'pon',
              _ => 'daiminkan',
            },
            'actor': s.seat,
            'target': target,
            'pai': types.first,
            'consumed': consumed,
          });
      }
      if (m.isKan) {
        if (p < s.pond.length) {
          turn.addAll(cut(drawn: true));
        } else {
          turn.addAll(draw(s.seat, hidden));
        }
      } else if (p < s.pond.length) {
        if (you) start.add(mjaiTile(s.pond[p]));
        turn.addAll(cut(drawn: false));
      }
      turns[s.seat].add(turn);
    }
    while (p < s.pond.length) {
      turns[s.seat].add(cut(drawn: true));
    }
  }

  final play = <MjaiEvent>[
    for (var t = 0; turns.any((seat) => seat.length > t); t++)
      for (var i = 0; i < 4; i++)
        if (turns[(sc.dealer + i) % 4].length > t)
          ...turns[(sc.dealer + i) % 4][t],
  ];
  final last = sc.isDiscardRead
      ? draw(kHumanSeat, mjaiTile(sc.hand.last))
      : [dahai(sc.offeredFrom, mjaiTile(sc.offered!), tsumogiri: false)];
  // libriichi panics past four kans.
  final kans = sc.seats.expand((s) => s.melds).where((m) => m.isKan).length;
  if (start.length != 13 || draws > 70 || kans > 4) return null;

  return [
    {
      'type': 'start_kyoku',
      'bakaze': pai(sc.roundWind.tile),
      'dora_marker': pai(sc.dora.first),
      'kyoku': sc.dealer + 1,
      'honba': sc.honba,
      'kyotaku': sc.riichiSticks,
      'oya': sc.dealer,
      'scores': const [25000, 25000, 25000, 25000],
      'tehais': [
        for (var i = 0; i < 4; i++)
          i == kHumanSeat ? start : List.filled(13, hidden),
      ],
    },
    for (final d in sc.dora.skip(1)) {'type': 'dora', 'dora_marker': pai(d)},
    for (var i = draws; i < 70 - sc.wallRemaining; i++)
      {'type': 'tsumo', 'actor': 1 + i % 3, 'pai': hidden},
    ...play,
    ...last,
  ];
}

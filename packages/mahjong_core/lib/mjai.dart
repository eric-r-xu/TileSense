/// A riichi [Round] as mjai events — the protocol Mortal reads — so the
/// Mortal-backed Saeko bot (offline, and on the multiplayer server) and the
/// guide's Mortal column can ask for a move. Only under riichi rules; every
/// other bot stays on `SimpleBot`. See flutter_client/BOT_STRATEGY.md.
///
/// [MjaiRecorder] is not told what happened; it watches. Call [sync] after
/// every action on the round and it turns whatever changed since the last
/// call into events, in the order the table saw them. One [Round] action can
/// be several events: a discard nobody can call also draws for the next seat,
/// so it comes out as `dahai` then `tsumo`.
///
/// Kan dora are sent when this engine flips them — at the replacement draw,
/// for every kind of kan — rather than at Tenhou's after-the-discard timing
/// for open kans, so Mortal sees the table as it really is. A hand is
/// recorded up to its end; the `hora` / `ryukyoku` that close it are never
/// needed for a decision, so they are not recorded.
library;

import 'meld.dart';
import 'round.dart';
import 'tile.dart';

typedef MjaiEvent = Map<String, Object?>;

/// A tile in mjai notation: `5m`, `5mr` for a red five, `E` `S` `W` `N` for
/// the winds and `P` `F` `C` for the white, green and red dragons.
String mjaiTile(Tile tile) => '${_mjaiType(tile.type)}${tile.aka ? 'r' : ''}';

String _mjaiType(TileType type) => switch (type) {
      TileType.haku => 'P',
      TileType.hatsu => 'F',
      TileType.chun => 'C',
      _ => type.code,
    };

List<String> _mjaiTiles(Iterable<Tile> tiles) => [for (final t in tiles) mjaiTile(t)];

/// [events] as [seat] receives them from an mjai server — the other seats'
/// starting hands and draws hidden — led by the `start_game` Mortal expects.
List<MjaiEvent> mjaiView(List<MjaiEvent> events, int seat) => [
      {'type': 'start_game'},
      for (final e in events)
        switch (e['type']) {
          'start_kyoku' => {
              ...e,
              'tehais': [
                for (var i = 0; i < 4; i++)
                  i == seat ? (e['tehais'] as List)[i] : List.filled(13, '?')
              ],
            },
          'tsumo' when e['actor'] != seat => {...e, 'pai': '?'},
          _ => e,
        },
    ];

class MjaiRecorder {
  /// Starts recording [round], which must be freshly dealt. [kyoku] is the
  /// hand's number within its round wind, 1-4.
  MjaiRecorder(this.round, {required int kyoku}) {
    events.add({
      'type': 'start_kyoku',
      'bakaze': _mjaiType(round.roundWind.tile),
      'dora_marker': mjaiTile(_doraIndicator(0)),
      'kyoku': kyoku,
      'honba': round.honba,
      'kyotaku': round.riichiSticks,
      'oya': round.dealer,
      'scores': List.of(round.startPoints),
      'tehais': [
        // The dealer's first draw has already happened; it is sent as the
        // hand's first `tsumo` by the [sync] below.
        for (final s in round.seats)
          _mjaiTiles(s.hand.where((t) => t != s.drawn)),
      ],
    });
    sync();
  }

  final Round round;

  /// Every event so far, with nothing hidden; see [mjaiView].
  final List<MjaiEvent> events = [];

  // What the table looked like at the last [sync].
  final List<int> _discards = List.filled(4, 0);
  final List<List<Meld>> _melds = List.generate(4, (_) => []);
  final List<Tile?> _drawn = List.filled(4, null);
  final List<bool> _riichi = List.filled(4, false);
  int _dora = 1;
  int? _reachPending;

  Tile _doraIndicator(int i) => round.wall.deadWallDisplay()[4 + i * 2]!;

  void sync() {
    for (var i = 0; i < 4; i++) {
      final s = round.seats[i];
      if (s.allDiscards.length == _discards[i]) continue;
      _discards[i] = s.allDiscards.length;
      if (s.riichi && !_riichi[i]) {
        _riichi[i] = true;
        _reachPending = i;
        events.add({'type': 'reach', 'actor': i});
      }
      final tile = s.allDiscards.last;
      events.add({
        'type': 'dahai',
        'actor': i,
        'pai': mjaiTile(tile),
        'tsumogiri': tile == _drawn[i],
      });
    }

    // A riichi is accepted once its discard clears the call window unronned.
    if (_reachPending != null && round.phase != RoundPhase.callOffer) {
      if (round.result?.kind != RoundEndKind.ron) {
        events.add({'type': 'reach_accepted', 'actor': _reachPending});
      }
      _reachPending = null;
    }

    for (var i = 0; i < 4; i++) {
      final melds = round.seats[i].melds;
      for (var m = 0; m < melds.length; m++) {
        final meld = melds[m];
        if (m >= _melds[i].length) {
          events.add(_call(i, meld));
        } else if (!identical(meld, _melds[i][m])) {
          // An added kan replaces the pon it extends.
          events.add({
            'type': 'kakan',
            'actor': i,
            'pai': mjaiTile(meld.tiles.last),
            'consumed': _mjaiTiles(meld.tiles.take(3)),
          });
        }
      }
      _melds[i] = List.of(melds);
    }

    final dora = round.wall.doraIndicators().length;
    for (; _dora < dora; _dora++) {
      events.add({'type': 'dora', 'dora_marker': mjaiTile(_doraIndicator(_dora))});
    }

    for (var i = 0; i < 4; i++) {
      final drawn = round.seats[i].drawn;
      if (drawn != null && drawn != _drawn[i]) {
        events.add({'type': 'tsumo', 'actor': i, 'pai': mjaiTile(drawn)});
      }
      _drawn[i] = drawn;
    }
  }

  /// A new meld: a concealed kan, or a call off the discard it ends with.
  MjaiEvent _call(int seat, Meld meld) {
    if (meld.concealed) {
      return {'type': 'ankan', 'actor': seat, 'consumed': _mjaiTiles(meld.tiles)};
    }
    return {
      'type': switch (meld.kind) {
        MeldKind.sequence => 'chi',
        MeldKind.triplet => 'pon',
        _ => 'daiminkan',
      },
      'actor': seat,
      'target': (seat + meld.calledFromSeatOffset!) % 4,
      'pai': mjaiTile(meld.tiles.last),
      'consumed': _mjaiTiles(meld.tiles.take(meld.tiles.length - 1)),
    };
  }
}

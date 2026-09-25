/// Wire codecs shared by the multiplayer game server and the online client.
///
/// A single [roundSnapshotToJson] / [buildRoundFromSnapshot] pair is the only
/// place that knows the shape of a round-over-the-wire: the server calls the
/// former (once per recipient, with a `reveal` predicate deciding whose hand
/// is sent in full), the client calls the latter to rebuild a real [Round] —
/// via [Round.posed] — from whatever the server sent. Keeping both directions
/// in one file means the encode and decode side can never drift apart.
///
/// The only things ever redacted are a seat's concealed [SeatState.hand],
/// which tile in it is the current draw, and — under Taiwanese rules, until
/// the hand ends — what its concealed kongs are made of (see
/// [Round.isHiddenKong]). Everything else on a mahjong table (discards, other
/// melds, flowers, riichi declarations, points, dora) is public knowledge in
/// the real game and is always sent in full.
library;

import 'hong_kong/hong_kong_rules.dart';
import 'hong_kong/hong_kong_wall.dart';
import 'meld.dart';
import 'round.dart';
import 'ruleset.dart';
import 'scoring.dart';
import 'taiwanese/taiwanese_rules.dart';
import 'tile.dart';
import 'wall.dart';

// --- primitive codecs -------------------------------------------------

Map<String, dynamic> tileToJson(Tile t) =>
    {'id': t.id, 'type': t.type.name, if (t.aka) 'aka': true};

Tile tileFromJson(Map<String, dynamic> json) => Tile(
      json['id'] as int,
      TileType.values.byName(json['type'] as String),
      aka: json['aka'] as bool? ?? false,
    );

List<Map<String, dynamic>> tilesToJson(Iterable<Tile> tiles) =>
    [for (final t in tiles) tileToJson(t)];

List<Tile> tilesFromJson(List<dynamic> json) =>
    [for (final t in json) tileFromJson(t as Map<String, dynamic>)];

Map<String, dynamic> meldToJson(Meld m) => {
      'kind': m.kind.name,
      'low': m.low.name,
      'concealed': m.concealed,
      'addedKan': m.addedKan,
      if (m.calledFromSeatOffset != null)
        'calledFromSeatOffset': m.calledFromSeatOffset,
      'tiles': tilesToJson(m.tiles),
    };

Meld meldFromJson(Map<String, dynamic> json) => Meld(
      kind: MeldKind.values.byName(json['kind'] as String),
      low: TileType.values.byName(json['low'] as String),
      concealed: json['concealed'] as bool,
      addedKan: json['addedKan'] as bool? ?? false,
      calledFromSeatOffset: json['calledFromSeatOffset'] as int?,
      tiles: tilesFromJson(json['tiles'] as List),
    );

Map<String, dynamic> yakuResultToJson(YakuResult y) =>
    {'name': y.name, 'han': y.han, 'yakuman': y.yakuman};

YakuResult yakuResultFromJson(Map<String, dynamic> json) => YakuResult(
      json['name'] as String,
      json['han'] as int,
      yakuman: json['yakuman'] as int? ?? 0,
    );

Map<String, dynamic> handScoreToJson(HandScore s) => {
      'yaku': [for (final y in s.yaku) yakuResultToJson(y)],
      'han': s.han,
      'fu': s.fu,
      'yakuman': s.yakuman,
      'points': s.points,
      'dealerPays': s.dealerPays,
      'nonDealerPays': s.nonDealerPays,
      'limitName': s.limitName,
      'valid': s.valid,
    };

HandScore handScoreFromJson(Map<String, dynamic> json) => HandScore(
      yaku: [
        for (final y in json['yaku'] as List)
          yakuResultFromJson(y as Map<String, dynamic>)
      ],
      han: json['han'] as int,
      fu: json['fu'] as int,
      yakuman: json['yakuman'] as int,
      points: json['points'] as int,
      dealerPays: json['dealerPays'] as int,
      nonDealerPays: json['nonDealerPays'] as int,
      limitName: json['limitName'] as String,
      valid: json['valid'] as bool,
    );

Map<String, dynamic> roundResultToJson(RoundResult r) => {
      'kind': r.kind.name,
      'winners': r.winners,
      'loser': r.loser,
      'score': r.score == null ? null : handScoreToJson(r.score!),
      'scores': [for (final s in r.scores) handScoreToJson(s)],
      'winTiles': {
        for (final e in r.winTiles.entries) '${e.key}': tileToJson(e.value)
      },
      'pointDeltas': {
        for (final e in r.pointDeltas.entries) '${e.key}': e.value
      },
      'tenpaiAtDraw': r.tenpaiAtDraw,
      'label': r.label,
    };

/// [localSeat] remaps a server seat index to the recipient's local index
/// (always 0 for "me"), matching every seat-indexed field below.
RoundResult roundResultFromJson(
  Map<String, dynamic> json, {
  required int Function(int) localSeat,
}) {
  final scoreJson = json['score'] as Map<String, dynamic>?;
  return RoundResult(
    kind: RoundEndKind.values.byName(json['kind'] as String),
    winners: [for (final w in json['winners'] as List) localSeat(w as int)],
    loser: json['loser'] == null ? null : localSeat(json['loser'] as int),
    score: scoreJson == null ? null : handScoreFromJson(scoreJson),
    scores: [
      for (final s in json['scores'] as List)
        handScoreFromJson(s as Map<String, dynamic>)
    ],
    winTiles: {
      for (final e in (json['winTiles'] as Map<String, dynamic>).entries)
        localSeat(int.parse(e.key)):
            tileFromJson(e.value as Map<String, dynamic>)
    },
    pointDeltas: {
      for (final e in (json['pointDeltas'] as Map<String, dynamic>).entries)
        localSeat(int.parse(e.key)): e.value as int
    },
    tenpaiAtDraw: [
      for (final s in json['tenpaiAtDraw'] as List) localSeat(s as int)
    ],
    label: json['label'] as String,
  );
}

// --- round snapshot -----------------------------------------------------

/// Serializes [round] for one recipient. [reveal] decides, per server seat
/// index, whether that seat's real hand goes over the wire (true only for
/// the recipient's own seat) or just its tile count.
Map<String, dynamic> roundSnapshotToJson(
  Round round, {
  required bool Function(int seat) reveal,
}) {
  return {
    'ruleset': round.ruleset.name,
    'minimumFaan': round.minimumFaan,
    'minimumPoints': round.minimumPoints,
    'dealer': round.dealer,
    'roundWind': round.roundWind.name,
    'honba': round.honba,
    'riichiSticks': round.riichiSticks,
    'turn': round.turn,
    'phase': round.phase.name,
    'wallRemaining': round.wall.remaining,
    'doraIndicators': [
      for (final d in round.wall.doraIndicators()) d.name,
    ],
    // Secret until the round is actually over — sending it any earlier
    // would leak a riichi hand's ura dora to every seat in real time.
    'uraDoraIndicators': round.result == null
        ? const <String>[]
        : [for (final d in round.wall.uraDoraIndicators()) d.name],
    'pendingDiscard':
        round.pendingDiscard == null ? null : tileToJson(round.pendingDiscard!),
    'pendingDiscardSeat':
        round.pendingDiscardSeat < 0 ? null : round.pendingDiscardSeat,
    'callOptions': [
      for (final c in round.callOptions)
        {
          'seat': c.seat,
          'types': [for (final t in c.types) t.name],
        }
    ],
    'seats': [
      for (final s in round.seats) _seatToJson(round, s, reveal(s.seat))
    ],
    'result': round.result == null ? null : roundResultToJson(round.result!),
  };
}

Map<String, dynamic> _seatToJson(Round round, SeatState s, bool revealed) => {
      'seat': s.seat,
      'points': s.points,
      'handRevealed': revealed,
      if (revealed) 'hand': tilesToJson(s.hand),
      'handCount': s.hand.length,
      'hasDrawn': s.drawn != null,
      if (revealed && s.drawn != null) 'drawnId': s.drawn!.id,
      'pond': tilesToJson(s.pond),
      'melds': [
        for (final m in s.melds)
          meldToJson(
              !revealed && round.isHiddenKong(m) ? _faceDownKong(m) : m)
      ],
      'flowers': tilesToJson(s.flowers),
      'riichi': s.riichi,
      'doubleRiichi': s.doubleRiichi,
      'ippatsu': s.ippatsu,
      'tempFuriten': s.tempFuriten,
      'riichiFuriten': s.riichiFuriten,
      'allDiscards': tilesToJson(s.allDiscards),
      'passedDiscardsAfterRiichi': [
        for (final t in s.passedDiscardsAfterRiichi) t.name,
      ],
    };

/// [m] as another seat sees it face down: four blanks, same tile ids.
Meld _faceDownKong(Meld m) => Meld(
      kind: MeldKind.kan,
      low: TileType.blank,
      concealed: true,
      tiles: [for (final t in m.tiles) Tile(t.id, TileType.blank)],
    );

/// Rebuilds a playable [Round] from a [roundSnapshotToJson] payload, with
/// every seat index remapped through [mySeat] so the recipient always lands
/// at local seat 0 — the assumption every existing single-player UI widget
/// makes (`round.seats[kHumanSeat]` for "you").
Round buildRoundFromSnapshot(Map<String, dynamic> json, {required int mySeat}) {
  int localSeat(int serverSeat) => (serverSeat - mySeat + 4) % 4;

  final ruleset = Ruleset.values.byName(json['ruleset'] as String);
  final roundWind = Wind.values.byName(json['roundWind'] as String);
  final wallRemaining = json['wallRemaining'] as int;
  final dora = [
    for (final d in json['doraIndicators'] as List)
      TileType.values.byName(d as String)
  ];
  final ura = [
    for (final d in (json['uraDoraIndicators'] as List? ?? const []))
      TileType.values.byName(d as String)
  ];
  final wall = ruleset.isChineseStyle
      ? HongKongWall.posed(remaining: wallRemaining)
      : Wall.posed(remaining: wallRemaining, dora: dora, ura: ura);

  final seatsJson = [
    for (final s in json['seats'] as List) s as Map<String, dynamic>
  ];
  final startingPoints = List<int>.filled(4, 0);
  for (final sj in seatsJson) {
    startingPoints[localSeat(sj['seat'] as int)] = sj['points'] as int;
  }

  final round = Round.posed(
    dealer: localSeat(json['dealer'] as int),
    roundWind: roundWind,
    honba: json['honba'] as int,
    riichiSticks: json['riichiSticks'] as int,
    wall: wall,
    startingPoints: startingPoints,
    ruleset: ruleset,
    minimumFaan: HongKongRules.normalizeMinimumFaan(json['minimumFaan']),
    minimumPoints:
        TaiwaneseRules.normalizeMinimumPoints(json['minimumPoints']),
  );

  var nextPlaceholderId = -900000;
  for (final sj in seatsJson) {
    final seat = round.seats[localSeat(sj['seat'] as int)];
    final revealed = sj['handRevealed'] as bool;
    final hasDrawn = sj['hasDrawn'] as bool;
    List<Tile> hand;
    Tile? drawn;
    if (revealed) {
      hand = tilesFromJson(sj['hand'] as List);
      final drawnId = sj['drawnId'] as int?;
      if (hasDrawn && drawnId != null) {
        for (final t in hand) {
          if (t.id == drawnId) drawn = t;
        }
      }
    } else {
      final count = sj['handCount'] as int;
      hand = [
        for (var k = 0; k < count; k++)
          Tile(nextPlaceholderId--, TileType.blank)
      ];
      if (hasDrawn && hand.isNotEmpty) drawn = hand.last;
    }
    seat.hand = hand;
    seat.drawn = drawn;
    seat.pond = tilesFromJson(sj['pond'] as List);
    seat.melds = [
      for (final m in sj['melds'] as List)
        meldFromJson(m as Map<String, dynamic>)
    ];
    seat.flowers = tilesFromJson(sj['flowers'] as List);
    seat.riichi = sj['riichi'] as bool;
    seat.doubleRiichi = sj['doubleRiichi'] as bool;
    seat.ippatsu = sj['ippatsu'] as bool;
    seat.tempFuriten = sj['tempFuriten'] as bool;
    seat.riichiFuriten = sj['riichiFuriten'] as bool;
    seat.allDiscards.addAll(tilesFromJson(sj['allDiscards'] as List));
    seat.passedDiscardsAfterRiichi.addAll([
      for (final t in sj['passedDiscardsAfterRiichi'] as List)
        TileType.values.byName(t as String)
    ]);
  }

  round.turn = localSeat(json['turn'] as int);
  round.phase = RoundPhase.values.byName(json['phase'] as String);
  final pendingDiscardJson = json['pendingDiscard'];
  round.pendingDiscard = pendingDiscardJson == null
      ? null
      : tileFromJson(pendingDiscardJson as Map<String, dynamic>);
  final pendingDiscardSeat = json['pendingDiscardSeat'] as int?;
  round.pendingDiscardSeat =
      pendingDiscardSeat == null ? -1 : localSeat(pendingDiscardSeat);
  round.callOptions = [
    for (final c in json['callOptions'] as List)
      CallOption(
        localSeat((c as Map<String, dynamic>)['seat'] as int),
        {
          for (final t in c['types'] as List)
            CallType.values.byName(t as String)
        },
      )
  ];
  final resultJson = json['result'] as Map<String, dynamic>?;
  round.result = resultJson == null
      ? null
      : roundResultFromJson(resultJson, localSeat: localSeat);
  return round;
}

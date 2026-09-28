// MjaiRecorder, the Grant bot's feed to Mortal. Without a server: the events
// must rebuild every seat's concealed hand after every action. With the Mortal
// sidecar running (see mortal_sidecar/server.py), Mortal's own legal-action
// mask must agree with this engine's legal moves at every decision:
//
//   MORTAL_URL=http://127.0.0.1:8765 MORTAL_HANDS=20 dart test test/mjai_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

/// Plays one riichi hand with [SimpleBot]s. SimpleBot never chis, so a call it
/// passes up is taken at random half the time, to exercise every kind of
/// call. [onAction] runs after every action, once the recorder has synced.
void _playHand(int seed, void Function(Round, MjaiRecorder) onAction) {
  final rng = Random(seed);
  final round = Round(
    seed: seed,
    dealer: seed % 4,
    roundWind: Wind.east,
    startingPoints: List.filled(4, 25000),
  );
  final recorder = MjaiRecorder(round, kyoku: seed % 4 + 1);
  final bots = [for (var i = 0; i < 4; i++) SimpleBot(seed * 10 + i)];
  onAction(round, recorder);
  for (var step = 0; !round.finished; step++) {
    if (step > 4000) fail('seed $seed: hand did not finish');
    if (round.phase == RoundPhase.callOffer) {
      final discard = round.pendingDiscard!;
      final choices = <int, CallType>{};
      final chiLow = <int, TileType>{};
      for (final opt in round.callOptions) {
        var c = bots[opt.seat].decideCall(round, opt.seat, discard, opt.types);
        final calls = opt.types.where((t) => t != CallType.ron).toList();
        if (c == CallType.none && calls.isNotEmpty && rng.nextBool()) {
          c = calls[rng.nextInt(calls.length)];
        }
        if (c == CallType.chi) {
          final runs = round.chiSequences(opt.seat, discard);
          chiLow[opt.seat] = runs[rng.nextInt(runs.length)];
        }
        if (c != CallType.none) choices[opt.seat] = c;
      }
      round.resolveCalls(choices, chiLow: chiLow);
    } else {
      final seat = round.turn;
      final d = bots[seat].decideTurn(round, seat);
      if (d.tsumo) {
        round.declareTsumo(seat);
      } else if (d.closedKan != null) {
        round.closedKan(seat, d.closedKan!);
      } else if (d.addedKan != null) {
        round.addKan(seat, d.addedKan!);
      } else {
        round.discard(seat, d.discard ?? round.legalDiscards(seat).first,
            declareRiichi: d.riichi);
      }
    }
    recorder.sync();
    onAction(round, recorder);
  }
}

List<String> _sorted(Iterable<String> tiles) => tiles.toList()..sort();

/// Mortal's action index for discarding [t]: 0-33 by type, 34-36 red fives.
int _discardIndex(Tile t) => t.aka ? 34 + t.type.suit : t.type.index - 1;

/// This engine's legal actions for [seat] right now, in Mortal's action space.
Set<int> _turnActions(Round round, int seat) => {
      for (final t in round.legalDiscards(seat)) _discardIndex(t),
      if (round.canRiichi(seat)) 37,
      if (round.closedKanTypes(seat).isNotEmpty ||
          round.addedKanTypes(seat).isNotEmpty)
        42,
      if (round.canTsumo(seat)) 43,
      if (round.canDeclareKyuushu(seat)) 44,
    };

Set<int> _callActions(Round round, int seat) {
  final option = round.callOptions.where((o) => o.seat == seat).firstOrNull;
  if (round.phase != RoundPhase.callOffer || option == null) return {};
  final discard = round.pendingDiscard!;
  return {
    if (option.types.contains(CallType.chi))
      for (final low in round.chiSequences(seat, discard))
        38 + discard.type.number - low.number,
    if (option.types.contains(CallType.pon)) 41,
    if (option.types.contains(CallType.kan)) 42,
    if (option.types.contains(CallType.ron)) 43,
    45,
  };
}

final _mortalUrl = Platform.environment['MORTAL_URL'];

void main() {
  test('tiles use mjai notation', () {
    expect(mjaiTile(const Tile(0, TileType.man5, aka: true)), '5mr');
    expect(mjaiTile(const Tile(1, TileType.sou9)), '9s');
    expect(mjaiTile(const Tile(2, TileType.pei)), 'N');
    expect(
        [TileType.haku, TileType.hatsu, TileType.chun]
            .map((t) => mjaiTile(Tile(3, t))),
        ['P', 'F', 'C']);
  });

  test('events rebuild every hand after every action, every call covered', () {
    final seen = <String>{};
    for (var seed = 0; seed < 300; seed++) {
      _playHand(seed, (round, recorder) {
        final hands = List.generate(4, (_) => <String>[]);
        var dora = 0;
        for (final e in recorder.events) {
          seen.add(e['type'] as String);
          final hand = hands[(e['actor'] as int?) ?? 0];
          void take(Object? tile) =>
              expect(hand.remove(tile), isTrue, reason: 'seed $seed: $e');
          switch (e['type']) {
            case 'start_kyoku':
              for (var i = 0; i < 4; i++) {
                hands[i].addAll((e['tehais'] as List)[i] as List<String>);
              }
              dora++;
            case 'tsumo':
              hand.add(e['pai'] as String);
            case 'dahai' || 'kakan':
              take(e['pai']);
            case 'chi' || 'pon' || 'daiminkan' || 'ankan':
              (e['consumed'] as List).forEach(take);
            case 'dora':
              dora++;
          }
        }
        for (var i = 0; i < 4; i++) {
          expect(_sorted(hands[i]),
              _sorted(round.seats[i].hand.map(mjaiTile)),
              reason: 'seed $seed seat $i');
        }
        expect(dora, round.wall.doraIndicators().length, reason: 'seed $seed');
      });
    }
    expect(seen, containsAll(['chi', 'pon', 'daiminkan', 'ankan', 'kakan',
        'reach', 'reach_accepted', 'dora']));
  });

  test("a seat's view hides the others' hands and draws", () {
    final round = Round(
        seed: 1, dealer: 0, roundWind: Wind.east,
        startingPoints: List.filled(4, 25000));
    final view = mjaiView(MjaiRecorder(round, kyoku: 1).events, 1);
    expect(view.first, {'type': 'start_game'});
    final tehais = view[1]['tehais'] as List;
    expect(tehais[0], List.filled(13, '?'));
    expect(tehais[1], isNot(contains('?')));
    expect(view[2], {'type': 'tsumo', 'actor': 0, 'pai': '?'});
  });

  test("Mortal's legal actions match this engine's at every decision",
      () async {
    final url = Uri.parse('$_mortalUrl/react');
    final http = HttpClient();
    final hands = int.parse(Platform.environment['MORTAL_HANDS'] ?? '20');
    final problems = <String>[];
    var decisions = 0, afterCall = 0, lastDiscard = 0;

    for (var seed = 0; seed < hands; seed++) {
      // Worked out while the hand plays, asked once it is over.
      final asks = <({int seat, List<MjaiEvent> events, Set<int> legal,
          Set<String> discards, bool turn, bool called, bool lastTile,
          String at})>[];
      var synced = 0;
      _playHand(seed, (round, recorder) {
        final events = recorder.events;
        for (var k = synced; k < events.length; k++) {
          final e = events[k];
          if (e['type'] != 'dahai' && e['type'] != 'kakan') continue;
          final last = k == events.length - 1;
          for (var seat = 0; seat < 4; seat++) {
            if (seat == e['actor']) continue;
            asks.add((
              seat: seat,
              events: mjaiView(events.sublist(0, k + 1), seat),
              legal: last ? _callActions(round, seat) : {},
              discards: {},
              turn: false,
              called: false,
              lastTile: round.wall.isEmpty,
              at: 'seed $seed event $k',
            ));
          }
        }
        synced = events.length;
        if (round.phase == RoundPhase.discarding && !round.finished) {
          final seat = round.turn;
          asks.add((
            seat: seat,
            events: mjaiView(events, seat),
            legal: _turnActions(round, seat),
            discards: round.legalDiscards(seat).map(mjaiTile).toSet(),
            turn: true,
            called: const {'chi', 'pon'}.contains(events.last['type']),
            lastTile: round.wall.isEmpty,
            at: 'seed $seed event ${events.length - 1}',
          ));
        }
      });

      for (final a in asks) {
        decisions++;
        final req = await http.postUrl(url);
        final payload =
            utf8.encode(jsonEncode({'player_id': a.seat, 'events': a.events}));
        req.headers.contentType = ContentType.json;
        req.contentLength = payload.length;
        req.add(payload);
        final res = await req.close();
        final body = jsonDecode(await res.transform(utf8.decoder).join())
            as Map<String, Object?>;
        final where = '${a.at} seat ${a.seat}';
        if (res.statusCode != 200) {
          problems.add('$where: ${body['error']}');
          continue;
        }
        final reaction = body['reaction'] as Map<String, Object?>?;
        final meta = reaction?['meta'] as Map<String, Object?>?;
        if (reaction != null && meta == null) {
          // Mortal skips the model when one discard is its only legal action,
          // so there is no mask: check the discard, and that nothing but
          // discards was legal here either.
          if (reaction['type'] != 'dahai' ||
              !a.discards.contains(reaction['pai']) ||
              a.legal.any((i) => i >= 37)) {
            problems.add('$where: lone $reaction vs ${_sortedInts(a.legal)}');
          }
          continue;
        }
        final bits = (meta?['mask_bits'] as int?) ?? 0;
        final mortal = {for (var i = 0; i < 46; i++) if (bits >> i & 1 == 1) i};
        final onlyMortal = mortal.difference(a.legal);
        final onlyHere = a.legal.difference(mortal);
        // Three places Tenhou's rules, which Mortal plays by, are stricter
        // than this engine's: straight after a call it bars discarding the
        // called tile back out (kuikae) and an added kan before discarding,
        // and nobody may call the hand's last discard.
        if (onlyMortal.isEmpty && onlyHere.isNotEmpty) {
          if (a.turn && a.called && onlyHere.every((i) => i < 37 || i == 42)) {
            afterCall++;
            continue;
          }
          if (!a.turn && a.lastTile && mortal.isEmpty) {
            lastDiscard++;
            continue;
          }
        }
        if (onlyMortal.isNotEmpty || onlyHere.isNotEmpty) {
          problems.add('$where: only Mortal ${_sortedInts(onlyMortal)}, '
              'only here ${_sortedInts(onlyHere)}');
        }
      }
    }
    http.close();
    print('$decisions decisions over $hands hands; Tenhou stricter after a '
        'call $afterCall times, on the last discard $lastDiscard times; '
        '${problems.length} problems');
    problems.take(30).forEach(print);
    expect(problems, isEmpty);
  },
      skip: _mortalUrl == null ? 'set MORTAL_URL to check against Mortal' : null,
      timeout: Timeout.none);
}

List<int> _sortedInts(Set<int> s) => s.toList()..sort();

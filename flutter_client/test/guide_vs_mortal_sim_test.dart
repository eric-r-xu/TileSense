// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/bot.dart';
import 'package:mahjong_core/mjai.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/guide_host.dart';
import 'package:tilesense/game/mortal_advisor.dart';
import 'package:tilesense/game/sfx.dart';

/// Monte-Carlo check of whether the guide (Autoplay at seat 0) beats three
/// Saeko bots playing Mortal's moves. Drives the real [GameController], like
/// guide_vs_bots_sim_test.dart, but Mortal answers over real HTTP, which
/// cannot run under fake time. [_SyncMortal] therefore makes each request a
/// blocking socket call that has its reply before the fake clock moves on.
///
/// Two arms on identical seeds:
///  * guide   — seat 0 on Autoplay with the TileSense guide;
///  * control — seat 0 on Autoplay following Mortal, the same engine as the
///    three Saeko seats.
/// The control sits at 2.5 by symmetry once the deal rotates, so it checks
/// the harness; the guide's own result is the paired difference between arms.
///
/// A game in which any Mortal request failed or named a move the table did
/// not offer is invalid, because that seat was played by SimpleBot (or the
/// guide) instead. Invalid games are counted and left out of the statistics.
///
/// To see where the guide loses, the report also breaks each seat's game into
/// win, deal-in, riichi and call rates and where the points came and went.
/// And in the guide arm Mortal is also asked what it would do at each of the
/// guide's decisions (the guide panel's Mortal column), which are then
/// compared with what the guide did.
///
/// One single-threaded sidecar per shard, from mortal_sidecar/ (setup steps in
/// server.py's header; it must be a libriichi that knows `game_length`):
///
///   for k in 0 1 2 3 4 5 6 7 8 9; do
///     .venv/bin/python server.py --model mortal_298k.onnx --port 879$k &
///   done
///   MORTAL_GAMES=200 flutter test test/guide_vs_mortal_sim_test.dart
///
/// Hybrid arms (MORTAL_HYBRIDS, e.g. `calls,kan,riichi,discard,calls+kan`) keep
/// the guide in seat 0 but hand it the named decisions from Mortal, to find
/// which of them carry the gap; see [MortalPart]. The first three are paired
/// with the other arms on the same seeds. A riichi that Mortal declares keeps
/// the discard it paired with it.
///
/// MORTAL_POS=PREFIX also writes every compared decision of the guide arm
/// (the position, Mortal's q-values and the guide's EV lines) to
/// PREFIX.SHARD.jsonl, one JSON object per line.
///
/// MORTAL_SHARDS (10) sidecars are expected on ports MORTAL_PORT (8790)+k.
/// MORTAL_EAST=0 plays hanchan instead of East-only. MORTAL_OPP=simple seats
/// three SimpleBots instead of the Saeko bots, to compare the guide and Mortal
/// on the same easy table. MORTAL_SEED (1000) is the first seed; MORTAL_OUT
/// writes one CSV row per game and arm.
void main() {
  final env = Platform.environment;
  final games = int.tryParse(env['MORTAL_GAMES'] ?? '') ?? 0;

  test('guide vs Saeko (Mortal) simulation', () async {
    final shards = int.tryParse(env['MORTAL_SHARDS'] ?? '') ?? 10;
    final base = int.tryParse(env['MORTAL_SEED'] ?? '') ?? 1000;
    final port = int.tryParse(env['MORTAL_PORT'] ?? '') ?? 8790;
    final east = env['MORTAL_EAST'] != '0';
    final sw = Stopwatch()..start();
    print('Riichi, ${east ? 'East-only' : 'hanchan'}, $games games/arm, '
        '$shards shards on ports $port-${port + shards - 1}');

    final names = [
      'guide',
      'control',
      ...?env['MORTAL_HYBRIDS']?.split(',').where((n) => n.isNotEmpty),
    ];
    final arms = <List<List<num>>>[];
    for (final name in names) {
      arms.add(await _runArm(base, games, shards, port, east, name,
          arms.length, env['MORTAL_POS']));
      print('$name arm: ${sw.elapsed.inSeconds}s');
    }

    final out = env['MORTAL_OUT'];
    if (out != null) {
      File(out).writeAsStringSync([
        _header.join(','),
        for (final arm in arms)
          for (final r in arm) r.join(','),
      ].join('\n'));
    }
    _report(names, arms);
  }, skip: games == 0 ? 'set MORTAL_GAMES to run' : false, timeout: Timeout.none);
}

// --- row layout -------------------------------------------------------------

// A game is one row of numbers: seed, arm (index into the arm names), hands,
// then these columns,
// four seats each, then the single columns, then the agreement counters.
const _perSeat = [
  'pts', // final points
  'win', // hands won
  'tsumo', // of which by self-draw
  'dealin', // hands lost to a ron
  'winGain', // points from won hands
  'lossRon', // points lost to rons on this seat
  'lossTsumo', // points paid to others' self-draws
  'other', // everything else: draw payments, riichi sticks, ...
  'riichi', // hands in which the seat declared riichi
  'called', // hands in which the seat opened its hand with a call
];
const _single = ['draws', 'fallbacks', 'asks', 'ms'];
int _seatCol(String name, int seat) => 3 + _perSeat.indexOf(name) * 4 + seat;
int _singleCol(String name) =>
    3 + _perSeat.length * 4 + _single.indexOf(name);

/// Where the guide's decisions are compared with Mortal's (guide arm only).
/// Discards are split by whether another seat has declared riichi.
final _agreeNames = [
  for (final ctx in ['calm', 'threat'])
    for (final f in [
      'dis', // discards where both named a tile
      'same', // the same tile
      'rank1', 'rank2', 'rank3', 'rank4plus', // Mortal's rank of the guide's tile
      'ranked', // how many of those had a rank
      'qgap', // summed gap between Mortal's best tile and the guide's
    ])
      '${ctx}_$f',
  'reachBoth', 'reachMortalOnly', 'reachGuideOnly',
  'kanBoth', 'kanMortalOnly', 'kanGuideOnly',
  // Calls offered to seat 0: Mortal's answer (rows) by the guide's (columns).
  for (final m in _callNames)
    for (final g in _callNames.take(4)) 'call_${m}_$g',
];
const _callNames = ['pass', 'pon', 'chi', 'kan', 'ron'];
final _agreeStart = _singleCol('ms') + 1;
int _agreeIdx(String name) => _agreeNames.indexOf(name);
int _agree(String name) => _agreeStart + _agreeIdx(name);
final _rowLength = _agreeStart + _agreeNames.length;

final _header = [
  'seed', 'arm', 'hands', //
  for (final n in _perSeat)
    for (var s = 0; s < 4; s++) '$n$s',
  ..._single,
  ..._agreeNames,
];

// --- Mortal over a blocking socket ------------------------------------------

/// Mortal over a blocking socket. In the control arm Mortal plays your seat,
/// so its answers are the moves. In the guide arm they are only the guide
/// panel's Mortal column, which [_SyncMortal] keeps and later compares with
/// the move the guide made from the same position.
class _SyncMortal extends MortalAdvisor {
  _SyncMortal(this.port, {required this.trackAgreement, this.seed = 0, this.log})
      : super('http://unused');
  final int port;
  final bool trackAgreement;
  final int seed;

  /// Where each compared decision is written, when the run is logging them.
  final RandomAccessFile? log;
  int asks = 0;
  final agree = List<num>.filled(_agreeNames.length, 0);

  // What the guide worked out at its decisions this hand, by how many events
  // had happened: its EV lines for a turn, its options for a call.
  String? _traceHand;
  final _traces = <int, Map<String, Object?>>{};

  void _trace(List<MjaiEvent> events, Map<String, Object?> what) {
    final hand = jsonEncode(events.first);
    if (hand != _traceHand) {
      _traceHand = hand;
      _traces.clear();
    }
    _traces[events.length] = what;
  }

  void traceTurn(List<MjaiEvent> events, EfficiencyReport report, BotTurn move) =>
      _trace(events, _turnJson(report, move));

  void traceCall(List<MjaiEvent> events, CallAdvice? advice) =>
      _trace(events, _callJson(advice));

  // The hand being followed, and how many of its events are compared already.
  String? _hand;
  var _done = 0;

  @override
  Future<Map<String, Object?>> ask(int seat, List<MjaiEvent> events,
      {bool hanchan = true}) {
    asks++;
    try {
      final reply = _post(seat, events, hanchan);
      if (trackAgreement) _catchUp(events, hanchan);
      return Future.value(reply);
    } catch (e) {
      return Future.error(e);
    }
  }

  Map<String, Object?> _post(int seat, List<MjaiEvent> events, bool hanchan) {
    final body = utf8.encode(jsonEncode({
      'player_id': seat,
      'events': mjaiView(events, seat),
      'game_length': hanchan ? 8 : 4,
    }));
    final socket = RawSynchronousSocket.connectSync('127.0.0.1', port);
    socket.writeFromSync(utf8.encode('POST /react HTTP/1.0\r\n'
        'Content-Type: application/json\r\n'
        'Content-Length: ${body.length}\r\n\r\n'));
    socket.writeFromSync(body);
    // The sidecar speaks HTTP/1.0 and closes the connection when done.
    final reply = <int>[];
    for (var chunk = socket.readSync(65536);
        chunk != null && chunk.isNotEmpty;
        chunk = socket.readSync(65536)) {
      reply.addAll(chunk);
    }
    socket.closeSync();
    final text = utf8.decode(reply);
    final payload = jsonDecode(text.substring(text.indexOf('\r\n\r\n') + 4))
        as Map<String, Object?>;
    if (!text.startsWith('HTTP/1.0 200')) {
      throw StateError('Mortal: ${payload['error']}');
    }
    return payload;
  }

  /// [events] is the hand so far with nothing hidden, so it already holds
  /// what the guide did at seat 0's earlier decisions. Asks Mortal what it
  /// would have done at each one not yet looked at, and compares.
  ///
  /// The guide's own wins are not in the events, and nothing is asked after a
  /// hand's last event, so a hand's final decisions are never compared.
  void _catchUp(List<MjaiEvent> events, bool hanchan) {
    final hand = jsonEncode(events.first);
    if (hand != _hand) {
      _hand = hand;
      _done = 1;
    }
    var mine = false, theirs = false;
    final table = _Table()..apply(events.first);
    for (var i = 1; i < events.length; i++) {
      final prev = events[i - 1];
      if (i >= _done) {
        final turn = prev['actor'] == kHumanSeat &&
            (prev['type'] == 'tsumo' ||
                prev['type'] == 'pon' ||
                prev['type'] == 'chi');
        final call = prev['type'] == 'dahai' && prev['actor'] != kHumanSeat;
        if (turn || call) {
          // A riichi's discard is the next event: wait until it is there.
          if (events[i]['type'] == 'reach' && i + 1 >= events.length) return;
          final reply =
              _post(kHumanSeat, events.sublist(0, i), hanchan);
          _compare(events, i, call, reply, mine, theirs, table);
        }
        _done = i + 1;
      }
      final e = events[i];
      table.apply(e);
      if (e['type'] == 'reach') {
        if (e['actor'] == kHumanSeat) mine = true;
        if (e['actor'] != kHumanSeat) theirs = true;
      }
    }
  }

  /// Compares what seat 0 did at event [n] with Mortal's [reply] there.
  void _compare(List<MjaiEvent> events, int n, bool call,
      Map<String, Object?> reply, bool mineRiichi, bool theirsRiichi,
      _Table table) {
    final a = events[n];
    final reaction = reply['reaction'] as Map<String, Object?>?;
    final type = reaction?['type'];
    if (call) {
      final m = switch (type) {
        'pon' => 1,
        'chi' => 2,
        'daiminkan' => 3,
        'hora' => 4,
        _ => 0,
      };
      final g = a['actor'] == kHumanSeat
          ? switch (a['type']) {
              'pon' => 1,
              'chi' => 2,
              'daiminkan' => 3,
              _ => 0,
            }
          : 0;
      // Both passing is most positions and says nothing: it is not counted.
      if (m != 0 || g != 0) {
        agree[_agreeIdx('call_${_callNames[m]}_${_callNames[g]}')]++;
        _record(events, n, 'call', table, reply, m == g ? 'none' : 'call');
      }
      return;
    }

    // A turn: a discard, a riichi (with its discard next) or a kan.
    if (a['actor'] != kHumanSeat) return;
    String? tile;
    var reach = false, kan = false;
    switch (a['type']) {
      case 'dahai':
        tile = '${a['pai']}';
      case 'reach':
        reach = true;
        tile = '${events[n + 1]['pai']}';
      case 'ankan' || 'kakan':
        kan = true;
      default:
        return;
    }
    final mReach = type == 'reach';
    final mKan = type == 'ankan' || type == 'kakan';
    if (mReach || reach) {
      agree[_agreeIdx(mReach && reach
          ? 'reachBoth'
          : mReach
              ? 'reachMortalOnly'
              : 'reachGuideOnly')]++;
    }
    if (mKan || kan) {
      agree[_agreeIdx(mKan && kan
          ? 'kanBoth'
          : mKan
              ? 'kanMortalOnly'
              : 'kanGuideOnly')]++;
    }
    // Once you are in riichi your discards are forced.
    if (mineRiichi || tile == null && !kan) return;
    final diff = mReach != reach
        ? 'riichi'
        : mKan != kan
            ? 'kan'
            : tile != null &&
                    reply['reaction'] != null &&
                    _bare(_mortalTile(reply) ?? '') != _bare(tile)
                ? 'discard'
                : 'none';
    _record(events, n, 'turn', table, reply, diff);
    if (tile == null || kan) return;
    final step = mReach
        ? reply['riichi_discard'] as Map<String, Object?>?
        : reaction;
    if (step?['type'] != 'dahai') return;
    final ctx = theirsRiichi ? 'threat' : 'calm';
    final mTile = _bare('${step!['pai']}'), gTile = _bare(tile);
    agree[_agreeIdx('${ctx}_dis')]++;
    if (mTile == gTile) agree[_agreeIdx('${ctx}_same')]++;
    final q = _discardQ(step);
    final best = q.values.fold<double>(-1e9, max);
    if (q.containsKey(gTile)) {
      final rank = 1 + q.values.where((v) => v > q[gTile]!).length;
      agree[_agreeIdx('${ctx}_rank${rank >= 4 ? '4plus' : rank}')]++;
      agree[_agreeIdx('${ctx}_ranked')]++;
      agree[_agreeIdx('${ctx}_qgap')] += best - q[gTile]!;
    }
  }

  /// Writes the decision at event [n] with the position, Mortal's scores and
  /// the guide's own numbers, when the run is logging them.
  void _record(List<MjaiEvent> events, int n, String kind, _Table table,
      Map<String, Object?> reply, String diff) {
    if (log == null) return;
    final a = events[n];
    final trace = _traces[n];
    final reaction = reply['reaction'] as Map<String, Object?>?;
    final riichiStep = reply['riichi_discard'] as Map<String, Object?>?;
    final gTile = switch (a['type']) {
      'dahai' => '${a['pai']}',
      'reach' => '${events[n + 1]['pai']}',
      _ => null,
    };
    final mTile = _mortalTile(reply);

    // The guide's lines worth showing: its top three, its pick and Mortal's.
    Object? guideTrace = trace;
    if (kind == 'turn' && trace != null) {
      final lines = (trace['lines'] as List).cast<Map<String, Object?>>();
      final keep = <Map<String, Object?>>[
        ...lines.take(3),
        for (final l in lines.skip(3))
          if (_bare('${l['d']}') == _bare(gTile ?? '') ||
              _bare('${l['d']}') == _bare(mTile ?? ''))
            l,
      ];
      guideTrace = {...trace, 'lines': keep, 'lineCount': lines.length};
    }

    final q = _discardQ(riichiStep ?? reaction ?? const {});
    final gap = gTile != null && q.containsKey(_bare(gTile))
        ? q.values.fold<double>(-1e9, max) - q[_bare(gTile)]!
        : null;
    log!.writeStringSync('${jsonEncode({
          'seed': seed,
          'kind': kind,
          'diff': diff,
          'n': n,
          'state': table.snapshot(),
          'mortal': {
            'type': reaction?['type'],
            'pai': reaction?['pai'],
            'consumed': reaction?['consumed'],
            'riichiPai': riichiStep?['pai'],
            'q': _decodeQ(reaction),
            'qRiichi': _decodeQ(riichiStep),
          },
          'guide': {
            'type': a['type'],
            'pai': a['pai'] ?? gTile,
            'consumed': a['consumed'],
            'trace': guideTrace,
          },
          'gap': gap == null ? null : _round(gap, 4),
        })}\n');
  }
}

String _bare(String tile) => tile.replaceFirst('r', '');

/// The tile Mortal discards in [reply] (the riichi discard, for a riichi).
String? _mortalTile(Map<String, Object?> reply) {
  final reaction = reply['reaction'] as Map<String, Object?>?;
  final step = reaction?['type'] == 'reach'
      ? reply['riichi_discard'] as Map<String, Object?>?
      : reaction;
  return step?['type'] == 'dahai' ? '${step!['pai']}' : null;
}

double _round(num x, [int digits = 1]) =>
    x.isFinite ? double.parse(x.toStringAsFixed(digits)) : 0;

/// Mortal's actions in index order: the discards, then the rest.
final _actionNames = [
  ..._discardNames,
  'reach', 'chi_low', 'chi_mid', 'chi_high', 'pon', 'kan', 'hora', 'ryukyoku',
  'pass', //
];

/// Mortal's q-value for every legal action in [step], by name.
Map<String, double> _decodeQ(Map<String, Object?>? step) {
  final meta = step?['meta'] as Map<String, Object?>?;
  if (meta == null) return {};
  final q = (meta['q_values'] as List).cast<num>();
  final bits = meta['mask_bits'] as int;
  final out = <String, double>{};
  var k = 0;
  for (var i = 0; i < _actionNames.length && k < q.length; i++) {
    if (bits >> i & 1 == 0) continue;
    out[_actionNames[i]] = _round(q[k++], 3);
  }
  return out;
}

/// The guide's EV lines for a turn, as it saw them when it decided.
Map<String, Object?> _turnJson(EfficiencyReport r, BotTurn move) => {
      'shanten': r.currentShanten,
      'tenpai': r.tenpai,
      'recommendRiichi': r.recommendRiichi,
      'defending': r.defending,
      'chosen': move.discard == null ? null : mjaiTile(move.discard!),
      'lines': [
        for (final l in r.lines)
          {
            'd': mjaiTile(Tile(-1, l.discard)),
            'shanten': l.shanten,
            'ukeire': l.ukeire,
            'ev': _round(l.expectedValue),
            'placementEv': _round(l.placementExpectedValue),
            'avgPoints': _round(l.averagePoints, 0),
            'winProb': _round(l.winProbability, 4),
            'dealInCost': _round(l.dealInCost),
            'commitCost': _round(l.commitmentCost),
            'riichiLock': _round(l.riichiLockCost),
            'tilt': _round(l.valueTilt),
            'bonus': _round(l.winBonus),
            'plan': l.valuePlan,
            'riichi': l.recommendRiichi,
            'recommended': l.recommended,
            'safety': l.safety?.rating,
            'why': l.reason,
          },
      ]..sort((a, b) => (b['ev'] as double).compareTo(a['ev'] as double)),
    };

/// The guide's verdict on a call: each option's EV and reason.
Map<String, Object?> _callJson(CallAdvice? advice) => advice == null
    ? {}
    : {
        'recommended': advice.recommended.name,
        'options': [
          for (final o in advice.options)
            {
              'action': o.action.name,
              'ev': _round(o.expectedValue),
              'shantenAfter': o.shantenAfter,
              'eligible': o.eligible,
              'discardAfter':
                  o.discardAfter == null ? null : mjaiTile(Tile(-1, o.discardAfter!)),
              'why': o.reason,
            },
        ],
      };

/// Seat 0's view of a hand, built up from its mjai events.
class _Table {
  var _bakaze = '', _kyoku = 0, _honba = 0, _kyotaku = 0, _oya = 0;
  var _scores = <int>[];
  final _dora = <String>[];
  final _hand = <String>[];
  String? _drawn;
  final _discards = List.generate(4, (_) => <String>[]);
  final _riichiAt = List.filled(4, -1);
  final _melds = List.generate(4, (_) => <Map<String, Object?>>[]);
  var _own = 0, _draws = 0;

  void apply(MjaiEvent e) {
    final actor = e['actor'] as int?;
    switch (e['type']) {
      case 'start_kyoku':
        _bakaze = '${e['bakaze']}';
        _kyoku = e['kyoku'] as int;
        _honba = e['honba'] as int;
        _kyotaku = e['kyotaku'] as int;
        _oya = e['oya'] as int;
        _scores = (e['scores'] as List).cast<int>().toList();
        _dora.add('${e['dora_marker']}');
        _hand.addAll(((e['tehais'] as List)[kHumanSeat] as List).cast<String>());
      case 'dora':
        _dora.add('${e['dora_marker']}');
      case 'tsumo':
        _draws++;
        if (actor == kHumanSeat) {
          _drawn = '${e['pai']}';
          _hand.add(_drawn!);
        }
      case 'dahai':
        if (actor == kHumanSeat) {
          _hand.remove('${e['pai']}');
          _own++;
          _drawn = null;
        }
        _discards[actor!].add('${e['pai']}');
      case 'reach':
        _riichiAt[actor!] = _discards[actor].length;
      case 'reach_accepted':
        _scores[actor!] -= 1000;
        _kyotaku++;
      case 'chi' || 'pon' || 'daiminkan':
        final consumed = (e['consumed'] as List).cast<String>();
        if (actor == kHumanSeat) consumed.forEach(_hand.remove);
        final from = _discards[e['target'] as int];
        if (from.isNotEmpty) from.last = '${from.last}^'; // taken by a call
        _melds[actor!].add({'t': e['type'], 'tiles': [...consumed, '${e['pai']}']});
      case 'ankan':
        final consumed = (e['consumed'] as List).cast<String>();
        if (actor == kHumanSeat) consumed.forEach(_hand.remove);
        _melds[actor!].add({'t': 'ankan', 'tiles': consumed});
      case 'kakan':
        if (actor == kHumanSeat) _hand.remove('${e['pai']}');
        final pon = _melds[actor!].lastWhere(
            (m) => m['t'] == 'pon' && _bare('${(m['tiles'] as List).last}') == _bare('${e['pai']}'),
            orElse: () => <String, Object?>{});
        if (pon.isNotEmpty) {
          pon['t'] = 'kakan';
          (pon['tiles'] as List).add('${e['pai']}');
        }
    }
  }

  Map<String, Object?> snapshot() => {
        'bakaze': _bakaze,
        'kyoku': _kyoku,
        'honba': _honba,
        'kyotaku': _kyotaku,
        'oya': _oya,
        'scores': _scores,
        'dora': _dora,
        'hand': ([..._hand]..sort((a, b) => _tileKey(a).compareTo(_tileKey(b)))),
        'drawn': _drawn,
        'melds': _melds,
        'discards': _discards,
        'riichiAt': _riichiAt,
        'junme': _own,
        'draws': _draws,
      };
}

/// Sort order for mjai tiles: manzu, pinzu, souzu, then honors.
int _tileKey(String t) {
  const honors = 'ESWNPFC';
  if (honors.contains(t[0])) return 100 + honors.indexOf(t[0]);
  return 'mps'.indexOf(t[1]) * 10 + int.parse(t[0]);
}

/// Mortal's discard indices 0-36 (see mortal_advisor.dart).
final _discardNames = [
  for (final suit in ['m', 'p', 's'])
    for (var n = 1; n <= 9; n++) '$n$suit',
  'E', 'S', 'W', 'N', 'P', 'F', 'C', '5mr', '5pr', '5sr', //
];

/// Mortal's q-value for each legal discard, the better of a five and its red.
Map<String, double> _discardQ(Map<String, Object?> step) {
  final meta = step['meta'] as Map<String, Object?>?;
  if (meta == null) return {};
  final q = (meta['q_values'] as List).cast<num>();
  final bits = meta['mask_bits'] as int;
  final best = <String, double>{};
  var k = 0;
  for (var i = 0; i < 46 && k < q.length; i++) {
    if (bits >> i & 1 == 0) continue;
    final value = q[k++].toDouble();
    if (i >= _discardNames.length) continue;
    final name = _bare(_discardNames[i]);
    if (value > (best[name] ?? -1e9)) best[name] = value;
  }
  return best;
}

// --- playing games ----------------------------------------------------------

/// Plays [games] seeds for the arm called [arm]: `guide`, `control`, or the
/// [MortalPart]s Mortal takes over, joined with `+`. [index] marks its rows.
Future<List<List<num>>> _runArm(int base, int games, int shards, int port,
    bool east, String arm, int index, String? pos) async {
  final parts = await Future.wait([
    for (var s = 0; s < shards; s++)
      Isolate.run(() =>
          _shard(base, games, s, shards, port + s, east, arm, index, pos)),
  ]);
  return [for (final p in parts) ...p]..sort((a, b) => a[0].compareTo(b[0]));
}

List<List<num>> _shard(int base, int games, int shard, int shards, int port,
    bool east, String arm, int index, String? pos) {
  Sfx.i.enabled = false;
  final log = pos != null && arm == 'guide'
      ? File('$pos.$shard.jsonl').openSync(mode: FileMode.write)
      : null;
  try {
    return [
      for (var g = shard; g < games; g += shards)
        _playGame(base + g, port, east, arm, index, log),
    ];
  } finally {
    log?.closeSync();
  }
}

List<num> _playGame(int seed, int port, bool east, String arm, int index,
    RandomAccessFile? log) {
  final guide = arm == 'guide';
  late List<num> row;
  final oldDebugPrint = debugPrint;
  var fallbacks = 0;
  // The controller reports a Mortal move it could not use only here.
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && message.contains('fell back')) fallbacks++;
  };
  final sw = Stopwatch()..start();
  fakeAsync((fa) {
    final mortal =
        _SyncMortal(port, trackAgreement: guide, seed: seed, log: log);
    final game = GameController(
      seed: seed,
      hanchan: !east,
      // Rotated with the seed, so no seat keeps the first deal's edge.
      startingDealer: seed % 4,
      seatCharacters: Platform.environment['MORTAL_OPP'] == 'simple'
          ? const [
              Character.orderic,
              Character.hubert,
              Character.astaroth,
              Character.hubert,
            ]
          : const [
              Character.orderic,
              Character.saeko,
              Character.saeko,
              Character.saeko,
            ],
      mortal: mortal,
    );
    game.setAutoplay(true);
    if (arm == 'control') {
      game.setAutoplayBrain(AutoplayBrain.mortal);
    } else if (guide) {
      game
        ..traceGuideTurn = mortal.traceTurn
        ..traceGuideCall = mortal.traceCall;
    } else {
      game.mortalParts = {
        for (final name in arm.split('+')) MortalPart.values.byName(name),
      };
    }

    final r = List<num>.filled(_rowLength, 0);
    var hands = 0;
    void add(String name, int seat, num x) => r[_seatCol(name, seat)] += x;
    for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
      if (guard > 100000) throw StateError('seed $seed never finished');
      if (game.phase == GamePhase.roundEnd) {
        final res = game.round.result!;
        hands++;
        if (res.kind == RoundEndKind.exhaustiveDraw) r[_singleCol('draws')]++;
        for (var s = 0; s < 4; s++) {
          final d = res.pointDeltas[s] ?? 0;
          if (res.winners.contains(s)) {
            add('win', s, 1);
            add('winGain', s, d);
            if (res.kind == RoundEndKind.tsumo) add('tsumo', s, 1);
          } else if (res.kind == RoundEndKind.ron && res.loser == s) {
            add('dealin', s, 1);
            add('lossRon', s, d);
          } else if (res.kind == RoundEndKind.tsumo) {
            add('lossTsumo', s, d);
          } else {
            add('other', s, d);
          }
          final seat = game.round.seats[s];
          if (seat.riichi) add('riichi', s, 1);
          if (seat.melds.any((m) => !m.concealed)) add('called', s, 1);
        }
        game.continueFromRoundEnd();
        continue;
      }
      fa.elapse(const Duration(milliseconds: 1104));
    }
    r[0] = seed;
    r[1] = index;
    r[2] = hands;
    for (var s = 0; s < 4; s++) {
      r[_seatCol('pts', s)] = game.tablePoints[s];
    }
    r[_singleCol('fallbacks')] = fallbacks;
    r[_singleCol('asks')] = mortal.asks;
    r[_singleCol('ms')] = sw.elapsedMilliseconds;
    for (var i = 0; i < _agreeNames.length; i++) {
      r[_agreeStart + i] = mortal.agree[i];
    }
    row = r;
    game.dispose();
  });
  debugPrint = oldDebugPrint;
  return row;
}

// --- statistics -------------------------------------------------------------

/// Placement with ties split (two seats tied for 1st both get 1.5).
double _place(List<num> row, int seat) {
  final mine = row[_seatCol('pts', seat)];
  var p = 1.0;
  for (var i = 0; i < 4; i++) {
    if (i == seat) continue;
    final o = row[_seatCol('pts', i)];
    if (o > mine) p += 1;
    if (o == mine) p += 0.5;
  }
  return p;
}

double _mean(List<num> xs) => xs.fold<double>(0, (a, b) => a + b) / xs.length;

({double mean, double se}) _meanSe(List<num> xs) {
  final m = _mean(xs);
  final v =
      xs.fold<double>(0, (a, b) => a + (b - m) * (b - m)) / (xs.length - 1);
  return (mean: m, se: sqrt(v / xs.length));
}

/// Complementary error function (Numerical Recipes erfcc, |err| < 1.2e-7).
double _erfc(double x) {
  final z = x.abs();
  final t = 1 / (1 + 0.5 * z);
  final r = t *
      exp(-z * z -
          1.26551223 +
          t *
              (1.00002368 +
                  t *
                      (0.37409196 +
                          t *
                              (0.09678418 +
                                  t *
                                      (-0.18628806 +
                                          t *
                                              (0.27886807 +
                                                  t *
                                                      (-1.13520398 +
                                                          t *
                                                              (1.48851587 +
                                                                  t *
                                                                      (-0.82215223 +
                                                                          t * 0.17087277)))))))));
  return x >= 0 ? r : 2 - r;
}

/// Two-sided p-value for a z statistic (n is in the hundreds or more, so the
/// t distribution is indistinguishable from normal).
double _p(double z) => _erfc(z.abs() / sqrt2);

String _f(double x, [int d = 3]) => x.toStringAsFixed(d);
String _pf(double p) => p < 1e-6 ? '<1e-6' : p.toStringAsExponential(2);

String _test(String label, List<num> xs, double h0) {
  final s = _meanSe(xs);
  final z = (s.mean - h0) / s.se;
  return '  $label: ${_f(s.mean)} ± ${_f(1.96 * s.se)} (95% CI)'
      '  vs $h0 → z=${_f(z, 2)}, p=${_pf(_p(z))}';
}

void _seatTable(String name, List<List<num>> rows) {
  final hands = rows.fold<num>(0, (a, r) => a + r[2]);
  num sum(String col, int s) =>
      rows.fold<num>(0, (a, r) => a + r[_seatCol(col, s)]);
  final draws = rows.fold<num>(0, (a, r) => a + r[_singleCol('draws')]);
  print('\n[$name] ${rows.length} games, $hands hands, '
      '${_f(draws / hands)} exhaustive draws/hand');
  print('  seat   place  1st%  4th%   win/h  tsumo%  dealin/h  riichi/h  '
      'call/h   win avg  ron loss avg   pts/hand');
  for (var s = 0; s < 4; s++) {
    final places = [for (final r in rows) _place(r, s)];
    final w = sum('win', s), d = sum('dealin', s);
    print('  ${s == 0 ? 'you ' : 'bot$s'}'
        '  ${_f(_mean(places), 3).padLeft(6)}'
        '  ${_f(100 * places.where((p) => p == 1).length / rows.length, 1).padLeft(4)}'
        '  ${_f(100 * places.where((p) => p == 4).length / rows.length, 1).padLeft(4)}'
        '  ${_f(w / hands).padLeft(6)}'
        '  ${_f(w == 0 ? 0 : 100 * sum('tsumo', s) / w, 0).padLeft(6)}'
        '  ${_f(d / hands).padLeft(8)}'
        '  ${_f(sum('riichi', s) / hands).padLeft(8)}'
        '  ${_f(sum('called', s) / hands).padLeft(6)}'
        '  ${_f(w == 0 ? 0 : sum('winGain', s) / w, 0).padLeft(8)}'
        '  ${_f(d == 0 ? 0 : sum('lossRon', s) / d, 0).padLeft(12)}'
        '  ${_f((sum('pts', s) / rows.length - 25000) / (hands / rows.length), 0).padLeft(9)}');
  }
}

/// Seat 0's per-game differences between [a] and [b], paired by seed.
void _diffTable(List<List<num>> a, List<List<num>> b) {
  for (final (label, col) in [
    ('hands won      ', 'win'),
    ('won by tsumo   ', 'tsumo'),
    ('rons dealt in  ', 'dealin'),
    ('riichi hands   ', 'riichi'),
    ('hands with call', 'called'),
    ('points won     ', 'winGain'),
    ('lost to rons   ', 'lossRon'),
    ('lost to tsumo  ', 'lossTsumo'),
    ('other (draws, sticks)', 'other'),
  ]) {
    final diff = [
      for (var i = 0; i < a.length; i++)
        a[i][_seatCol(col, 0)] - b[i][_seatCol(col, 0)],
    ];
    final m = _meanSe(diff);
    final z = m.se == 0 ? 0.0 : m.mean / m.se;
    final digits = const {'win', 'tsumo', 'dealin', 'riichi', 'called'}
            .contains(col)
        ? 3
        : 0;
    print('  $label ${_f(m.mean, digits).padLeft(8)}'
        ' ± ${_f(1.96 * m.se, digits)}   p=${_pf(_p(z))}');
  }
}

void _report(List<String> names, List<List<List<num>>> arms) {
  final guide = arms[0], control = arms[1];
  final badSeeds = {
    for (final arm in arms)
      for (final r in arm)
        if (r[_singleCol('fallbacks')] > 0) r[0],
  };
  print('\nInvalid games (a Mortal request failed, so SimpleBot or the guide '
      'played that move): ${badSeeds.length} of ${guide.length} seeds');

  // Pair by seed, dropping a seed if either arm was invalid.
  bool ok(List<num> r) => !badSeeds.contains(r[0]);
  final g = guide.where(ok).toList(), c = control.where(ok).toList();
  if (g.length < 2) {
    print('Too few valid games to report.');
    return;
  }

  for (final (name, rows) in [('guide', g), ('control (Mortal)', c)]) {
    final secs = _mean([for (final r in rows) r[_singleCol('ms')]]) / 1000;
    final asks = _mean([for (final r in rows) r[_singleCol('asks')]]);
    print('\n[$name at seat 0] ${rows.length} games, '
        '${_f(secs, 1)}s and ${_f(asks, 0)} Mortal requests per game');
    print(_test('avg placement', [for (final r in rows) _place(r, 0)], 2.5));
  }

  print('\nPaired guide − control (same seeds, same deal order):');
  final d = [
    for (var i = 0; i < g.length; i++) _place(g[i], 0) - _place(c[i], 0),
  ];
  print(_test('Δ avg placement', d, 0));
  final s = _meanSe(d);
  print('  (negative = guide places better; per-game SD ${_f(s.se * sqrt(d.length))}, '
      '${_f(pow(2.8 * s.se * sqrt(d.length) / 0.05, 2).toDouble(), 0)} '
      'paired games detect a 0.05 edge at 80% power)');

  _seatTable('GUIDE arm', g);
  _seatTable('CONTROL arm (Mortal in seat 0)', c);

  print('\nWhere the guide differs from Mortal in seat 0, per game '
      '(paired, positive = guide has more):');
  _diffTable(g, c);

  // --- which decisions carry the gap: the guide with some of them Mortal's ---
  final gap = _mean([for (var i = 0; i < g.length; i++) _place(g[i], 0) - _place(c[i], 0)]);
  for (var k = 2; k < arms.length; k++) {
    final h = arms[k].where(ok).toList();
    final vsGuide = [
      for (var i = 0; i < g.length; i++) _place(h[i], 0) - _place(g[i], 0),
    ];
    final vsControl = [
      for (var i = 0; i < g.length; i++) _place(h[i], 0) - _place(c[i], 0),
    ];
    final asks = _mean([for (final r in h) r[_singleCol('asks')]]);
    print('\n[guide with Mortal\'s ${names[k].replaceAll('+', ' + ')}] '
        '${h.length} games, ${_f(_mean([for (final r in h) _place(r, 0)]))} '
        'avg placement, ${_f(asks, 0)} Mortal requests per game');
    print(_test('Δ vs guide (negative = better)', vsGuide, 0));
    print(_test('Δ vs Mortal control', vsControl, 0));
    final closed = -_mean(vsGuide) / gap;
    print('  closes ${_f(100 * closed, 0)}% of the ${_f(gap)} gap '
        '(a share of a noisy estimate: see the CIs)');
    print('  per game vs the guide (positive = this arm has more):');
    _diffTable(h, g);
  }

  // --- the guide's decisions against Mortal's, in the guide arm ---
  num tot(String name) => g.fold<num>(0, (a, r) => a + r[_agree(name)]);
  print('\nGuide vs. what Mortal would do from the same position '
      '(${g.length} guide games):');
  for (final ctx in ['calm', 'threat']) {
    final n = tot('${ctx}_dis');
    if (n == 0) continue;
    final ranked = tot('${ctx}_ranked');
    String pct(num x, num of) => '${_f(100 * x / of, 1)}%';
    print('  discards, ${ctx == 'calm' ? 'no one else in riichi' : 'another seat in riichi'}: '
        '$n decisions, guide = Mortal\'s tile ${pct(tot('${ctx}_same'), n)}');
    print('    Mortal\'s rank of the guide\'s tile: '
        '1st ${pct(tot('${ctx}_rank1'), ranked)}, '
        '2nd ${pct(tot('${ctx}_rank2'), ranked)}, '
        '3rd ${pct(tot('${ctx}_rank3'), ranked)}, '
        '4th+ ${pct(tot('${ctx}_rank4plus'), ranked)}; '
        'mean q-gap ${_f(tot('${ctx}_qgap') / ranked, 4)} '
        '(${_f(tot('${ctx}_qgap') / g.length, 3)} per game)');
  }
  print('  riichi: both ${tot('reachBoth')}, Mortal only ${tot('reachMortalOnly')}, '
      'guide only ${tot('reachGuideOnly')}');
  print('  kan:    both ${tot('kanBoth')}, Mortal only ${tot('kanMortalOnly')}, '
      'guide only ${tot('kanGuideOnly')}');
  print('  calls offered to you (rows: Mortal\'s answer; columns: the guide\'s):');
  print('            ${_callNames.take(4).map((n) => n.padLeft(6)).join(' ')}');
  for (final m in _callNames) {
    print('    ${m.padRight(6)}  '
        '${_callNames.take(4).map((n) => '${tot('call_${m}_$n')}'.padLeft(6)).join(' ')}');
  }
}

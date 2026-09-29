/// Asks the Mortal sidecar (mortal_sidecar/server.py) what Mortal would do in
/// one seat, seeing only what that seat can see: for your seat, the guide
/// panel's Mortal column ([MortalAdvice]); for the Saeko bot, her moves
/// ([MortalMove]).
///
/// Off unless the app is built with `--dart-define=MORTAL_URL=<address>`
/// (`/tilesense/mortal` in production); then only offline riichi games, and
/// the scenario builder's riichi tables, ask.
library;

import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:mahjong_core/bot.dart';
import 'package:mahjong_core/mjai.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';

/// The Mortal sidecar's address, fixed at build time. Empty (the default)
/// hides the column.
const String kMortalUrl = String.fromEnvironment('MORTAL_URL');

/// Mortal's discard indices 0-36, in its own action order.
final _discardNames = [
  for (final suit in ['m', 'p', 's'])
    for (var n = 1; n <= 9; n++) '$n$suit',
  'E', 'S', 'W', 'N', 'P', 'F', 'C', '5mr', '5pr', '5sr', //
];

enum MortalStatus { idle, thinking, failed, ready }

/// What Mortal would do right now in your seat.
class MortalAdvice {
  const MortalAdvice._(this.status,
      {this.action, this.discard, this.riichi = false, this.ranks = const {}});

  /// Nothing to ask: not your turn and no call to answer.
  static const idle = MortalAdvice._(MortalStatus.idle);
  static const thinking = MortalAdvice._(MortalStatus.thinking);
  static const failed = MortalAdvice._(MortalStatus.failed);

  final MortalStatus status;

  /// A move other than a plain discard, in the panel's words: TSUMO, RON,
  /// PON, CHI 345m, KAN, PASS, NINE TERMINALS. Null for a plain discard.
  final String? action;

  /// The tile Mortal would cut (after declaring riichi, if [riichi]).
  final String? discard;
  final bool riichi;

  /// Mortal's order of preference over the legal discards, 1 = its pick,
  /// keyed by mjai tile name without the red marker.
  final Map<String, int> ranks;

  int? rankOf(TileType type) => ranks[mjaiTile(Tile(-1, type))];

  /// Reads the sidecar's reply; see server.py.
  factory MortalAdvice.fromReply(Map<String, Object?> body,
      {required bool call}) {
    final reaction = body['reaction'] as Map<String, Object?>?;
    final riichiDiscard = body['riichi_discard'] as Map<String, Object?>?;
    final type = reaction?['type'];
    final discardStep = type == 'reach' ? riichiDiscard : reaction;
    final action = switch (type) {
      'dahai' || 'reach' => null,
      'hora' => call ? 'RON' : 'TSUMO',
      'pon' => 'PON',
      'chi' => 'CHI ${_run(reaction!)}',
      'daiminkan' || 'ankan' || 'kakan' => 'KAN',
      'ryukyoku' => 'NINE TERMINALS',
      _ => call ? 'PASS' : null,
    };
    return MortalAdvice._(MortalStatus.ready,
        action: action,
        discard: discardStep?['type'] == 'dahai'
            ? '${discardStep!['pai']}'.replaceFirst('r', '')
            : null,
        riichi: type == 'reach',
        ranks: _ranks(discardStep));
  }

  static String _run(Map<String, Object?> chi) {
    final tiles = [chi['pai'], ...chi['consumed'] as List]
        .map((t) => '$t'.replaceFirst('r', ''))
        .toList()
      ..sort();
    return '${tiles.map((t) => t[0]).join()}${tiles.first[1]}';
  }

  /// Ranks the legal discards by Mortal's q-values, which line up with the
  /// set bits of `mask_bits` in action order. Red and plain fives share a
  /// rank: the better of the two.
  static Map<String, int> _ranks(Map<String, Object?>? reaction) {
    final meta = reaction?['meta'] as Map<String, Object?>?;
    if (meta == null) return const {};
    final q = (meta['q_values'] as List).cast<num>();
    // Divided rather than shifted: on the web, bit shifts stop at 32 bits
    // and the mask has 46.
    var bits = meta['mask_bits'] as int;
    final best = <String, num>{};
    var k = 0;
    for (var i = 0; bits > 0 && k < q.length; i++, bits ~/= 2) {
      if (bits % 2 == 0) continue;
      final value = q[k++];
      if (i >= _discardNames.length) continue;
      final name = _discardNames[i].replaceFirst('r', '');
      if (value > (best[name] ?? double.negativeInfinity)) best[name] = value;
    }
    final order = best.keys.toList()
      ..sort((a, b) => best[b]!.compareTo(best[a]!));
    return {for (var i = 0; i < order.length; i++) order[i]: i + 1};
  }
}

class MortalAdvisor {
  MortalAdvisor(String url) : _url = Uri.base.resolve('$url/react');
  final Uri _url;

  /// Mortal's reply for [seat]. [events] is the hand with nothing hidden
  /// ([MjaiRecorder]); only [seat]'s own view of it ([mjaiView]) is sent.
  Future<Map<String, Object?>> ask(int seat, List<MjaiEvent> events) async {
    final res = await http
        .post(_url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(
                {'player_id': seat, 'events': mjaiView(events, seat)}))
        .timeout(const Duration(seconds: 3));
    final body = jsonDecode(res.body) as Map<String, Object?>;
    if (res.statusCode != 200) throw StateError('Mortal: ${body['error']}');
    return body;
  }

  /// Mortal's advice for your seat, for the guide panel.
  Future<MortalAdvice> advise(List<MjaiEvent> events,
          {required bool call}) async =>
      MortalAdvice.fromReply(await ask(0, events), call: call);
}

/// A reply from [MortalAdvisor.ask] as a move the table can play. Each
/// throws a [StateError] when Mortal names a move this table doesn't offer;
/// the caller then falls back to another player (SimpleBot, for Saeko).
abstract final class MortalMove {
  /// [seat]'s turn: discard (after riichi, if Mortal declares it), tsumo,
  /// closed or added kan, or nine terminals.
  static BotTurn turn(Map<String, Object?> reply, Round round, int seat) {
    var reaction = reply['reaction'] as Map<String, Object?>?;
    final riichi = reaction?['type'] == 'reach';
    if (riichi) {
      if (!round.canRiichi(seat)) throw _unplayable(reaction);
      // The sidecar asks for the discard that goes with the riichi.
      reaction = reply['riichi_discard'] as Map<String, Object?>?;
    }
    switch (reaction?['type']) {
      case 'dahai':
        final pai = reaction!['pai'];
        final drawn = round.seats[seat].drawn;
        final matches =
            round.legalDiscards(seat).where((t) => mjaiTile(t) == pai);
        // Cut the drawn tile itself when Mortal does, so the table shows it.
        final tile = reaction['tsumogiri'] == true && matches.contains(drawn)
            ? drawn
            : matches.firstOrNull;
        if (tile != null) return BotTurn(discard: tile, riichi: riichi);
      case 'hora' when round.canTsumo(seat):
        return BotTurn(tsumo: true);
      case 'ankan':
        final type = _kanType(
            round.closedKanTypes(seat), (reaction!['consumed'] as List).first);
        if (type != null) return BotTurn(closedKan: type);
      case 'kakan':
        final type = _kanType(round.addedKanTypes(seat), reaction!['pai']);
        if (type != null) return BotTurn(addedKan: type);
      case 'ryukyoku' when round.canDeclareKyuushu(seat):
        return BotTurn(kyuushu: true);
    }
    throw _unplayable(reaction);
  }

  /// Whether [seat] takes the pending discard, out of the calls [offered];
  /// a chi names its run by the run's lowest tile ([Round.resolveCalls]).
  static ({CallType call, TileType? chiLow}) call(Map<String, Object?> reply,
      Round round, int seat, Set<CallType> offered) {
    final reaction = reply['reaction'] as Map<String, Object?>?;
    final call = switch (reaction?['type']) {
      null || 'none' => CallType.none,
      'hora' => CallType.ron,
      'pon' => CallType.pon,
      'daiminkan' => CallType.kan,
      'chi' => CallType.chi,
      _ => null,
    };
    if (call == null || (call != CallType.none && !offered.contains(call))) {
      throw _unplayable(reaction);
    }
    if (call != CallType.chi) return (call: call, chiLow: null);
    final low = [reaction!['pai'], ...reaction['consumed'] as List]
        .map((t) => int.parse('$t'[0]))
        .reduce(min);
    final run = round
        .chiSequences(seat, round.pendingDiscard!)
        .where((t) => t.number == low)
        .firstOrNull;
    if (run == null) throw _unplayable(reaction);
    return (call: CallType.chi, chiLow: run);
  }

  /// The kan in [legal] that Mortal's tile [pai] names (red or not).
  static TileType? _kanType(List<TileType> legal, Object? pai) => legal
      .where((t) => mjaiTile(Tile(-1, t)) == '$pai'.replaceFirst('r', ''))
      .firstOrNull;

  static StateError _unplayable(Object? reaction) =>
      StateError('Mortal reply not playable here: $reaction');
}

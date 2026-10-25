/// English rules text: the reference wording the other languages follow.
library;

import 'package:mahjong_core/ruleset.dart';

import 'rules_content.dart';
import 'rules_text.dart';

class EnRulesText extends RulesText {
  const EnRulesText();

  // Lines several variants share.
  static const _drawDiscard = 'Draw a tile, then discard one.';
  static const _hold13 = 'Hold 13 tiles between draws.';
  static const _winFirst = 'A winning claim beats any other.';
  static const _priority = 'A win beats kong or pung, which beat chow.';
  static const _lastDiscard = 'The last discard can only be claimed to win.';
  static const _multiWin = 'Several players may win on the same discard.';
  static const _hiddenKongs =
      'Concealed kongs stay face down until the hand ends.';
  static const _dealerStays =
      'The dealer stays after their own win or a draw; otherwise the deal moves on.';
  static const _listedBelow = 'Every pattern is listed below.';
  static const _openPdf = 'Open the PDF for the full reference.';

  @override
  List<RuleSection> riichi({required bool sanma}) => [
        RuleSection(
            'setup',
            'Tiles and the goal',
            sanma
                ? const [
                    'Three players, 108 tiles: the 2–8 characters are removed.',
                    'The seat across is empty.',
                    _hold13,
                    'Win with four sets and a pair.',
                    'Seven Pairs and Thirteen Orphans are special winning shapes.',
                    'Start with 35,000 points.',
                  ]
                : const [
                    'Four players, 136 tiles including red fives.',
                    _hold13,
                    'Win with four sets and a pair.',
                    'A set is three suited tiles in a row, or three identical tiles; a kan is four.',
                    'Seven Pairs and Thirteen Orphans are special winning shapes.',
                    'Start with 25,000 points.',
                  ]),
        RuleSection(
            'calls',
            'Draw, discard and call',
            sanma
                ? const [
                    _drawDiscard,
                    'Pon and kan are allowed; chi is not.',
                    'A kan draws a replacement from the dead wall.',
                    'Pon and open kan make the hand open, which changes the yaku it can score.',
                  ]
                : const [
                    _drawDiscard,
                    'Chi takes a sequence from the player before you; pon takes a triplet, kan a quad.',
                    _winFirst,
                    'A kan draws a replacement from the dead wall.',
                    'Chi, pon and open kan make the hand open, which changes the yaku it can score.',
                  ]),
        const RuleSection('winning', 'Winning: yaku and furiten', [
          'Tsumo wins on your own draw; ron wins on a discard.',
          'You need at least one yaku; dora alone are not enough.',
          'Furiten: if any of your waits is in your own discards, you cannot ron, but can still tsumo.',
          'Passing a ron also blocks ron for a while; after riichi, for the rest of the hand.',
        ]),
        const RuleSection('riichi', 'Riichi and dora', [
          'With a closed, ready hand and enough points, declare riichi and pay a 1,000-point deposit.',
          'The hand is then locked: discard each draw, except for permitted kans.',
          'Yaku and dora add han; fu reflect the hand’s shape.',
          'Dora indicators mark bonus tiles, and red fives add han too.',
          'A riichi win also reveals ura dora.',
        ]),
        if (sanma)
          const RuleSection('kita', 'Kita: setting North aside', [
            'On your turn, set a North aside for 1 bonus han and draw a replacement.',
            'Dora and ura indicators that point to North add more.',
            'After riichi, only a freshly drawn North can be set aside.',
            'Kita cancels ippatsu and first-turn bonuses.',
            'Opponents may ron the North; this is not robbing a kan.',
            'Kita and kans share eight replacement draws.',
            'A 1-character indicator makes 9-character dora, and vice versa.',
          ]),
        RuleSection(
            'payments',
            'Scores and payments',
            sanma
                ? const [
                    'Han and fu set the points; limit hands and yakuman go above the table.',
                    'On ron, the discarder pays.',
                    'On tsumo, the two opponents pay their four-player shares; nobody covers the empty seat (tsumo loss).',
                    'At an exhaustive draw, not-ready players pay ready players 2,000 points in total.',
                    'The only abortive draw is nine terminals.',
                  ]
                : const [
                    'Han and fu set the points; limit hands and yakuman go above the table.',
                    'On ron, the discarder pays; on tsumo, every opponent pays, with the dealer’s share larger.',
                    'Honba add to each payment, and the winner collects riichi deposits.',
                    'At an exhaustive draw, not-ready players pay ready players 3,000 points in total.',
                    'Rare fu cases and some double-yakuman rules are approximated.',
                  ]),
        RuleSection(
            'game',
            'Dealer and game length',
            sanma
                ? const [
                    'A full game is East and South, three hands each; East-only is three hands.',
                    'Dealer repeats can extend the game.',
                  ]
                : const [
                    'A full game (hanchan) is East and South, four hands each; East-only is four hands.',
                    'The dealer repeats after winning, or when ready at an exhaustive draw.',
                  ]),
        RuleSection('source', 'About this summary', [
          'A quick guide to TileSense’s rules; the lists above cover every yaku, fu rule and limit the scorer counts.',
          if (sanma)
            'Sanma follows the Japanese Mahjong Wiki’s Sanma reference.',
          'Open the external reference for more detail.',
        ]),
      ];

  @override
  List<RuleSection> hongKong(String minimum) => [
        const RuleSection('setup', 'Tiles and the goal', [
          'Four players, 144 tiles including eight flowers and seasons.',
          _hold13,
          'Win with four sets and a pair, Seven Pairs or Thirteen Orphans.',
          'Flowers are exposed and replaced from the wall’s tail, like kong replacements; there is no dead wall.',
        ]),
        const RuleSection('calls', 'Draw, discard and call', [
          _drawDiscard,
          'Chow takes a sequence only from the player before you; pung takes a triplet, kong a quad.',
          _priority,
          'Added kongs can be robbed; concealed kongs cannot.',
          _multiWin,
          _lastDiscard,
        ]),
        RuleSection('winning', 'Winning and the minimum', [
          minimum,
          'A hand below the minimum cannot win.',
          'At 0 faan, a chicken hand with no scoring features can win.',
          'Self-Pick adds faan, so a hand too small to win on a discard may win on a draw.',
          'There is no riichi or furiten.',
        ]),
        const RuleSection('scoring', 'Faan and flowers', [
          'Independent features add up; an upgraded feature replaces the lower one.',
          'Flowers and seasons can add bonuses.',
          'Exposing a seventh or eighth bonus tile offers an immediate flower win (3 or 8 faan) before the replacement draw.',
          _listedBelow,
        ]),
        const RuleSection('payments', 'Payments', [
          'Table points for 0–13 faan: 1, 2, 4, 8, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384; higher totals stay at 384.',
          'Discard win: the discarder alone pays each winner double.',
          'Self-pick: each opponent pays the table points.',
          'Draws pay nothing, and there is no dealer multiplier or repeat bonus.',
        ]),
        const RuleSection('game', 'Dealer and game length', [
          _dealerStays,
          'Play East and South (eight scheduled deals) or East-only (four); repeats extend play.',
          'Negative chip balances do not end the game.',
        ]),
        const RuleSection('source', 'About this summary', [
          'Based on danma’s Hong Kong Mahjong Rule Sheet v1.0, with New Style discarder-pays-all payments.',
          _openPdf,
        ]),
      ];

  @override
  List<RuleSection> taiwanese(String minimum) => [
        const RuleSection('setup', 'Tiles and the goal', [
          'Four players, 144 tiles including flowers and seasons.',
          'Hold 16 tiles between draws.',
          'Win with 17 tiles: five sets and a pair, or seven different pairs plus a pung.',
          'A kong counts as one set.',
          'Flowers are exposed and replaced automatically.',
        ]),
        const RuleSection('calls', 'Draw, discard and call', [
          _drawDiscard,
          'Chow takes a sequence from the player before you; pung and kong take matching tiles.',
          _winFirst,
          _hiddenKongs,
          'There is no riichi, dora or red-five bonus.',
          _lastDiscard,
        ]),
        RuleSection('winning', 'Winning and the minimum', [
          minimum,
          'The minimum is a TileSense house rule; a hand below it cannot win.',
          'Passing a winning discard blocks that wait until your next draw.',
          'Your own earlier discards do not cause riichi-style furiten.',
        ]),
        const RuleSection('scoring', 'Additive points and flowers', [
          'Patterns add flat tai (the source sheet’s points) instead of Hong Kong’s doubling table.',
          'Flower bonuses count toward the minimum.',
          'Eight flowers can make a special flower win.',
          _listedBelow,
        ]),
        const RuleSection('payments', 'Payments and dealer streak', [
          'Self-draw: each opponent pays the full value.',
          'Discard win: only the discarder pays.',
          'Dealer streak: +0, 2, 4 or 6 for zero, one, two or three-plus earlier consecutive dealer wins.',
          'The streak bonus applies when the dealer wins or deals in; a draw resets it.',
        ]),
        const RuleSection('game', 'Dealer and game length', [
          _dealerStays,
          'Play East and South, or a shorter East-only game; repeats extend play.',
        ]),
        const RuleSection('source', 'About this summary', [
          'Based on the San Diego Mahjong Club’s Taiwanese Mahjong pamphlet by Nathanael J. Reynolds, with TileSense’s configurable minimum.',
        ]),
      ];

  @override
  List<RuleSection> mcr() => const [
        RuleSection('setup', 'Tiles and the goal', [
          'Four players, 144 tiles including eight flowers.',
          _hold13,
          'Win with four sets and a pair, or a special shape such as Seven Pairs, Thirteen Orphans or a knitted hand.',
          'Four identical tiles may count as two pairs.',
          'Flowers are always exposed and replaced; there is no dead wall.',
        ]),
        RuleSection('calls', 'Draw, discard and call', [
          'Chow takes only from the player before you.',
          _priority,
          'You cannot kong on the turn you chow or pung.',
          _hiddenKongs,
          _lastDiscard,
          'If several players claim Hu on one discard, only the nearest after the discarder wins.',
        ]),
        RuleSection('winning', 'The 8-point minimum', [
          'A win needs 8 points before flowers; 7 plus flowers is not enough.',
          'A hand with nothing else scores Chicken Hand (8).',
          'There is no riichi, furiten or honba.',
        ]),
        RuleSection('scoring', '81 fan and exclusions', [
          'The scorer checks all 81 fan and their combination rules, and takes the highest legal total.',
          'Overlapping or implied fan are not always added together.',
          'Flowers add 1 point each, only once the minimum is met.',
          'Every fan, and the fan it excludes, is listed below.',
        ]),
        RuleSection('payments', 'Payments', [
          'Self-draw: each opponent pays F + 8, where F is the hand’s points with flowers.',
          'Discard win: the discarder pays F + 8 and the other two 8 each.',
          'Draws pay nothing; scores start at 0 and may go negative.',
        ]),
        RuleSection('game', 'Dealer and game length', [
          'The deal moves on after every hand, win or draw.',
          'A full game is 16 hands, four per wind; practice is four East hands.',
        ]),
        RuleSection('source', 'About this summary', [
          'Based on the World Mahjong Organization’s Mahjong Competition Rules.',
          'Tournament administration and referee penalties are not part of the game.',
          _openPdf,
        ]),
      ];

  @override
  List<RuleSection> sichuan() => const [
        RuleSection('setup', 'Tiles and the goal', [
          'Four players, 108 suited tiles: no honours or flowers.',
          _hold13,
          'Win with four sets and a pair, or Seven Pairs; four identical tiles may count as two pairs.',
          'There are no red fives or dead wall; kong replacements come from the wall’s tail.',
        ]),
        RuleSection('void', 'Choose a void suit', [
          'Before play, choose one suit to give up.',
          'Discard all of it before any other suit.',
          'You cannot win while you hold or have melded that suit.',
          'Opponents see your choice at your first discard.',
        ]),
        RuleSection('calls', 'Calls and continued play', [
          'Pung and kong are allowed; chow is not, though sequences in your hand are fine.',
          'A winner drops out and the rest play on.',
          _multiWin,
          'The hand ends when three players have won or the wall runs out.',
          _lastDiscard,
        ]),
        RuleSection('winning', 'Winning and passed wins', [
          'There is no minimum fan, riichi or honba.',
          'After passing a Hu, you cannot win on that tile from another player until your next turn, or on another discard unless it pays more.',
        ]),
        RuleSection('scoring', 'Fan and payments', [
          'Hand values: 1, 2, 4 and 8 points for 0, 1, 2 and 3+ fan.',
          'All Pungs and each root (four identical tiles) add 1 fan; Full Flush and Seven Pairs add 2; situational bonuses add more.',
          'Discard win: the discarder pays each winner the hand value.',
          'Self-draw: each opponent still in pays the hand value + 1.',
        ]),
        RuleSection('settlement', 'Kongs and wall-end settlement', [
          'Concealed kong: 2 from each active opponent.',
          'Claimed kong: 2 from the discarder.',
          'Added kong: 1 from each active opponent, and only with the tile just drawn.',
          'Kong payments are cancelled if the kong is robbed or followed by a winning discard.',
          'A player still in and not ready at wall end gets no kong payments.',
          'At wall end, each not-ready player pays each ready player their best waiting value.',
        ]),
        RuleSection('game', 'Dealer and game length', [
          'Scores start at 0; practice is four hands, a full game eight, with no round wind.',
          'The first winner deals next; if several win on that first discard, the discarder deals.',
          'If nobody wins, the dealer stays.',
        ]),
        RuleSection('source', 'About this summary', [
          'Based on the Sichuan Bloody Rules quick reference at mahjongpictureguide.com, with TileSense’s own settlement and turn-order choices where it is silent.',
          _openPdf,
        ]),
      ];

  @override
  String hongKongDefaultMinimum(int faan, List<int> choices) =>
      'Default minimum: $faan faan; choose ${choices.join(', ')} before play.';
  @override
  String hongKongTableMinimum(int faan) => 'This table’s minimum: $faan faan.';
  @override
  String taiwaneseDefaultMinimum(int tai, List<int> choices) =>
      'Default minimum: $tai tai; choose ${choices.join(', ')} before play.';
  @override
  String taiwaneseTableMinimum(int tai) => 'This table’s minimum: $tai tai.';

  @override
  String groupTitle(String id) => switch (id) {
        'yaku' => 'Every yaku',
        'yakuman' => 'Yakuman',
        'dora' => 'Dora and bonus han',
        'fu' => 'Fu',
        'limits' => 'Limit hands',
        'faan' => 'Every faan feature',
        'tai' => 'Every scoring pattern',
        'sichuanFan' => 'Every fan',
        _ => '${id.substring(3)}-fan patterns',
      };

  @override
  List<String> groupIntro(String id) => switch (id) {
        'yaku' => const [
            'A win needs at least one yaku; dora never count alone.',
            'Of two related yaku, the stronger replaces the weaker.',
          ],
        'yakuman' => const [
            'Each yakuman is 8,000 basic points, and they stack.',
            'Not implemented: Tenhou, Chiihou, Renhou, Suukantsu and nagashi mangan.',
          ],
        'dora' => const [
            'Bonus han count only with a yaku, and never add to yakuman.'
          ],
        'fu' => const ['Fu measure the hand’s shape: add them up, then round.'],
        'limits' => const [
            'Basic points are fu × 2^(han + 2), raised to these limits.',
            'Ron pays 4× basic, or 6× to the dealer.',
            'Tsumo: the dealer pays 2× and others 1×; a winning dealer gets 2× from everyone.',
            'Each payment rounds up to the next 100.',
          ],
        'faan' => const [
            'Independent features add together; totals above 13 faan are shown but paid at 13.'
          ],
        'tai' => const [
            'Points add together; in a tiered family only the strongest counts.',
            'Not implemented: the sheet’s Riichi (10) and Robbing the Flower (20).',
          ],
        'sichuanFan' => const [
            'Fan add together; 0, 1, 2 and 3+ fan pay 1, 2, 4 and 8 points.'
          ],
        'mcr88' => const [
            'All 81 fan from Appendix 1; the scorer takes the highest legal total.',
            'Fan named after “Not with” are implied and not added again.',
          ],
        _ => const [],
      };

  @override
  String get nameHeading => 'Pattern';
  @override
  String get valueHeading => 'Value';
  @override
  String get exampleHeading => 'Example';

  @override
  String value(ValueUnit unit, ScoringPattern p) {
    final each = p.each ? ' each' : '';
    return switch (unit) {
      ValueUnit.han when p.yakuman > 0 =>
        p.yakuman == 1 ? 'Yakuman' : 'Double yakuman',
      ValueUnit.han when p.closedOnly => '${p.value} han · closed only',
      ValueUnit.han when p.open != null => '${p.value} han · ${p.open} open',
      ValueUnit.han => '${p.value} han$each',
      ValueUnit.faan => '${p.value} faan$each',
      ValueUnit.tai => '${p.value} tai$each',
      ValueUnit.fan || ValueUnit.mcrFan => '${p.value} fan$each',
      ValueUnit.fu => p.value == 0 ? '' : '${p.value} fu',
      ValueUnit.basicPoints => '${groupDigits(p.value)} basic points',
    };
  }

  @override
  Map<String, String> get readerNames => const {
        'yakuhaiDragon': 'Dragon triplet',
        'hkDragonPung': 'Dragon pung',
        'hkSeatFlower': 'Seat flower or season',
        'fuBase': 'Base',
        'fuClosedRon': 'Closed ron',
        'fuTsumo': 'Self-draw',
        'fuPinfu': 'Pinfu',
        'fuChiitoitsu': 'Seven pairs',
        'fuOpenSimpleTriplet': 'Open triplet of simples',
        'fuClosedSimpleTriplet': 'Concealed triplet of simples',
        'fuOpenHonorTriplet': 'Open triplet of terminals or honours',
        'fuClosedHonorTriplet': 'Concealed triplet of terminals or honours',
        'fuKan': 'Kan',
        'fuValuePair': 'Value-tile pair',
        'fuWait': 'Closed, edge or single wait',
        'fuRounding': 'Rounding',
      };

  @override
  String mcrExcludes(List<String> names) => 'Not with: ${names.join(', ')}.';

  @override
  Map<String, String> notes(Ruleset ruleset) => switch (ruleset) {
        Ruleset.riichi || Ruleset.sanma => _riichi,
        Ruleset.hongKong => _hongKong,
        Ruleset.taiwanese => _taiwanese,
        Ruleset.mcr => _mcr,
        Ruleset.sichuan => _sichuan,
      };

  static const _riichi = {
    'Riichi':
        'Declare with a closed, ready hand and pay 1,000 points; the hand is then locked.',
    'Double Riichi':
        'Riichi on your first discard, before any call or kan. Replaces Riichi.',
    'Ippatsu':
        'Win within one go-around of declaring riichi, with no call or kan in between.',
    'Menzen Tsumo': 'Self-draw with a closed hand.',
    'Pinfu':
        'Four sequences, a pair that is not a value tile, and a two-sided wait.',
    'Iipeiko': 'Two identical sequences in one suit.',
    'Haitei Raoyue': 'Self-draw on the last tile of the live wall.',
    'Houtei Raoyui': 'Ron on the last discard.',
    'Rinshan Kaihou': 'Win on a replacement tile from the dead wall.',
    'Chankan': 'Ron on the tile another player adds to make an added kan.',
    'Tanyao': 'No terminals or honours anywhere. Open tanyao counts.',
    'yakuhaiDragon': 'A triplet or kan of any dragon.',
    'Round Wind': 'A triplet or kan of the round wind.',
    'Seat Wind':
        'A triplet or kan of your seat wind. A wind that is both earns 2.',
    'Sanshoku Doujun': 'The same sequence in all three suits.',
    'Ittsu': '1-2-3, 4-5-6 and 7-8-9 in one suit.',
    'Chanta':
        'Every set and the pair include a terminal or honour, with at least one sequence.',
    'Chiitoitsu':
        'Seven different pairs, always 25 fu. TileSense adds only dora to it: riichi, tsumo, tanyao and flushes are not counted.',
    'Toitoi': 'Four triplets or kans.',
    'Sanankou':
        'Three concealed triplets. One completed by ron counts as open.',
    'Sanshoku Doukou': 'Triplets of the same number in all three suits.',
    'Sankantsu': 'Three kans, open or closed.',
    'Honroutou':
        'Only terminals and honours, as four triplets and a pair, so Toitoi also scores.',
    'Shousangen':
        'Two dragon triplets and a dragon pair. Each dragon triplet also scores.',
    'Junchan':
        'Every set and the pair include a terminal, with no honours. Replaces Chanta.',
    'Honitsu': 'One suit plus honours.',
    'Ryanpeikou': 'Two pairs of identical sequences. Replaces Iipeiko.',
    'Chinitsu': 'Only one suit. Replaces Honitsu.',
    'Kokushi Musou':
        'One of each terminal and honour, plus a second of one of them.',
    'Suuankou': 'Four concealed triplets. A single wait is not doubled.',
    'Daisangen': 'Triplets of all three dragons.',
    'Shousuushii': 'Three wind triplets and a wind pair.',
    'Daisuushii': 'Triplets of all four winds.',
    'Tsuuiisou': 'Only honour tiles, seven pairs included.',
    'Chinroutou': 'Only 1s and 9s.',
    'Ryuuiisou':
        'Only 2, 3, 4, 6 and 8 sou and the green dragon; the dragon is optional.',
    'Chuuren Poutou':
        'Closed 1112345678999 plus one more tile of that suit. The nine-sided wait is not doubled.',
    'Dora': 'Each tile that follows a dora indicator in sequence.',
    'Ura Dora':
        'The same, for the indicators under the dora; counted only on a riichi win.',
    'Aka Dora': 'Each red five.',
    'Kita': 'Each North set aside. Indicators pointing to North add more.',
    'fuBase': 'Every hand starts here, except Pinfu and seven pairs.',
    'fuClosedRon': 'Winning on a discard with a closed hand.',
    'fuTsumo': 'Winning on your own draw; not added to Pinfu.',
    'fuPinfu': '30 fu on ron, 20 fu on tsumo.',
    'fuChiitoitsu': 'Fixed, and not rounded.',
    'fuOpenSimpleTriplet': 'A called triplet of 2–8.',
    'fuClosedSimpleTriplet':
        'A concealed triplet of 2–8. A triplet completed by ron counts as open.',
    'fuOpenHonorTriplet': 'A called triplet of 1s, 9s or honours.',
    'fuClosedHonorTriplet': 'A concealed triplet of 1s, 9s or honours.',
    'fuKan': 'Four times the matching triplet: 8, 16 or 32 fu.',
    'fuValuePair':
        'A dragon, round-wind or seat-wind pair; 4 if the wind is both.',
    'fuWait':
        'Not added when the winning tile could also complete a two-sided wait.',
    'fuRounding':
        'Round up to the next 10. An open ron with only the base fu stays at 20 (standard rules score 30).',
    'Mangan':
        '5 han, or fewer han with enough fu to reach 2,000 basic points. No rounding up to mangan.',
    'Haneman': '6–7 han.',
    'Baiman': '8–10 han.',
    'Sanbaiman': '11–12 han.',
    'Kazoe Yakuman': '13 han or more from ordinary yaku and dora.',
    'Yakuman': 'Per yakuman; several stack.',
  };

  static const _hongKong = {
    'Self-Pick': 'Winning on your own draw.',
    'Win by Kong Replacement':
        'Self-pick on a kong’s replacement tile. Replaces Self-Pick.',
    'Double Kong Replacement':
        'The first replacement tile makes another kong, and its replacement wins. Replaces the other self-pick awards.',
    'Concealed Hand':
        'No exposed calls; concealed kongs keep the hand concealed. Also scored on a discard win.',
    'Robbing the Kong': 'Winning on the tile added to an exposed pung.',
    'Moon Under the Sea': 'Winning on the last wall tile or the last discard.',
    'All Sequences': 'Four chows.',
    'All Triplets': 'Four pungs or kongs.',
    'All Concealed Triplets':
        'Four concealed pungs, by self-pick or a discard completing the pair. Replaces All Triplets.',
    'All Quadruplets': 'Four kongs. Replaces the triplet awards.',
    'hkDragonPung': 'A pung or kong of any dragon.',
    'Small Three Dragons':
        'Two dragon pungs and a dragon pair. Replaces the dragon pung awards.',
    'Big Three Dragons':
        'Pungs of all three dragons. Replaces the dragon pung awards.',
    'Seat Wind': 'A pung or kong of your seat wind.',
    'Round Wind':
        'A pung or kong of the round wind. A wind that is both earns 2.',
    'Small Four Winds':
        'Three wind pungs and a wind pair. Replaces the seat and round wind awards.',
    'Big Four Winds':
        'Pungs of all four winds. Replaces the seat and round wind awards.',
    'Mixed Flush': 'One suit plus honours.',
    'Full Flush': 'One suit only. Replaces Mixed Flush.',
    'Mixed Terminals':
        'Only terminals and honours; includes All Triplets. With concealed triplets or four kongs, only the upgrade (5 or 10) is added.',
    'All Terminals': 'Only 1s and 9s. Includes All Triplets.',
    'All Honours': 'Only winds and dragons. Includes All Triplets.',
    'Seven Pairs':
        'Seven different pairs, a variant rule that is enabled. Combines with the flushes and All Honours.',
    'Nine Gates':
        'Concealed 1112345678999 in one suit plus any tile of that suit.',
    'Thirteen Orphans': 'One of each terminal and honour plus a matching tile.',
    'Blessing of Heaven': 'The dealer wins with the opening hand.',
    'Blessing of Earth':
        'Winning on the dealer’s first discard, before any call.',
    'Blessing of Man': 'A non-dealer’s first self-pick, before any call.',
    'No Flowers or Seasons': 'No bonus tiles exposed.',
    'hkSeatFlower':
        'A bonus tile numbered for your seat: East 1, South 2, West 3, North 4.',
    'All Flowers': 'All four flowers. Adds to the seat flower.',
    'All Seasons': 'All four seasons. Adds to the seat season.',
    'Seven Flowers':
        'An optional immediate win on exposing a seventh bonus tile. Nothing else is scored.',
    'Eight Flowers':
        'An optional immediate win on exposing all eight bonus tiles. Nothing else is scored.',
    'Chicken Hand':
        'A complete hand with no scoring features. It wins only at a 0-faan minimum.',
  };

  static const _taiwanese = {
    'Self-Drawn': 'Winning on your own draw. Adds to Fully Concealed Hand.',
    'Concealed Hand': 'A closed hand won on a discard.',
    'Fully Concealed Hand':
        'A closed hand won by self-draw, instead of Concealed Hand.',
    'Value Honor':
        'Each dragon pung or kong, and a pung or kong of your seat wind.',
    'Flower Tile': 'Each flower or season exposed, whatever its number.',
    'No Flower Tiles': 'No flowers or seasons.',
    'No Honors': 'No winds or dragons.',
    'No Flower or Honor Tiles': 'Neither. Replaces the two awards above.',
    'Melded Kong': 'Each open or added kong.',
    'Concealed Kong': 'Each concealed kong.',
    'Two Concealed Pungs':
        'Two concealed pungs or kongs. A pung completed by a discard is not concealed.',
    'Three Concealed Pungs': 'Three. Replaces Two Concealed Pungs.',
    'Four Concealed Pungs': 'Four. Replaces the smaller tiers.',
    'Five Concealed Pungs': 'Five. Replaces the smaller tiers.',
    'Single Wait': 'The winning tile completes the pair.',
    'Closed Wait':
        'The winning tile is the middle of a chow, like the 5 in 4-5-6.',
    'Robbing the Kong': 'Winning on the tile added to an exposed pung.',
    'Last Tile Draw': 'Self-draw on the last wall tile.',
    'Win Within 5 Discards': 'Fewer than five discards on the table.',
    'Win Within 5 to 10 Discards':
        'Five to nine discards on the table. Replaced by the above.',
    'Pure Straight': '1-2-3, 4-5-6 and 7-8-9 in one suit.',
    'All Pungs': 'Five pungs or kongs.',
    'All Chows': 'Five chows, no flowers, and a pair that is not an honor.',
    'All Chows with Flowers or Honors':
        'Five chows with flowers or an honor pair. Replaces All Chows.',
    'Melded Hand': 'All five sets called, won on a discard.',
    'Little Three Dragons': 'Two dragon pungs and a dragon pair.',
    'Big Three Dragons':
        'Pungs of all three dragons. Replaces Little Three Dragons and the dragon Value Honors.',
    'Little Three Winds': 'Two wind pungs and a wind pair.',
    'Big Three Winds': 'Three wind pungs. Replaces Little Three Winds.',
    'Little Four Winds':
        'Three wind pungs and a wind pair. Replaces Big Three Winds.',
    'Big Four Winds':
        'Pungs of all four winds. Replaces the smaller wind tiers.',
    'Half Flush': 'One suit plus honors.',
    'Full Flush': 'One suit only. Replaces Half Flush.',
    'Seven Pairs and a Pung':
        'Seven different pairs plus a pung: the alternate 17-tile shape.',
    'Blessings of Heaven': 'The dealer wins with the opening 17 tiles.',
    'Blessings of Earth': 'A non-dealer wins on the dealer’s first discard.',
    'All Flowers':
        'All eight bonus tiles: an immediate win with nothing else scored.',
  };

  static const _mcr = {
    'Big Four Winds': 'Pungs or kongs of all four winds.',
    'Big Three Dragons': 'Pungs or kongs of all three dragons.',
    'All Green': 'Only 2, 3, 4, 6 and 8 bamboo and green dragons.',
    'Nine Gates':
        'Concealed 1112345678999 in one suit, won on any tile of that suit.',
    'Four Kongs': 'Four kongs, melded or concealed.',
    'Seven Shifted Pairs':
        'Seven pairs of consecutive numbers in one suit, such as 2 to 8.',
    'Thirteen Orphans':
        'One of each terminal and honour, plus a second of one of them.',
    'All Terminals': 'Only 1s and 9s.',
    'Little Four Winds': 'Three wind pungs or kongs and a wind pair.',
    'Little Three Dragons': 'Two dragon pungs or kongs and a dragon pair.',
    'All Honors': 'Only winds and dragons.',
    'Four Concealed Pungs': 'Four concealed pungs or kongs.',
    'Pure Terminal Chows':
        'Two 1-2-3 and two 7-8-9 chows in one suit, with a pair of 5s in that suit.',
    'Quadruple Chow': 'Four identical chows in one suit.',
    'Four Pure Shifted Pungs':
        'Pungs or kongs of four consecutive numbers in one suit.',
    'Four Shifted Chows':
        'Four chows in one suit, each one step or each two steps above the last.',
    'Three Kongs': 'Three kongs.',
    'All Terminals and Honors':
        'Only 1s, 9s and honours, as pungs and a pair or as seven pairs.',
    'Seven Pairs': 'Seven pairs; four identical tiles may count as two.',
    'Greater Honors and Knitted Tiles':
        'All seven honours plus seven tiles from a knitted 1-4-7, 2-5-8, 3-6-9 set, one suit each, with no pairs.',
    'All Even Pungs': 'Pungs or kongs of 2, 4, 6 or 8, and a pair of the same.',
    'Full Flush': 'Only one suit.',
    'Pure Triple Chow': 'Three identical chows in one suit.',
    'Pure Shifted Pungs':
        'Pungs or kongs of three consecutive numbers in one suit.',
    'Upper Tiles': 'Only 7, 8 and 9.',
    'Middle Tiles': 'Only 4, 5 and 6.',
    'Lower Tiles': 'Only 1, 2 and 3.',
    'Pure Straight': '1-2-3, 4-5-6 and 7-8-9 in one suit.',
    'Three-Suited Terminal Chows':
        '1-2-3 and 7-8-9 in each of two suits, and a pair of 5s in the third.',
    'Pure Shifted Chows':
        'Three chows in one suit, each one step or each two steps above the last.',
    'All Fives': 'Every set and the pair include a 5.',
    'Triple Pung': 'Pungs or kongs of the same number in all three suits.',
    'Three Concealed Pungs': 'Three concealed pungs or kongs.',
    'Lesser Honors and Knitted Tiles':
        '14 different single tiles from the honours and a knitted 1-4-7, 2-5-8, 3-6-9 set.',
    'Knitted Straight':
        '1-4-7, 2-5-8 and 3-6-9, each in a different suit, plus one set and a pair.',
    'Upper Four': 'Only 6, 7, 8 and 9.',
    'Lower Four': 'Only 1, 2, 3 and 4.',
    'Big Three Winds': 'Pungs or kongs of three winds.',
    'Mixed Straight': '1-2-3, 4-5-6 and 7-8-9, one in each suit.',
    'Reversible Tiles':
        'Only tiles that look the same upside down: 1, 2, 3, 4, 5, 8, 9 dots, 2, 4, 5, 6, 8, 9 bamboo and white dragons.',
    'Mixed Triple Chow': 'The same chow in all three suits.',
    'Mixed Shifted Pungs':
        'Pungs or kongs of three consecutive numbers, one in each suit.',
    'Chicken Hand': 'A hand worth no other fan, flowers aside.',
    'Last Tile Draw': 'Self-draw on the last tile of the wall.',
    'Last Tile Claim': 'Winning on the final discard.',
    'Out with Replacement Tile': 'Self-draw on a kong’s replacement tile.',
    'Robbing the Kong':
        'Winning on the tile another player adds to a melded pung.',
    'Two Concealed Kongs': 'Two concealed kongs.',
    'All Pungs': 'Four pungs or kongs and a pair.',
    'Half Flush': 'One suit plus honours.',
    'Mixed Shifted Chows':
        'Three chows, one in each suit, each one step above the last.',
    'All Types': 'Characters, bamboo, dots, winds and dragons all appear.',
    'Melded Hand':
        'Every set melded, won on a discard that completes the pair.',
    'Two Dragon Pungs': 'Two dragon pungs or kongs.',
    'Outside Hand': 'Every set and the pair include a terminal or honour.',
    'Fully Concealed': 'No melds, won by self-draw.',
    'Two Melded Kongs': 'Two melded kongs.',
    'Last Tile':
        'Winning on the last copy of a tile, the other three already visible.',
    'Dragon Pung': 'A dragon pung or kong.',
    'Prevalent Wind': 'A pung or kong of the round wind.',
    'Seat Wind': 'A pung or kong of your seat wind.',
    'Concealed Hand': 'No melds, won on a discard.',
    'All Chows': 'Four chows and a suited pair.',
    'Tile Hog': 'All four copies of a tile used without a kong.',
    'Double Pung': 'Pungs or kongs of the same number in two suits.',
    'Two Concealed Pungs': 'Two concealed pungs or kongs.',
    'Concealed Kong': 'One concealed kong.',
    'All Simples': 'No terminals or honours.',
    'Pure Double Chow': 'Two identical chows in one suit.',
    'Mixed Double Chow': 'The same chow in two suits.',
    'Short Straight': 'Two chows making six consecutive numbers in one suit.',
    'Two Terminal Chows': '1-2-3 and 7-8-9 in one suit.',
    'Pung of Terminals or Honors':
        'A pung or kong of 1s, 9s, or a wind that is neither seat nor round wind.',
    'Melded Kong': 'One melded kong.',
    'One Voided Suit': 'One of the three suits is missing.',
    'No Honors': 'No winds or dragons.',
    'Edge Wait': 'Winning on the 3 of 1-2 or the 7 of 8-9, the only wait.',
    'Closed Wait': 'Winning on the middle tile of a chow, the only wait.',
    'Single Wait': 'Winning on the pair, the only wait.',
    'Self-Drawn': 'Winning on your own draw.',
    'Flower Tiles': 'Each flower, added after the 8-point minimum.',
    mcrMixedKongs: 'One melded and one concealed kong.',
  };

  static const _sichuan = {
    'Root':
        'Each set of four identical tiles in the hand, kong or not, seven pairs included.',
    'All Pungs': 'Four pungs or kongs and a pair.',
    'Full Flush': 'Only one suit.',
    'Seven Pairs': 'Seven pairs; four identical tiles may be two of them.',
    'Golden Single Wait':
        'Four melds exposed, and the win completes the pair. Includes All Pungs.',
    'Win after Kong': 'Self-draw on a kong’s replacement tile.',
    'Robbing the Kong': 'Winning on the tile added to an exposed pung.',
    'Shoot after Kong':
        'Winning on the discard a player makes just after their kong.',
    'Under the Sea': 'Winning on the last wall tile, or the discard after it.',
  };
}

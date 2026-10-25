/// English rules text: the reference wording the other languages follow.
library;

import 'package:mahjong_core/ruleset.dart';

import 'rules_content.dart';
import 'rules_text.dart';

class EnRulesText extends RulesText {
  const EnRulesText();

  @override
  List<RuleSection> riichi({required bool sanma}) => [
        RuleSection(
            'setup',
            'Tiles and the goal',
            sanma
                ? 'Three players, 108 tiles. The 2–8 characters are removed; the seat across is empty. Hold 13 tiles between draws. A winning hand normally has four sets and a pair. Seven distinct pairs and Thirteen Orphans are special winning shapes. Start with 35,000 points.'
                : 'Four players, 136 tiles, including red fives. Hold 13 tiles between draws. A winning hand normally has four sets and a pair. A set is a sequence of three suited tiles or three identical tiles; a kan uses four identical tiles. Seven distinct pairs and Thirteen Orphans are special winning shapes. Start with 25,000 points.'),
        RuleSection(
            'calls',
            'Draw, discard and call',
            sanma
                ? 'Draw a tile, then discard one. You may pon a discard to make a triplet or kan to make a quad, but you cannot chi. A kan draws a replacement from the dead wall. Calling pon or an open kan makes your hand open and changes which yaku it can score.'
                : 'Draw a tile, then discard one. Chi claims a sequence from the player immediately before you; pon claims a triplet and kan a quad. Winning claims take priority. A kan draws a replacement from the dead wall. Chi, pon and open kan make the hand open, changing which yaku it can score.'),
        const RuleSection('winning', 'Winning: yaku and furiten',
            'Declare tsumo on your own draw or ron on a discard. You need at least one yaku: dora alone cannot make a legal win. If any tile in your current waits is in your own discards, you are furiten and cannot ron, but can still tsumo. Passing a legal ron also blocks ron temporarily; after riichi that restriction lasts for the rest of the hand.'),
        const RuleSection('riichi', 'Riichi and dora',
            'With a closed, ready hand and enough points, declare riichi and pay a 1,000-point deposit. Your hand is then locked: normally you discard each new draw, with only permitted kans allowed. Yaku and dora add han; fu describes the hand’s structure. Dora indicators identify bonus tiles, red fives add bonus han, and a riichi win can reveal ura dora.'),
        if (sanma)
          const RuleSection('kita', 'Kita: setting North aside',
              'On your turn, set a North aside for one bonus han and draw a replacement. North also benefits from matching dora and ura indicators. After riichi, only a newly drawn North may be extracted. Kita interrupts ippatsu and first-turn bonuses. An opponent may ron the extracted North; this is not robbing a kan. Kita and kans share eight replacement draws. A 1-character indicator makes 9-character dora, and vice versa.'),
        RuleSection(
            'payments',
            'Scores and payments',
            sanma
                ? 'Han and fu determine points, with limit hands and yakuman above the ordinary table. The discarder pays a ron. On tsumo, the two opponents pay their normal four-player shares; nobody pays for the missing seat (tsumo loss). An exhaustive draw moves 2,000 points between ready and not-ready players when both groups exist. Only the nine-terminals abortive draw is available.'
                : 'Han and fu determine points, with limit hands and yakuman above the ordinary table. The discarder pays a ron; all opponents pay a tsumo, with dealer-dependent amounts. Honba adds repeat payments and the winner collects riichi deposits. An exhaustive draw moves 3,000 points between ready and not-ready players when both groups exist. Rare fu cases and some double-yakuman rules are approximated.'),
        RuleSection(
            'game',
            'Dealer and game length',
            sanma
                ? 'A full game covers East and South, three scheduled hands per wind; East-only has three. Dealer repeats can extend the game. The seat across never takes a turn.'
                : 'A full game is East and South (a hanchan), with four scheduled hands per wind; East-only has four. A dealer win or a ready dealer on an exhaustive draw can repeat the dealership and extend the game.'),
        const RuleSection('source', 'About this summary',
            'This is a quick guide to TileSense’s implemented rules; the lists above cover every yaku, fu rule and limit the scorer counts. Sanma builds on the Japanese Mahjong Wiki’s Sanma reference. Open the external reference for more detail.'),
      ];

  @override
  List<RuleSection> hongKong(String minimum) => [
        const RuleSection('setup', 'Tiles and the goal',
            'Four players, 144 tiles including eight flowers and seasons. Hold 13 ordinary tiles between draws; a normal win is four sets and a pair. Seven Pairs and Thirteen Orphans are also supported. Flowers are exposed and replaced from the wall’s tail, as are kong replacements. There is no reserved dead wall.'),
        const RuleSection('calls', 'Draw, discard and call',
            'Draw, then discard. Chow claims a sequence only from the preceding player; pung claims a triplet and kong a quad. Wins beat kong/pung, which beat chow. Added kongs can be robbed; concealed kongs cannot. Several players may win on the same discard. The last discard can be claimed only to win.'),
        RuleSection('winning', 'Winning and the minimum',
            '$minimum A hand below the minimum cannot win. At 0 faan, a complete chicken hand with no scoring features is legal. Self-Pick adds faan, so a hand may qualify on a draw even when it cannot win on a discard. There is no riichi or furiten.'),
        const RuleSection('scoring', 'Faan and flowers',
            'Independent scoring features add faan; an upgraded feature replaces its lower award. Flowers and seasons can add bonuses. Exposing a seventh or eighth bonus tile offers an immediate flower win, worth 3 or 8 faan, before drawing its replacement. Every feature is listed below.'),
        const RuleSection('payments', 'Payments',
            'Table points for 0–13 faan are 1, 2, 4, 8, 16, 24, 32, 48, 64, 96, 128, 192, 256 and 384. Higher totals stay capped at 384. On a discard win, the discarder alone pays twice the table points to each winner. On self-pick, each opponent pays the table points. Draws transfer nothing; there is no dealer multiplier or repeat payment.'),
        const RuleSection('game', 'Dealer and game length',
            'The dealer repeats on a win or draw; otherwise dealership advances. TileSense plays East and South (eight scheduled dealerships), or East-only (four), with repeats extending play. Negative chip balances do not end the game.'),
        const RuleSection('source', 'About this summary',
            'Based on TileSense’s implementation of danma’s Hong Kong Mahjong Rule Sheet, version 1.0, using New Style discarder-pays-all payments. Open the PDF for the original sheet.'),
      ];

  @override
  List<RuleSection> taiwanese(String minimum) => [
        const RuleSection('setup', 'Tiles and the goal',
            'Four players and 144 tiles including flowers and seasons. Hold 16 ordinary tiles between draws. A normal win has 17 tiles: five sets and a pair. Seven distinct pairs plus a pung is also a winning shape. A kong still counts as one set. Flowers are exposed and replaced automatically.'),
        const RuleSection('calls', 'Draw, discard and call',
            'Draw, then discard. Chow claims a sequence from the preceding player; pung and kong claim matching tiles. Winning claims take priority. Concealed kongs show four backs until the hand ends. There is no riichi, dora or red-five bonus. The last discard can be claimed only to win.'),
        RuleSection('winning', 'Winning and the minimum',
            '$minimum This minimum is a TileSense house rule. A complete hand below it cannot win. Passing a winning discard prevents claiming that wait until your next draw; your own old discards do not create riichi-style furiten.'),
        const RuleSection('scoring', 'Additive points and flowers',
            'Scoring features add flat points rather than using Hong Kong’s doubling table. The source sheet’s points are used as the app’s tai. Flower bonuses count toward the minimum. Eight flowers can produce a special flower win. Every pattern is listed below.'),
        const RuleSection('payments', 'Payments and dealer streak',
            'On self-draw, each opponent pays the full hand value; on a discard win, only the discarder pays. A dealer streak adds 0, 2, 4 or 6 points for zero, one, two or at least three prior consecutive dealer wins. It applies when the dealer wins or deals into a win. A drawn hand resets the streak.'),
        const RuleSection('game', 'Dealer and game length',
            'The dealer stays after a win or draw; otherwise dealership advances. Play East and South, or a shorter East-only game. Repeats can extend the scheduled dealerships.'),
        const RuleSection('source', 'About this summary',
            'Based on the San Diego Mahjong Club’s Taiwanese Mahjong pamphlet, designed by Nathanael J. Reynolds, with TileSense’s configurable winning minimum.'),
      ];

  @override
  List<RuleSection> mcr() => const [
        RuleSection('setup', 'Tiles and the goal',
            'Four players and 144 tiles including eight flowers. Hold 13 tiles between draws. The usual win is four sets and a pair; special shapes include Seven Pairs, Thirteen Orphans and knitted hands. Four identical tiles may count as two pairs. Flowers are always exposed and replaced in TileSense. There is no dead wall.'),
        RuleSection('calls', 'Draw, discard and call',
            'Chow claims from the preceding player. Hu beats kong/pung, which beat chow. A kong cannot follow a chow or pung on the same turn. Concealed kongs stay face down until the hand ends. Only Hu may claim the last discard. If several players claim Hu on a discard, only the nearest player after the discarder wins.'),
        RuleSection('winning', 'The 8-point minimum',
            'A legal win needs at least 8 points before flowers. Seven points plus flowers is still below the minimum. A hand with no other scoring features can score Chicken Hand (8). There is no riichi, furiten or honba.'),
        RuleSection('scoring', '81 fan and exclusions',
            'The scorer considers all 81 fan and their combination rules, selecting the highest legal total. Overlapping or implied patterns cannot always be added together. Flowers add 1 point each only after the minimum is satisfied. Every fan, and the fan it excludes, is listed below.'),
        RuleSection('payments', 'Payments',
            'For a hand worth F points including flowers, each opponent pays F + 8 on self-draw. On a discard win, the discarder pays F + 8 and each other opponent pays 8. A draw transfers nothing. Scores start at 0 and may go negative.'),
        RuleSection('game', 'Dealer and game length',
            'Dealership advances after every hand, win or draw. A full game has 16 hands: four each in East, South, West and North. The shorter practice game has four East-round hands.'),
        RuleSection('source', 'About this summary',
            'Based on the World Mahjong Organization’s Mahjong Competition Rules. TileSense implements play and scoring; tournament administration and referee penalties are outside the game. Open the PDF for the detailed reference.'),
      ];

  @override
  List<RuleSection> sichuan() => const [
        RuleSection('setup', 'Tiles and the goal',
            'Four players, 108 suited tiles, no honors or flowers. Hold 13 tiles between draws. Win with four sets and a pair or Seven Pairs; four identical tiles may count as two pairs. There are no red fives or dead wall. Kong replacements come from the wall’s tail.'),
        RuleSection('void', 'Choose a void suit',
            'Before play, choose one suit to give up. Discard all its tiles before discarding any other suit. You cannot win while that suit remains in your hand or melds. Your choice is hidden from opponents until your first discard.'),
        RuleSection('calls', 'Calls and continued play',
            'You may pung or kong, but cannot claim a chow; sequences inside your hand are allowed. After Hu, that winner stops playing while the others continue. Several players may Hu on one discard. The hand ends when three players have won or the wall runs out. Only Hu may claim the last discard.'),
        RuleSection('winning', 'Winning and passed wins',
            'There is no minimum fan, riichi or honba. If you pass a legal Hu, you cannot claim that tile from another player until after your own turn, or claim another discard unless it pays more.'),
        RuleSection('scoring', 'Fan and payments',
            'Hand values are 1, 2, 4 and 8 points for 0, 1, 2 and 3 or more fan. All Pungs and each root (four identical tiles) add 1 fan; Full Flush and Seven Pairs add 2. Situational bonuses also apply. A discarder pays each winner the hand value. On self-draw, each opponent still playing pays hand value + 1.'),
        RuleSection('settlement', 'Kongs and wall-end settlement',
            'A concealed kong earns 2 from each active opponent; a claimed kong earns 2 from the discarder; an added kong earns 1 from each active opponent. Added kongs must use the tile just drawn. Kong payments are cancelled if robbed or followed immediately by a winning discard. A player still in and not ready at the end collects no kong payments. At wall end, each not-ready player pays each ready player the best value of their waiting hand.'),
        RuleSection('game', 'Dealer and game length',
            'Scores start at 0. Practice is four hands; a full game is eight, with no round wind. The first winner deals next; if several win the first Hu on one discard, the discarder deals. If nobody wins, the dealer stays.'),
        RuleSection('source', 'About this summary',
            'Based on the Sichuan Bloody Rules quick reference at mahjongpictureguide.com, with TileSense’s settlement and turn-order choices where the sheet is silent. Open the PDF for the reference.'),
      ];

  @override
  String hongKongDefaultMinimum(int faan, List<int> choices) =>
      'Default minimum: $faan faan. Choose ${choices.join(', ')} before play.';
  @override
  String hongKongTableMinimum(int faan) => 'This table’s minimum: $faan faan.';
  @override
  String taiwaneseDefaultMinimum(int tai, List<int> choices) =>
      'Default minimum: $tai tai. Choose ${choices.join(', ')} before play.';
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
  String groupIntro(String id) => switch (id) {
        'yaku' =>
          'A win needs at least one yaku; dora never count alone. Where a hand qualifies for two related yaku, the stronger replaces the weaker.',
        'yakuman' =>
          'Each yakuman is worth 8,000 basic points, and they stack. Tenhou, Chiihou, Renhou, Suukantsu and nagashi mangan are not implemented.',
        'dora' =>
          'Bonus han count only when the hand already has a yaku, and are never added to yakuman.',
        'fu' => 'Fu measure the hand’s shape. Add them up, then round.',
        'limits' =>
          'Basic points are fu × 2^(han + 2), raised to these limits. A ron pays 4× basic, or 6× to the dealer. On tsumo the dealer pays 2× and others 1×, or everyone pays 2× to a winning dealer, each rounded up to 100.',
        'faan' =>
          'Independent features add together. Totals above 13 faan are shown but paid at the 13-faan cap.',
        'tai' =>
          'Points add together. Where a family has tiers, only the strongest applies. Not implemented: the sheet’s Riichi (10) and Robbing the Flower (20).',
        'sichuanFan' =>
          'Fan add together; 0, 1, 2 and 3 or more fan pay 1, 2, 4 and 8 points.',
        'mcr88' =>
          'All 81 fan from Appendix 1 of the rules. The scorer picks the highest legal total; the fan named after “Not with” are implied and not added again.',
        _ => '',
      };

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

/// Player-facing summaries of docs/*_RULES.md. Update both when rules change.
/// First pass: English content; the reader labels that limitation explicitly.
library;

import 'package:mahjong_core/hong_kong/hong_kong_rules.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/taiwanese/taiwanese_rules.dart';

class RuleSection {
  const RuleSection(this.id, this.title, this.body);

  final String id;
  final String title;
  final String body;

  bool matches(String query) => '$title $body'.toLowerCase().contains(query);
}

/// Null minimums mean the reader was opened before a table was configured.
List<RuleSection> rulesSections(Ruleset ruleset,
    {int? minimumFaan, int? minimumPoints}) {
  final hkMinimum = minimumFaan == null
      ? 'Default minimum: ${HongKongRules.defaultMinimumFaan} faan. '
          'Choose ${HongKongRules.minimumFaanChoices.join(', ')} before play.'
      : 'This table’s minimum: $minimumFaan faan.';
  final twMinimum = minimumPoints == null
      ? 'Default minimum: ${TaiwaneseRules.defaultMinimumPoints} tai. '
          'Choose ${TaiwaneseRules.minimumPointsChoices.join(', ')} before play.'
      : 'This table’s minimum: $minimumPoints tai.';
  if (ruleset.isJapanese) {
    return [
      RuleSection(
          'setup',
          'Tiles and the goal',
          ruleset.isSanma
              ? 'Three players, 108 tiles. The 2–8 characters are removed; the seat across is empty. Hold 13 tiles between draws. A winning hand normally has four sets and a pair. Seven distinct pairs and Thirteen Orphans are special winning shapes. Start with 35,000 points.'
              : 'Four players, 136 tiles, including red fives. Hold 13 tiles between draws. A winning hand normally has four sets and a pair. A set is a sequence of three suited tiles or three identical tiles; a kan uses four identical tiles. Seven distinct pairs and Thirteen Orphans are special winning shapes. Start with 25,000 points.'),
      RuleSection(
          'calls',
          'Draw, discard and call',
          ruleset.isSanma
              ? 'Draw a tile, then discard one. You may pon a discard to make a triplet or kan to make a quad, but you cannot chi. A kan draws a replacement from the dead wall. Calling pon or an open kan makes your hand open and changes which yaku it can score.'
              : 'Draw a tile, then discard one. Chi claims a sequence from the player immediately before you; pon claims a triplet and kan a quad. Winning claims take priority. A kan draws a replacement from the dead wall. Chi, pon and open kan make the hand open, changing which yaku it can score.'),
      const RuleSection('winning', 'Winning: yaku and furiten',
          'Declare tsumo on your own draw or ron on a discard. You need at least one yaku: dora alone cannot make a legal win. If any tile in your current waits is in your own discards, you are furiten and cannot ron, but can still tsumo. Passing a legal ron also blocks ron temporarily; after riichi that restriction lasts for the rest of the hand.'),
      const RuleSection('riichi', 'Riichi and dora',
          'With a closed, ready hand and enough points, declare riichi and pay a 1,000-point deposit. Your hand is then locked: normally you discard each new draw, with only permitted kans allowed. Yaku and dora add han; fu describes the hand’s structure. Dora indicators identify bonus tiles, red fives add bonus han, and a riichi win can reveal ura dora.'),
      if (ruleset.isSanma)
        const RuleSection('kita', 'Kita: setting North aside',
            'On your turn, set a North aside for one bonus han and draw a replacement. North also benefits from matching dora and ura indicators. After riichi, only a newly drawn North may be extracted. Kita interrupts ippatsu and first-turn bonuses. An opponent may ron the extracted North; this is not robbing a kan. Kita and kans share eight replacement draws. A 1-character indicator makes 9-character dora, and vice versa.'),
      RuleSection(
          'payments',
          'Scores and payments',
          ruleset.isSanma
              ? 'Han and fu determine points, with limit hands and yakuman above the ordinary table. The discarder pays a ron. On tsumo, the two opponents pay their normal four-player shares; nobody pays for the missing seat (tsumo loss). An exhaustive draw moves 2,000 points between ready and not-ready players when both groups exist. Only the nine-terminals abortive draw is available.'
              : 'Han and fu determine points, with limit hands and yakuman above the ordinary table. The discarder pays a ron; all opponents pay a tsumo, with dealer-dependent amounts. Honba adds repeat payments and the winner collects riichi deposits. An exhaustive draw moves 3,000 points between ready and not-ready players when both groups exist. Rare fu cases and some double-yakuman rules are approximated.'),
      RuleSection(
          'game',
          'Dealer and game length',
          ruleset.isSanma
              ? 'A full game covers East and South, three scheduled hands per wind; East-only has three. Dealer repeats can extend the game. The seat across never takes a turn.'
              : 'A full game is East and South (a hanchan), with four scheduled hands per wind; East-only has four. A dealer win or a ready dealer on an exhaustive draw can repeat the dealership and extend the game.'),
      const RuleSection('source', 'About this summary',
          'This is a quick guide to TileSense’s implemented rules, not a complete yaku catalogue. Sanma builds on the Japanese Mahjong Wiki’s Sanma reference. Open the external reference for more detail.'),
    ];
  }
  return switch (ruleset) {
    Ruleset.hongKong => [
        const RuleSection('setup', 'Tiles and the goal',
            'Four players, 144 tiles including eight flowers and seasons. Hold 13 ordinary tiles between draws; a normal win is four sets and a pair. Seven Pairs and Thirteen Orphans are also supported. Flowers are exposed and replaced from the wall’s tail, as are kong replacements. There is no reserved dead wall.'),
        const RuleSection('calls', 'Draw, discard and call',
            'Draw, then discard. Chow claims a sequence only from the preceding player; pung claims a triplet and kong a quad. Wins beat kong/pung, which beat chow. Added kongs can be robbed; concealed kongs cannot. Several players may win on the same discard. The last discard cannot be claimed.'),
        RuleSection('winning', 'Winning and the minimum',
            '$hkMinimum A hand below the minimum cannot win. At 0 faan, a complete chicken hand with no scoring features is legal. Self-Pick adds faan, so a hand may qualify on a draw even when it cannot win on a discard. There is no riichi or furiten.'),
        const RuleSection('scoring', 'Faan and flowers',
            'Independent scoring features add faan; an upgraded feature replaces its lower award. Examples include All Triplets (3), Mixed Flush (3), Full Flush (7) and Seven Pairs (4). Flowers and seasons can add bonuses. Exposing a seventh or eighth bonus tile offers an immediate flower win, worth 3 or 8 faan, before drawing its replacement.'),
        const RuleSection('payments', 'Payments',
            'Table points for 0–13 faan are 1, 2, 4, 8, 16, 24, 32, 48, 64, 96, 128, 192, 256 and 384. Higher totals stay capped at 384. On a discard win, the discarder alone pays twice the table points to each winner. On self-pick, each opponent pays the table points. Draws transfer nothing; there is no dealer multiplier or repeat payment.'),
        const RuleSection('game', 'Dealer and game length',
            'The dealer repeats on a win or draw; otherwise dealership advances. TileSense plays East and South (eight scheduled dealerships), or East-only (four), with repeats extending play. Negative chip balances do not end the game.'),
        const RuleSection('source', 'About this summary',
            'Based on TileSense’s implementation of danma’s Hong Kong Mahjong Rule Sheet, version 1.0, using New Style discarder-pays-all payments. This is a summary; open the PDF for the scoring reference.'),
      ],
    Ruleset.taiwanese => [
        const RuleSection('setup', 'Tiles and the goal',
            'Four players and 144 tiles including flowers and seasons. Hold 16 ordinary tiles between draws. A normal win has 17 tiles: five sets and a pair. Seven distinct pairs plus a pung is also a winning shape. A kong still counts as one set. Flowers are exposed and replaced automatically.'),
        const RuleSection('calls', 'Draw, discard and call',
            'Draw, then discard. Chow claims a sequence from the preceding player; pung and kong claim matching tiles. Winning claims take priority. Concealed kongs show four backs until the hand ends. There is no riichi, dora or red-five bonus. The last discard cannot be claimed.'),
        RuleSection('winning', 'Winning and the minimum',
            '$twMinimum This minimum is a TileSense house rule. A complete hand below it cannot win. Passing a winning discard prevents claiming that wait until your next draw; your own old discards do not create riichi-style furiten.'),
        const RuleSection('scoring', 'Additive points and flowers',
            'Scoring features add flat points rather than using Hong Kong’s doubling table. The source sheet’s points are used as the app’s tai. Flower bonuses count toward the minimum. Eight flowers can produce a special flower win. Check the PDF for the full list of patterns and replacement awards.'),
        const RuleSection('payments', 'Payments and dealer streak',
            'On self-draw, each opponent pays the full hand value; on a discard win, only the discarder pays. A dealer streak adds 0, 2, 4 or 6 points for zero, one, two or at least three prior consecutive dealer wins. It applies when the dealer wins or deals into a win. A drawn hand resets the streak.'),
        const RuleSection('game', 'Dealer and game length',
            'The dealer stays after a win or draw; otherwise dealership advances. Play East and South, or a shorter East-only game. Repeats can extend the scheduled dealerships.'),
        const RuleSection('source', 'About this summary',
            'Based on the San Diego Mahjong Club’s Taiwanese Mahjong pamphlet, designed by Nathanael J. Reynolds, with TileSense’s configurable winning minimum. This summary covers play flow, not every scoring pattern.'),
      ],
    Ruleset.mcr => const [
        RuleSection('setup', 'Tiles and the goal',
            'Four players and 144 tiles including eight flowers. Hold 13 tiles between draws. The usual win is four sets and a pair; special shapes include Seven Pairs, Thirteen Orphans and knitted hands. Four identical tiles may count as two pairs. Flowers are always exposed and replaced in TileSense. There is no dead wall.'),
        RuleSection('calls', 'Draw, discard and call',
            'Chow claims from the preceding player. Hu beats kong/pung, which beat chow. A kong cannot follow a chow or pung on the same turn. Concealed kongs stay face down until the hand ends. Only Hu may claim the last discard. If several players claim Hu on a discard, only the nearest player after the discarder wins.'),
        RuleSection('winning', 'The 8-point minimum',
            'A legal win needs at least 8 points before flowers. Seven points plus flowers is still below the minimum. A hand with no other scoring features can score Chicken Hand (8). There is no riichi, furiten or honba.'),
        RuleSection('scoring', '81 fan and exclusions',
            'The scorer considers all 81 fan and their combination rules, selecting the highest legal total. Overlapping or implied patterns cannot always be added together. Flowers add 1 point each only after the minimum is satisfied. The PDF gives the scoring catalogue; this summary does not list all exclusions.'),
        RuleSection('payments', 'Payments',
            'For a hand worth F points including flowers, each opponent pays F + 8 on self-draw. On a discard win, the discarder pays F + 8 and each other opponent pays 8. A draw transfers nothing. Scores start at 0 and may go negative.'),
        RuleSection('game', 'Dealer and game length',
            'Dealership advances after every hand, win or draw. A full game has 16 hands: four each in East, South, West and North. The shorter practice game has four East-round hands.'),
        RuleSection('source', 'About this summary',
            'Based on the World Mahjong Organization’s Mahjong Competition Rules. TileSense implements play and scoring; tournament administration and referee penalties are outside the game. Open the PDF for the detailed reference.'),
      ],
    Ruleset.sichuan => const [
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
      ],
    _ => throw StateError('Japanese rules are handled above'),
  };
}

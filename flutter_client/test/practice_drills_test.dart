import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/hand_parse.dart' show waitTiles;
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/logic/practice_drills.dart';

/// The practice hands are fixed data, so each one is checked here against the
/// game's own rules: a drill whose answer the engine disagrees with would
/// teach the wrong thing.
void main() {
  PracticeDrill drill(String id) =>
      kPracticeDrills.firstWhere((d) => d.id == id);

  test('ids are unique, and each kind has the hand size it should', () {
    final ids = kPracticeDrills.map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final d in kPracticeDrills) {
      expect(d.hand.length, d.kind == DrillKind.discard ? 14 : 13,
          reason: d.id);
    }
  });

  test('no drill needs more than four of any tile', () {
    for (final d in kPracticeDrills) {
      final all = [
        ...d.hand,
        ...d.optionTiles.take(0),
        if (d.claimedTile != null) d.claimedTile!,
      ];
      for (final t in all.toSet()) {
        expect(all.where((x) => x == t).length, lessThanOrEqualTo(4),
            reason: '${d.id} ${t.code}');
      }
    }
  });

  group('winning tile', () {
    final drills = kPracticeDrills.where((d) => d.kind == DrillKind.winningTile);

    test('the hand is really one tile from winning', () {
      for (final d in drills) {
        expect(d.winningTiles, isNotEmpty, reason: d.id);
      }
    });

    test('exactly one offered tile is right, and the options are distinct',
        () {
      for (final d in drills) {
        final options = d.optionTiles;
        expect(options.toSet().length, options.length, reason: d.id);
        expect(options.where(d.isWinningTile), hasLength(1), reason: d.id);
      }
    });
  });

  group('discard', () {
    test('exactly one tile is a good discard, and it is the odd one out', () {
      final want = {
        'd1': TileType.sou9,
        'd2': TileType.ton,
        'd3': TileType.shaa,
      };
      for (final d in kPracticeDrills.where((d) => d.kind == DrillKind.discard)) {
        expect(d.goodDiscards, [want[d.explains]], reason: d.id);
        expect(d.discardLeavesReady(want[d.explains]!), isTrue, reason: d.id);
      }
    });
  });

  group('claim', () {
    test('each answer follows the rules', () {
      expect(drill('c1').correctClaim, ClaimChoice.pung);
      expect(drill('c2').correctClaim, ClaimChoice.chow);
      expect(drill('c3').correctClaim, ClaimChoice.pass,
          reason: 'a chow is only from the player on your left');
      expect(drill('c4').correctClaim, ClaimChoice.pass);
    });

    test('the claimed tile never wins the hand outright', () {
      for (final d in kPracticeDrills.where((d) => d.kind == DrillKind.claim)) {
        expect(waitTiles([
          for (final (i, t) in d.hand.indexed) Tile(i, t)
        ]).contains(d.claimedTile), isFalse, reason: d.id);
      }
    });
  });

  group('rulesets', () {
    test('every four-player ruleset but Sichuan gets all of theirs', () {
      final fourPlayer = kPracticeDrills.where((d) => !d.sanmaOnly);
      for (final r in Ruleset.values.where((r) => !r.isSichuan && !r.isSanma)) {
        expect(practiceDrillsFor(r), fourPlayer.toList(), reason: r.name);
      }
    });

    test('sanma gets its own, with no 2-8 man and no chi, each explained by '
        'the lesson it restates', () {
      final drills = practiceDrillsFor(Ruleset.sanma);
      expect(drills.map((d) => d.id),
          ['w1s', 'w3s', 'd1s', 'd2s', 'd3s', 'c1s', 'c4s']);
      for (final d in drills) {
        final tiles = [
          ...d.hand,
          ...d.optionTiles,
          if (d.claimedTile != null) d.claimedTile!,
        ];
        expect(
            tiles.where((t) => t.isMan && t.number > 1 && t.number < 9),
            isEmpty,
            reason: d.id);
        final original = drill(d.explains);
        expect(d.kind, original.kind);
        if (d.kind == DrillKind.winningTile) {
          expect(d.winningTiles, original.winningTiles, reason: d.id);
        }
        if (d.kind == DrillKind.discard) {
          expect(d.goodDiscards, original.goodDiscards, reason: d.id);
        }
        if (d.kind == DrillKind.claim) {
          expect(d.correctClaim, original.correctClaim, reason: d.id);
        }
      }
    });

    test('Sichuan drops the honor tiles and the chow lessons', () {
      expect(practiceDrillsFor(Ruleset.sichuan).map((d) => d.id),
          ['w1', 'w2', 'w3', 'd1', 'c1']);
    });
  });
}

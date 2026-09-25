import 'dart:io';

import 'loading_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/meld.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/guide_host.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/table_view.dart';
import 'package:tilesense/ui/tile_face.dart';

/// The status (round / wall / honba / riichi, or dealer repeat) is one line in
/// a pill dead centre of the table, with your pond below it, the across pond
/// above and the side ponds either side, so the table's top-left corner is
/// left to the guide panel. Every pond renders the same size, and with all
/// four at their fullest (four rows and a riichi stick) nothing on the table
/// touches anything else — on the phone-shaped canvas and on a tablet's
/// taller one.
void main() {
  preloadDeferredPages();

  // The test font draws every glyph a full em wide, so a line of text comes
  // out ~1.6x its real width — enough to crowd the app bar with controls
  // that fit easily in the app. Measure with the real Roboto instead, from
  // the Flutter SDK's own cache beside the test runner.
  setUpAll(() async {
    final cache = File(Platform.resolvedExecutable).parent.parent.parent.parent;
    final fonts = Directory('${cache.path}/artifacts/material_fonts');
    final files = fonts.existsSync()
        ? fonts
            .listSync()
            .whereType<File>()
            .where((f) => RegExp(r'Roboto-[A-Za-z]+\.ttf$').hasMatch(f.path))
            .toList()
        : <File>[];
    expect(files, isNotEmpty,
        reason: 'Roboto not found under ${fonts.path}; the layout checks '
            'below need real text widths');
    final loader = FontLoader('Roboto');
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  });

  /// Every tile on the table, as (rect, TileFace).
  List<(Rect, TileFace)> tableTiles(WidgetTester tester) => [
        for (final e in find
            .descendant(
                of: find.byType(TableView), matching: find.byType(TileFace))
            .evaluate())
          (tester.getRect(find.byWidget(e.widget)), e.widget as TileFace),
      ];

  Future<void> startGame(WidgetTester tester,
      {String? ruleset,
      Size size = kDesignSize,
      bool full = false,
      void Function(GuideHost host)? arrange}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    if (ruleset != null) {
      await tester.tap(find.byKey(Key('ruleset_$ruleset')));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(); // Render the startup/loading frame.
    // The table is created after a loading frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // An empty pond renders nothing, so give every pond three full rows —
    // as far as a pond gets in an ordinary round — or, with [full], all four
    // rows behind a riichi stick, as far as a pond can ever get, plus a full
    // flower tray at every seat.
    final host = tester.widget<TableView>(find.byType(TableView)).game;
    for (final seat in [0, 1, 2, 3]) {
      final s = host.round.seats[seat];
      for (var i = 0; i < (full ? 24 : 18); i++) {
        s.pond.add(
          Tile(700 + seat * 30 + i, TileType.values[(seat * 7 + i) % 34]),
        );
      }
      if (full) {
        s.riichi = true;
        s.riichiPondIndex = 6;
        // Four open kans: the most room any opponent's melds can take.
        if (seat != 0) {
          for (var k = 0; k < 4; k++) {
            final type = TileType.values[TileType.man1.index + k * 2];
            s.melds.add(Meld(
              kind: MeldKind.kan,
              low: type,
              concealed: false,
              calledFromSeatOffset: 3,
              tiles: [
                for (var t = 0; t < 4; t++)
                  Tile(950 + seat * 20 + k * 4 + t, type)
              ],
            ));
          }
        }
        if (host.round.ruleset.isChineseStyle) {
          for (var f = 0; f < 8; f++) {
            s.flowers.add(Tile(
                900 + seat * 10 + f, TileType.values[TileType.plum.index + f]));
          }
        }
      }
    }
    arrange?.call(host);
    // Pause notifies listeners, which is what rebuilds the table.
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(milliseconds: 100));
    // Let each pond's newest tile finish flying in, so it is measured where
    // it lands rather than on its way.
    await tester.pump(const Duration(milliseconds: 600));
  }

  for (final (ruleset, tail) in [
    ('riichi', 'Riichi 0'),
    ('hongKong', 'Dealer repeat 0'),
    ('taiwanese', 'Dealer repeat 0'),
  ]) {
    testWidgets(
        '$ruleset: the status is one line in a pill dead centre of the table, '
        'and gone from the app bar', (tester) async {
      await startGame(tester, ruleset: ruleset);
      final line = find.byKey(const Key('tableStatus'));
      expect(line, findsOneWidget);
      expect(
          find.descendant(
              of: line, matching: find.textContaining(RegExp('East 1.*$tail'))),
          findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: line),
          findsNothing,
          reason: 'the status left the app bar for the table');

      final pill = find.byKey(const Key('statusPill'));
      expect(find.descendant(of: find.byType(TableView), matching: pill),
          findsOneWidget);
      final box = tester.getRect(pill);
      expect(box.height, lessThan(32), reason: 'on a single line');
      final between = Rect.fromLTRB(
          box.left,
          tester.getRect(find.byKey(const ValueKey('pond-2'))).bottom,
          box.right,
          tester.getRect(find.byKey(const ValueKey('pond-0'))).top);
      expect(
          (box.center.dx - tester.getRect(find.byType(TableView)).center.dx)
              .abs(),
          lessThan(1),
          reason: 'centred across the table');
      expect((box.center.dy - between.center.dy).abs(), lessThan(1),
          reason: 'centred between your pond and the across pond');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  for (final (label, size) in [
    ('phone-shaped canvas', kDesignSize),
    ('tablet-shaped canvas', const Size(1600, 1128)),
  ]) {
    for (final ruleset in ['riichi', 'hongKong', 'taiwanese']) {
      testWidgets(
          '$ruleset, $label: with every pond full nothing on the table '
          'touches anything else', (tester) async {
        await startGame(tester, ruleset: ruleset, size: size, full: true);
        final table = tester.getRect(find.byType(TableView));
        final bar = tester.getRect(find.byType(AppBar));
        Rect at(Key key) => tester.getRect(find.byKey(key));
        // On the felt.
        final parts = <String, Rect>{
          'status pill': at(const Key('statusPill')),
          for (final seat in [0, 1, 2, 3])
            'pond $seat': at(ValueKey('pond-$seat')),
          'across hand': at(const Key('acrossHand')),
          'across melds': at(const Key('acrossMelds')),
          'your seat': at(const Key('ownSeat')),
          for (final seat in [1, 3])
            'side seat $seat': at(ValueKey('sideSeat-$seat')),
          if (ruleset == 'riichi') 'dead wall': at(const Key('deadWall')),
        };
        // Up in the app bar, with the bar's own controls.
        final barParts = <String, Rect>{
          'across seat': at(const Key('acrossSeat')),
          for (final key in [
            'backToMenu',
            'ruleset',
            'rulesPdf',
            'hanchan',
            'fastMode',
            'autoplayGroup',
          ])
            key: at(Key(key)),
        };
        // A side seat's column runs the full height of the band, empty at
        // the top where the dead wall sits; its own tiles are centred well
        // clear of it.
        const exempt = {('side seat 1', 'dead wall')};
        void noneTouch(Map<String, Rect> group, Rect within, String where,
            {Set<String>? only}) {
          final names = group.keys.toList();
          for (var i = 0; i < names.length; i++) {
            final a = names[i];
            final r = group[a]!;
            expect(
                r.left >= within.left - 0.01 &&
                    r.top >= within.top - 0.01 &&
                    r.right <= within.right + 0.01 &&
                    r.bottom <= within.bottom + 0.01,
                isTrue,
                reason: '$a $r stays within the $where');
            for (final b in names.skip(i + 1)) {
              if (exempt.contains((a, b)) || exempt.contains((b, a))) continue;
              if (only != null && !only.contains(a) && !only.contains(b)) {
                continue;
              }
              // At least 4px between any two.
              expect(r.inflate(2).overlaps(group[b]!.inflate(2)), isFalse,
                  reason: '$a $r and $b ${group[b]} are closer than 4px');
            }
          }
        }

        noneTouch(parts, table, 'table');
        // The bar's own controls are laid out as before; only the across
        // seat is new up there.
        noneTouch(barParts, bar, 'app bar', only: {'across seat'});
        // The across hand hangs straight below the across portrait.
        final seatRect = barParts['across seat']!;
        final hand = parts['across hand']!;
        expect((hand.center.dx - seatRect.center.dx).abs(), lessThan(1),
            reason: 'the across hand is centred under the portrait');
        expect(hand.top - seatRect.bottom, inInclusiveRange(0, 12),
            reason: 'the across hand sits just below the portrait');
        // Every opponent's face-down hand shows the same size of back.
        Size back(Key hand) => tester.getSize(find
            .descendant(of: find.byKey(hand), matching: find.byType(TileFace))
            .first);
        final across = back(const Key('acrossHand'));
        for (final seat in [1, 3]) {
          final side = back(ValueKey('sideHand-$seat'));
          // A side seat's backs are turned on their side.
          expect(side.height, closeTo(across.width, 0.01),
              reason: 'seat $seat backs match the across seat\'s');
          expect(side.width, closeTo(across.height, 0.01),
              reason: 'seat $seat backs match the across seat\'s');
        }
        for (final seat in ['across seat', 'your seat']) {
          final r = parts[seat] ?? barParts[seat]!;
          expect((r.center.dx - table.center.dx).abs(), lessThan(1),
              reason: '$seat portrait and placard sit dead centre');
        }
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }

  for (final (ruleset, handSize) in [('riichi', 13), ('taiwanese', 16)]) {
    for (final calls in [0, 2, 4]) {
      testWidgets(
          '$ruleset: every opponent with $calls open melds shows '
          '${handSize - 3 * calls} backs, and a side seat\'s hand strip '
          'shrinks to fit them', (tester) async {
        final rest = handSize - 3 * calls;
        await startGame(tester, ruleset: ruleset, arrange: (host) {
          for (final seat in [1, 2, 3]) {
            final s = host.round.seats[seat];
            s.drawn = null;
            s.melds
              ..clear()
              ..addAll([
                for (var k = 0; k < calls; k++)
                  Meld(
                    kind: MeldKind.triplet,
                    low: TileType.values[TileType.man1.index + k * 2],
                    concealed: false,
                    calledFromSeatOffset: 3,
                    tiles: [
                      for (var t = 0; t < 3; t++)
                        Tile(600 + seat * 20 + k * 3 + t,
                            TileType.values[TileType.man1.index + k * 2])
                    ],
                  ),
              ]);
            s.hand = [
              for (var i = 0; i < rest; i++)
                Tile(500 + seat * 20 + i, TileType.values[(i * 3) % 27]),
            ];
          }
        });
        expect(
            find.descendant(
                of: find.byKey(const Key('acrossHand')),
                matching: find.byType(TileFace)),
            findsNWidgets(rest),
            reason: 'the across seat shows the same backs as the sides');
        for (final seat in [1, 3]) {
          final hand = find.byKey(ValueKey('sideHand-$seat'));
          final backs =
              find.descendant(of: hand, matching: find.byType(TileFace));
          expect(backs, findsNWidgets(rest));
          // A turned small back is 22 long plus 0.5 padding each end: the
          // strip holds the resting backs, one spare slot for the cut
          // flash, the 6 gap and the drawn tile's slot — nothing more.
          final scale = tester.getSize(backs.first).height / 22;
          expect(tester.getSize(hand).height,
              closeTo(((rest + 2) * 23 + 6) * scale, 0.5),
              reason: 'seat $seat hand strip is sized to its $rest backs');
        }
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }

  test('the canvas keeps its width and grows taller on squarer screens', () {
    // Phones held sideways are wider than 1600:820 and keep it.
    expect(canvasSizeFor(const Size(844, 390)), kDesignSize);
    expect(canvasSizeFor(const Size(915, 360)), kDesignSize);
    // Tablets and laptops get the height their screen has room for.
    final ipad = canvasSizeFor(const Size(1180, 760));
    expect(ipad.width, kDesignSize.width);
    expect(ipad.height, closeTo(1600 * 760 / 1180, 0.01));
    // Up to a cap, past 4:3.
    expect(canvasSizeFor(const Size(1000, 1000)),
        const Size(1600, kMaxCanvasHeight));
    expect(canvasSizeFor(Size.zero), kDesignSize);
  });

  testWidgets('the guide panel starts at the top of the table', (tester) async {
    await startGame(tester);
    // Resume first: the pause veil would otherwise sit over everything.
    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('bottomGuideToggle')));
    await tester.pump();

    final guide = tester.getRect(find.byType(EfficiencyOverlay));
    final table = tester.getRect(find.byType(TableView));
    expect(guide.top, greaterThanOrEqualTo(table.top));
    expect(guide.top - table.top, lessThan(20),
        reason: 'nothing sits in the top-left corner above it any more');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the builder\'s guide panel starts at the top of the table too',
      (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('openBuilder')));
    await pumpLoadedPage(tester);

    final guide = tester.getRect(find.byType(EfficiencyOverlay));
    final table = tester.getRect(find.byType(TableView));
    expect(guide.top, greaterThanOrEqualTo(table.top));
    expect(guide.top - table.top, lessThan(20));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
      'all four ponds render the same size, and the top and bottom ones '
      'meet across the middle', (tester) async {
    await startGame(tester);
    final table = tester.getRect(find.byType(TableView));
    final midX = table.center.dx;

    // Pond tiles are the table's `normal` faces; the top and bottom ponds sit
    // on the centre column, the side ponds well off it.
    final pond = [
      for (final t in tableTiles(tester))
        if (t.$2.size == TileSize.normal &&
            t.$1.top > table.top + 60 && // below the dead wall row
            t.$1.bottom < table.bottom)
          t,
    ];
    final centre = [
      for (final t in pond)
        if ((t.$1.center.dx - midX).abs() < 160) t
    ];
    final side = [
      for (final t in pond)
        if ((t.$1.center.dx - midX).abs() > 200) t
    ];
    expect(centre, hasLength(36), reason: 'three rows each, top and bottom');
    expect(side, hasLength(36));

    // A side pond is turned, so its tiles lie on their side: compare long
    // edge to long edge. Each pond's newest tile is caught mid drop-in (it
    // starts a little small), so compare the size most tiles have.
    double commonLongEdge(List<(Rect, TileFace)> tiles) {
      final counts = <double, int>{};
      for (final (r, _) in tiles) {
        final e = (r.width > r.height ? r.width : r.height).roundToDouble();
        counts[e] = (counts[e] ?? 0) + 1;
      }
      return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    expect(commonLongEdge(centre), commonLongEdge(side),
        reason: 'top and bottom pond tiles should match the side ponds');

    final midY = (centre.map((t) => t.$1.center.dy).reduce((a, b) => a + b)) /
        centre.length;
    final above = centre
        .where((t) => t.$1.center.dy < midY)
        .map((t) => t.$1.bottom)
        .reduce((a, b) => a > b ? a : b);
    final below = centre
        .where((t) => t.$1.center.dy > midY)
        .map((t) => t.$1.top)
        .reduce((a, b) => a < b ? a : b);
    final pill = tester.getRect(find.byKey(const Key('statusPill')));
    expect(above, lessThan(pill.top));
    expect(below, greaterThan(pill.bottom));
    expect(below - above, inInclusiveRange(pill.height + 8, pill.height + 16),
        reason: 'the two ponds should meet across the middle of the table, '
            'with just the status pill between them');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

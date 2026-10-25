/// Mahjong vocabulary in the current language, per ruleset: each language has
/// its own words, and within one Riichi, Hong Kong and Taiwanese keep theirs
/// (Chi vs Chow, 吃 vs 上). `mahjong_core` keeps its English getters as stable
/// identifiers for the server, logs and the guide's own bookkeeping; these are
/// only ever for display. English here is exactly what those getters say.
library;

import 'package:mahjong_core/mcr/mcr_rules.dart';
import 'package:mahjong_core/round.dart' show CallType, MinimumShortfall;
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart' show TileType, Wind;

import 'app_localizations.dart';

extension MahjongTerms on AppLocalizations {
  String rulesetName(Ruleset r) => switch (r) {
        Ruleset.riichi => rulesetRiichi,
        Ruleset.sanma => rulesetSanma,
        Ruleset.hongKong => rulesetHongKong,
        Ruleset.taiwanese => rulesetTaiwanese,
        Ruleset.mcr => rulesetMcr,
        Ruleset.sichuan => rulesetSichuan,
      };

  /// [rulesetName] for a tooltip, where there is room to say what the rules
  /// are: sanma says it is three-player.
  String rulesetTooltipName(Ruleset r) =>
      r.isSanma ? rulesetSanmaLong : rulesetName(r);

  /// The label on a link to [r]'s rules: a PDF, or (sanma) a web page.
  String rulesLinkLabel(Ruleset r) => r.rulesUrl.endsWith('.pdf')
      ? rulesPdf(rulesetName(r))
      : rulesWeb(rulesetName(r));

  /// [rulesetName] with the ruleset's flag in front, for toggles and badges.
  /// Plain text: a ruleset with a flag image (see [Ruleset.flagAsset]) shows
  /// its text stand-in here; widgets that can draw the image use `RulesetFlag`.
  String rulesetFlagLabel(Ruleset r) => '${r.flag} ${rulesetName(r)}'.trim();

  /// Sichuan's suit names (0 man, 1 pin, 2 sou) — the void suit's.
  String suitName(int suit) => switch (suit) {
        0 => suitMan,
        1 => suitPin,
        _ => suitSou,
      };

  String windName(Wind w) => switch (w) {
        Wind.east => windEast,
        Wind.south => windSouth,
        Wind.west => windWest,
        Wind.north => windNorth,
      };

  /// What a chi / pon / kan / ron is called under [r]; empty for
  /// [CallType.none].
  String callLabel(CallType type, Ruleset r) => switch (type) {
        CallType.chi =>
          _pick(r, callChiRiichi, callChiHongKong, callChiTaiwanese),
        CallType.pon =>
          _pick(r, callPonRiichi, callPonHongKong, callPonTaiwanese),
        CallType.kan =>
          _pick(r, callKanRiichi, callKanHongKong, callKanTaiwanese),
        CallType.ron =>
          _pick(r, callRonRiichi, callRonHongKong, callRonTaiwanese),
        CallType.none => '',
      };

  /// The under-minimum badge: what [r] calls a hand too cheap to win (no
  /// yaku, or under the table's faan / tai / fan floor), with "no win" added
  /// when not even a self-draw reaches it. Empty for [MinimumShortfall.none].
  String minimumShortfallLabel(Ruleset r, MinimumShortfall s,
      {required int minimumFaan, required int minimumPoints}) {
    if (s == MinimumShortfall.none) return '';
    final label = switch (r) {
      Ruleset.riichi || Ruleset.sanma => noYaku,
      Ruleset.hongKong => underFaan(minimumFaan),
      Ruleset.taiwanese => underTai(minimumPoints),
      Ruleset.mcr => underFan(McrRules.minimumPoints),
      // Sichuan has no minimum, so nothing is ever under it.
      Ruleset.sichuan => '',
    };
    return s == MinimumShortfall.dead ? '$label · $noWin' : label;
  }

  /// The under-minimum badge's tooltip; empty for [MinimumShortfall.none].
  String minimumShortfallTooltip(MinimumShortfall s) => switch (s) {
        MinimumShortfall.none => '',
        MinimumShortfall.ronOnly => minimumRonOnlyTooltip,
        MinimumShortfall.dead => minimumDeadTooltip,
      };

  String tsumoLabel(Ruleset r) =>
      _pick(r, callTsumoRiichi, callTsumoHongKong, callTsumoTaiwanese);

  /// A call bubble's word. `CallCallout` records English tokens (CHI, PON,
  /// KAN, RON, TSUMO, RIICHI, RINSHAN), which English shows as it always has,
  /// in every ruleset; every other language shows that ruleset's own word.
  String callBubble(String token, Ruleset r) {
    if (localeName == 'en') return token;
    return switch (token) {
      'CHI' => callLabel(CallType.chi, r),
      'PON' => callLabel(CallType.pon, r),
      'KAN' => callLabel(CallType.kan, r),
      'RON' => callLabel(CallType.ron, r),
      'TSUMO' => tsumoLabel(r),
      'RIICHI' => bubbleRiichi,
      'KITA' => bubbleKita,
      'RINSHAN' =>
        r.isChineseStyle ? bubbleRinshanChinese : bubbleRinshanRiichi,
      _ => token,
    };
  }

  /// An honor or flower tile's name (the ones scoring names embed); null for
  /// a suited tile.
  String? tileName(TileType t) => switch (t) {
        TileType.ton => tileTon,
        TileType.nan => tileNan,
        TileType.shaa => tileShaa,
        TileType.pei => tilePei,
        TileType.haku => tileHaku,
        TileType.hatsu => tileHatsu,
        TileType.chun => tileChun,
        TileType.plum => tilePlum,
        TileType.orchid => tileOrchid,
        TileType.chrysanthemum => tileChrysanthemum,
        TileType.bamboo => tileBamboo,
        TileType.spring => tileSpring,
        TileType.summer => tileSummer,
        TileType.autumn => tileAutumn,
        TileType.winter => tileWinter,
        _ => null,
      };

  /// Any tile's name ("5 Man", "Red Dragon"…); English is exactly
  /// [TileType.displayName].
  String tileDisplayName(TileType t) {
    if (t.isMan) return tileMan(t.number);
    if (t.isPin) return tilePin(t.number);
    if (t.isSou) return tileSou(t.number);
    return tileName(t) ?? t.displayName;
  }

  /// A yaku / faan / tai name from `mahjong_core` (e.g. "Riichi", "Red
  /// Dragon Pung", "Yakuhai (East)"), in this language under [r]. Anything
  /// not recognised — a name added to the core but not here yet — shows in
  /// English rather than blank.
  String scoringName(String name, Ruleset r) {
    final table = switch (r) {
      Ruleset.riichi || Ruleset.sanma => _riichiNames,
      Ruleset.hongKong => _hongKongNames,
      Ruleset.taiwanese => _taiwaneseNames,
      Ruleset.mcr => _mcrNames,
      Ruleset.sichuan => _sichuanNames,
    };
    if (table[name] case final known?) return known(this);
    if (_yakuhai.firstMatch(name) case final m?) {
      return yakuYakuhai(_tileByEnglish(m[1]!) ?? m[1]!);
    }
    if (_honorPung.firstMatch(name) case final m?) {
      if (_tileByEnglish(m[1]!) case final tile?) return faanHonorPung(tile);
    }
    // Hong Kong's own-seat flower or season, scored under its tile name.
    return _tileByEnglish(name) ?? name;
  }

  /// A round's result title from `mahjong_core` ("Ron", "Self Draw",
  /// "Exhaustive Draw"…); a flower win's title is its pattern's name.
  String resultLabel(String label, Ruleset r) =>
      _resultNames[label]?.call(this) ?? scoringName(label, r);

  /// A riichi or Hong Kong limit name ("Mangan", "3× Yakuman").
  String limitName(String name) {
    if (_limitNames[name] case final known?) return known(this);
    if (_multipleYakuman.firstMatch(name) case final m?) {
      return limitMultipleYakuman(int.parse(m[1]!));
    }
    return name;
  }

  String? _tileByEnglish(String english) {
    for (final t in TileType.values) {
      if (t.displayName == english) return tileName(t);
    }
    return null;
  }

  static final _yakuhai = RegExp(r'^Yakuhai \((.+)\)$');
  static final _honorPung = RegExp(r'^(.+) Pung$');
  static final _multipleYakuman = RegExp(r'^(\d+)× Yakuman$');

  static String _pick(
          Ruleset r, String riichi, String hongKong, String taiwanese) =>
      switch (r) {
        Ruleset.riichi || Ruleset.sanma => riichi,
        Ruleset.hongKong => hongKong,
        Ruleset.taiwanese => taiwanese,
        Ruleset.mcr => taiwanese,
        Ruleset.sichuan => taiwanese,
      };
}

// English name (mahjong_core's identifier) to its display string, per
// ruleset; see [MahjongTerms.scoringName].
final Map<String, String Function(AppLocalizations)> _riichiNames = {
  'Riichi': (l) => l.yakuRiichi,
  'Double Riichi': (l) => l.yakuDoubleRiichi,
  'Ippatsu': (l) => l.yakuIppatsu,
  'Menzen Tsumo': (l) => l.yakuMenzenTsumo,
  'Haitei Raoyue': (l) => l.yakuHaiteiRaoyue,
  'Houtei Raoyui': (l) => l.yakuHouteiRaoyui,
  'Rinshan Kaihou': (l) => l.yakuRinshanKaihou,
  'Chankan': (l) => l.yakuChankan,
  'Kita': (l) => l.yakuKita,
  'Tanyao': (l) => l.yakuTanyao,
  'Round Wind': (l) => l.yakuRoundWind,
  'Seat Wind': (l) => l.yakuSeatWind,
  'Shousangen': (l) => l.yakuShousangen,
  'Pinfu': (l) => l.yakuPinfu,
  'Iipeiko': (l) => l.yakuIipeiko,
  'Ryanpeikou': (l) => l.yakuRyanpeikou,
  'Chiitoitsu': (l) => l.yakuChiitoitsu,
  'Toitoi': (l) => l.yakuToitoi,
  'Sanankou': (l) => l.yakuSanankou,
  'Sankantsu': (l) => l.yakuSankantsu,
  'Sanshoku Doujun': (l) => l.yakuSanshokuDoujun,
  'Sanshoku Doukou': (l) => l.yakuSanshokuDoukou,
  'Ittsu': (l) => l.yakuIttsu,
  'Honroutou': (l) => l.yakuHonroutou,
  'Honitsu': (l) => l.yakuHonitsu,
  'Chinitsu': (l) => l.yakuChinitsu,
  'Chanta': (l) => l.yakuChanta,
  'Junchan': (l) => l.yakuJunchan,
  'Dora': (l) => l.yakuDora,
  'Ura Dora': (l) => l.yakuUraDora,
  'Aka Dora': (l) => l.yakuAkaDora,
  'Kokushi Musou': (l) => l.yakuKokushiMusou,
  'Suuankou': (l) => l.yakuSuuankou,
  'Daisangen': (l) => l.yakuDaisangen,
  'Daisuushii': (l) => l.yakuDaisuushii,
  'Shousuushii': (l) => l.yakuShousuushii,
  'Tsuuiisou': (l) => l.yakuTsuuiisou,
  'Chinroutou': (l) => l.yakuChinroutou,
  'Ryuuiisou': (l) => l.yakuRyuuiisou,
  'Chuuren Poutou': (l) => l.yakuChuurenPoutou,
};

final Map<String, String Function(AppLocalizations)> _hongKongNames = {
  'All Flowers': (l) => l.faanAllFlowers,
  'All Seasons': (l) => l.faanAllSeasons,
  'All Honours': (l) => l.faanAllHonours,
  'All Sequences': (l) => l.faanAllSequences,
  'All Terminals': (l) => l.faanAllTerminals,
  'All Triplets': (l) => l.faanAllTriplets,
  'All Quadruplets': (l) => l.faanAllQuadruplets,
  'All Quadruplets (upgrade)': (l) => l.faanAllQuadrupletsUpgrade,
  'All Concealed Triplets': (l) => l.faanAllConcealedTriplets,
  'All Concealed Triplets (upgrade)': (l) => l.faanAllConcealedTripletsUpgrade,
  'Big Four Winds': (l) => l.faanBigFourWinds,
  'Big Three Dragons': (l) => l.faanBigThreeDragons,
  'Blessing of Earth': (l) => l.faanBlessingOfEarth,
  'Blessing of Heaven': (l) => l.faanBlessingOfHeaven,
  'Blessing of Man': (l) => l.faanBlessingOfMan,
  'Chicken Hand': (l) => l.faanChickenHand,
  'Concealed Hand': (l) => l.faanConcealedHand,
  'Double Kong Replacement': (l) => l.faanDoubleKongReplacement,
  'Full Flush': (l) => l.faanFullFlush,
  'Mixed Flush': (l) => l.faanMixedFlush,
  'Mixed Terminals': (l) => l.faanMixedTerminals,
  'Moon Under the Sea': (l) => l.faanMoonUnderTheSea,
  'Nine Gates': (l) => l.faanNineGates,
  'No Flowers or Seasons': (l) => l.faanNoFlowersOrSeasons,
  'Robbing the Kong': (l) => l.faanRobbingTheKong,
  'Round Wind': (l) => l.faanRoundWind,
  'Seat Wind': (l) => l.faanSeatWind,
  'Self-Pick': (l) => l.faanSelfPick,
  'Seven Pairs': (l) => l.faanSevenPairs,
  'Small Four Winds': (l) => l.faanSmallFourWinds,
  'Small Three Dragons': (l) => l.faanSmallThreeDragons,
  'Thirteen Orphans': (l) => l.faanThirteenOrphans,
  'Win by Kong Replacement': (l) => l.faanWinByKongReplacement,
  'Seven Flowers': (l) => l.faanSevenFlowers,
  'Eight Flowers': (l) => l.faanEightFlowers,
};

final Map<String, String Function(AppLocalizations)> _taiwaneseNames = {
  'All Chows with Flowers or Honors': (l) => l.taiAllChowsWithFlowersOrHonors,
  'All Chows': (l) => l.taiAllChows,
  'All Pungs': (l) => l.taiAllPungs,
  'All Flowers': (l) => l.taiAllFlowers,
  'Big Four Winds': (l) => l.taiBigFourWinds,
  'Big Three Dragons': (l) => l.taiBigThreeDragons,
  'Big Three Winds': (l) => l.taiBigThreeWinds,
  'Blessings of Earth': (l) => l.taiBlessingsOfEarth,
  'Blessings of Heaven': (l) => l.taiBlessingsOfHeaven,
  'Closed Wait': (l) => l.taiClosedWait,
  'Concealed Hand': (l) => l.taiConcealedHand,
  'Concealed Kong': (l) => l.taiConcealedKong,
  'Five Concealed Pungs': (l) => l.taiFiveConcealedPungs,
  'Four Concealed Pungs': (l) => l.taiFourConcealedPungs,
  'Three Concealed Pungs': (l) => l.taiThreeConcealedPungs,
  'Two Concealed Pungs': (l) => l.taiTwoConcealedPungs,
  'Flower Tile': (l) => l.taiFlowerTile,
  'Fully Concealed Hand': (l) => l.taiFullyConcealedHand,
  'Full Flush': (l) => l.taiFullFlush,
  'Half Flush': (l) => l.taiHalfFlush,
  'Last Tile Draw': (l) => l.taiLastTileDraw,
  'Little Four Winds': (l) => l.taiLittleFourWinds,
  'Little Three Dragons': (l) => l.taiLittleThreeDragons,
  'Little Three Winds': (l) => l.taiLittleThreeWinds,
  'Melded Hand': (l) => l.taiMeldedHand,
  'Melded Kong': (l) => l.taiMeldedKong,
  'No Flower or Honor Tiles': (l) => l.taiNoFlowerOrHonorTiles,
  'No Flower Tiles': (l) => l.taiNoFlowerTiles,
  'No Honors': (l) => l.taiNoHonors,
  'Pure Straight': (l) => l.taiPureStraight,
  'Robbing the Kong': (l) => l.taiRobbingTheKong,
  'Self-Drawn': (l) => l.taiSelfDrawn,
  'Seven Pairs and a Pung': (l) => l.taiSevenPairsAndAPung,
  'Single Wait': (l) => l.taiSingleWait,
  'Value Honor': (l) => l.taiValueHonor,
  'Win Within 5 Discards': (l) => l.taiWinWithin5Discards,
  'Win Within 5 to 10 Discards': (l) => l.taiWinWithin5To10Discards,
};

final Map<String, String Function(AppLocalizations)> _resultNames = {
  'Kyuushu Kyuuhai — nine terminals/honors': (l) =>
      l.resultKyuushuKyuuhaiNineTerminalsHonors,
  'Exhaustive Draw': (l) => l.resultExhaustiveDraw,
  'Multiple Wins': (l) => l.resultMultipleWins,
  'Robbing a Kong': (l) => l.resultRobbingAKong,
  'Win on Discard': (l) => l.resultWinOnDiscard,
  'Multiple Ron': (l) => l.resultMultipleRon,
  'Chankan': (l) => l.resultChankan,
  'Ron': (l) => l.resultRon,
  'Self Draw': (l) => l.resultSelfDraw,
  'Tsumo': (l) => l.resultTsumo,
  'Wall Ends': (l) => l.resultWallEnds,
  'Three Hu': (l) => l.resultThreeHu,
};

// Sichuan's fan, by mahjong_core's English identifier.
final Map<String, String Function(AppLocalizations)> _sichuanNames = {
  'Root': (l) => l.scRoot,
  'All Pungs': (l) => l.scAllPungs,
  'Full Flush': (l) => l.scFullFlush,
  'Seven Pairs': (l) => l.scSevenPairs,
  'Golden Single Wait': (l) => l.scGoldenSingleWait,
  'Win after Kong': (l) => l.scWinAfterKong,
  'Robbing the Kong': (l) => l.scRobbingTheKong,
  'Shoot after Kong': (l) => l.scShootAfterKong,
  'Under the Sea': (l) => l.scUnderTheSea,
};

// MCR's 81 fan (Appendix 1 order), by mahjong_core's English identifier,
// and the scorer's line for one melded plus one concealed kong.
final Map<String, String Function(AppLocalizations)> _mcrNames = {
  'Big Four Winds': (l) => l.mcrFanBigFourWinds,
  'Big Three Dragons': (l) => l.mcrFanBigThreeDragons,
  'All Green': (l) => l.mcrFanAllGreen,
  'Nine Gates': (l) => l.mcrFanNineGates,
  'Four Kongs': (l) => l.mcrFanFourKongs,
  'Seven Shifted Pairs': (l) => l.mcrFanSevenShiftedPairs,
  'Thirteen Orphans': (l) => l.mcrFanThirteenOrphans,
  'All Terminals': (l) => l.mcrFanAllTerminals,
  'Little Four Winds': (l) => l.mcrFanLittleFourWinds,
  'Little Three Dragons': (l) => l.mcrFanLittleThreeDragons,
  'All Honors': (l) => l.mcrFanAllHonors,
  'Four Concealed Pungs': (l) => l.mcrFanFourConcealedPungs,
  'Pure Terminal Chows': (l) => l.mcrFanPureTerminalChows,
  'Quadruple Chow': (l) => l.mcrFanQuadrupleChow,
  'Four Pure Shifted Pungs': (l) => l.mcrFanFourPureShiftedPungs,
  'Four Shifted Chows': (l) => l.mcrFanFourShiftedChows,
  'Three Kongs': (l) => l.mcrFanThreeKongs,
  'All Terminals and Honors': (l) => l.mcrFanAllTerminalsAndHonors,
  'Seven Pairs': (l) => l.mcrFanSevenPairs,
  'Greater Honors and Knitted Tiles': (l) =>
      l.mcrFanGreaterHonorsAndKnittedTiles,
  'All Even Pungs': (l) => l.mcrFanAllEvenPungs,
  'Full Flush': (l) => l.mcrFanFullFlush,
  'Pure Triple Chow': (l) => l.mcrFanPureTripleChow,
  'Pure Shifted Pungs': (l) => l.mcrFanPureShiftedPungs,
  'Upper Tiles': (l) => l.mcrFanUpperTiles,
  'Middle Tiles': (l) => l.mcrFanMiddleTiles,
  'Lower Tiles': (l) => l.mcrFanLowerTiles,
  'Pure Straight': (l) => l.mcrFanPureStraight,
  'Three-Suited Terminal Chows': (l) => l.mcrFanThreeSuitedTerminalChows,
  'Pure Shifted Chows': (l) => l.mcrFanPureShiftedChows,
  'All Fives': (l) => l.mcrFanAllFives,
  'Triple Pung': (l) => l.mcrFanTriplePung,
  'Three Concealed Pungs': (l) => l.mcrFanThreeConcealedPungs,
  'Lesser Honors and Knitted Tiles': (l) => l.mcrFanLesserHonorsAndKnittedTiles,
  'Knitted Straight': (l) => l.mcrFanKnittedStraight,
  'Upper Four': (l) => l.mcrFanUpperFour,
  'Lower Four': (l) => l.mcrFanLowerFour,
  'Big Three Winds': (l) => l.mcrFanBigThreeWinds,
  'Mixed Straight': (l) => l.mcrFanMixedStraight,
  'Reversible Tiles': (l) => l.mcrFanReversibleTiles,
  'Mixed Triple Chow': (l) => l.mcrFanMixedTripleChow,
  'Mixed Shifted Pungs': (l) => l.mcrFanMixedShiftedPungs,
  'Chicken Hand': (l) => l.mcrFanChickenHand,
  'Last Tile Draw': (l) => l.mcrFanLastTileDraw,
  'Last Tile Claim': (l) => l.mcrFanLastTileClaim,
  'Out with Replacement Tile': (l) => l.mcrFanOutWithReplacementTile,
  'Robbing the Kong': (l) => l.mcrFanRobbingTheKong,
  'Two Concealed Kongs': (l) => l.mcrFanTwoConcealedKongs,
  'All Pungs': (l) => l.mcrFanAllPungs,
  'Half Flush': (l) => l.mcrFanHalfFlush,
  'Mixed Shifted Chows': (l) => l.mcrFanMixedShiftedChows,
  'All Types': (l) => l.mcrFanAllTypes,
  'Melded Hand': (l) => l.mcrFanMeldedHand,
  'Two Dragon Pungs': (l) => l.mcrFanTwoDragonPungs,
  'Outside Hand': (l) => l.mcrFanOutsideHand,
  'Fully Concealed': (l) => l.mcrFanFullyConcealed,
  'Two Melded Kongs': (l) => l.mcrFanTwoMeldedKongs,
  'Last Tile': (l) => l.mcrFanLastTile,
  'Dragon Pung': (l) => l.mcrFanDragonPung,
  'Prevalent Wind': (l) => l.mcrFanPrevalentWind,
  'Seat Wind': (l) => l.mcrFanSeatWind,
  'Concealed Hand': (l) => l.mcrFanConcealedHand,
  'All Chows': (l) => l.mcrFanAllChows,
  'Tile Hog': (l) => l.mcrFanTileHog,
  'Double Pung': (l) => l.mcrFanDoublePung,
  'Two Concealed Pungs': (l) => l.mcrFanTwoConcealedPungs,
  'Concealed Kong': (l) => l.mcrFanConcealedKong,
  'All Simples': (l) => l.mcrFanAllSimples,
  'Pure Double Chow': (l) => l.mcrFanPureDoubleChow,
  'Mixed Double Chow': (l) => l.mcrFanMixedDoubleChow,
  'Short Straight': (l) => l.mcrFanShortStraight,
  'Two Terminal Chows': (l) => l.mcrFanTwoTerminalChows,
  'Pung of Terminals or Honors': (l) => l.mcrFanPungOfTerminalsOrHonors,
  'Melded Kong': (l) => l.mcrFanMeldedKong,
  'One Voided Suit': (l) => l.mcrFanOneVoidedSuit,
  'No Honors': (l) => l.mcrFanNoHonors,
  'Edge Wait': (l) => l.mcrFanEdgeWait,
  'Closed Wait': (l) => l.mcrFanClosedWait,
  'Single Wait': (l) => l.mcrFanSingleWait,
  'Self-Drawn': (l) => l.mcrFanSelfDrawn,
  'Flower Tiles': (l) => l.mcrFanFlowerTiles,
  'Melded and Concealed Kongs': (l) => l.mcrFanMeldedAndConcealedKongs,
};

final Map<String, String Function(AppLocalizations)> _limitNames = {
  'Mangan': (l) => l.limitMangan,
  'Haneman': (l) => l.limitHaneman,
  'Baiman': (l) => l.limitBaiman,
  'Sanbaiman': (l) => l.limitSanbaiman,
  'Kazoe Yakuman': (l) => l.limitKazoeYakuman,
  'Yakuman': (l) => l.limitYakuman,
  '13+ faan cap': (l) => l.limit13FaanCap,
};

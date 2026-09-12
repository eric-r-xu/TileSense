import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/meld.dart';
import 'package:tilesense/logic/tile.dart';
import 'helpers.dart';

EfficiencyValueContext hkContext(
        {List<Meld> melds = const [],
        List<TileType> flowers = const [],
        int wall = 60,
        PlayStyle style = PlayStyle.balanced,
        HandFocus focus = HandFocus.balanced,
        bool legacy = false,
        Wind seat = Wind.south}) =>
    EfficiencyValueContext(
        melds: melds,
        roundWind: Wind.east,
        seatWind: seat,
        isDealer: seat == Wind.east,
        inRiichi: legacy,
        wallTilesRemaining: wall,
        doraIndicators: legacy ? [TileType.man1] : [],
        honba: legacy ? 3 : 0,
        riichiSticks: legacy ? 4 : 0,
        flowers: flowers,
        style: style,
        focus: focus);

EfficiencyReport hkReport(String spec,
    {int wall = 60,
    bool threat = false,
    bool legacy = false,
    PlayStyle style = PlayStyle.balanced,
    HandFocus focus = HandFocus.balanced,
    List<Meld> melds = const [],
    List<TileType> flowers = const [],
    Wind seat = Wind.south}) {
  final hand = parseTiles(spec);
  final visible = toCounts34(hand);
  for (final m in melds) {
    for (final t in m.types) {
      visible[t.index - 1]++;
    }
  }
  return EfficiencyEngine().analyze(
      hand: hand,
      visibleCounts34: visible,
      canRiichi: legacy,
      opponentRiichi: threat,
      defenseHand: threat ? hand : null,
      opponentDiscards: legacy ? [TileType.man1] : [],
      valueContext: hkContext(
          wall: wall,
          legacy: legacy,
          style: style,
          focus: focus,
          melds: melds,
          flowers: flowers,
          seat: seat));
}

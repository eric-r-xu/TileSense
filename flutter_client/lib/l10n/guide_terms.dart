import '../logic/efficiency_engine.dart' show HandFocus, PlayStyle, Strategy;
import 'app_localizations.dart';

extension GuideTerms on AppLocalizations {
  String playStyleName(PlayStyle style) => switch (style) {
        PlayStyle.defensive => tipDefensive,
        PlayStyle.balanced => tipBalanced,
        PlayStyle.aggressive => tipAggressive,
      };

  String handFocusName(HandFocus focus) => switch (focus) {
        HandFocus.speed => tipSpeed,
        HandFocus.balanced => tipBalanced,
      };

  String strategyName(Strategy strategy) => switch (strategy) {
        Strategy.points => tipPoints,
        Strategy.placement => tipPlacementLabel,
      };
}

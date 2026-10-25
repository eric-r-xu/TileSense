/// Which rules the daily quiz has puzzles for. Apart from the quiz itself so
/// the welcome screen can ask without loading the quiz's code.
library;

import 'package:mahjong_core/ruleset.dart';

/// The rules the daily quiz has puzzles for. Any other ruleset's quiz is
/// [kQuizFallback]'s, until it has a pool of its own.
const Set<Ruleset> kQuizRulesets = {Ruleset.riichi, Ruleset.hongKong};

/// The rules a ruleset without puzzles of its own gets its quiz in.
const Ruleset kQuizFallback = Ruleset.riichi;

/// Whether [ruleset] has a daily quiz at all. Sanma has none: riichi's
/// puzzles are four-player tables, and a sanma pool would need its own.
bool hasDailyQuiz(Ruleset ruleset) => !ruleset.isSanma;

/// The rules [ruleset]'s daily quiz is posed in. Only asked of rules that
/// [hasDailyQuiz].
Ruleset quizRulesetFor(Ruleset ruleset) =>
    kQuizRulesets.contains(ruleset) ? ruleset : kQuizFallback;

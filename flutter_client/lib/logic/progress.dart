/// How far along a player is, and what to suggest next. Counts the hands you
/// win at the offline table and, once enough have been won, offers one
/// suggestion at a time for making the game harder: the full guide, a higher
/// minimum, another ruleset. A suggestion only ever asks; it changes nothing
/// until it is accepted, and each is offered once.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mahjong_core/ruleset.dart';

import '../telemetry/src/platform_web.dart'
    if (dart.library.io) '../telemetry/src/platform_stub.dart' as platform;

/// The wins after which each suggestion is first offered.
const int kFullGuideWins = 3;
const int kHigherMinimumWins = 5;
const int kNewRulesetWins = 10;

enum Nudge {
  /// Switch the guide from its simple view to the full table.
  fullGuide,

  /// Play Hong Kong with a 1 faan minimum instead of 0.
  higherMinimum,

  /// Try the next ruleset along.
  newRuleset,
}

/// What a player has done so far, and which suggestions are used up.
class Progress {
  const Progress({
    this.wins = 0,
    this.hands = 0,
    this.done = const {},
    this.muted = false,
    this.quizDay,
    this.quizStreak = 0,
    this.quizBest = 0,
    this.quizCorrect = false,
  });

  /// Hands you won, with nobody playing your seat.
  final int wins;

  /// Hands you played to the end.
  final int hands;

  /// Suggestions already accepted or dismissed.
  final Set<Nudge> done;

  /// True once the player asked not to be given suggestions.
  final bool muted;

  /// The calendar day (`2026-10-20`, local) the daily quiz was last answered,
  /// or null if never.
  final String? quizDay;

  /// Days in a row the daily quiz has been answered, as of [quizDay].
  final int quizStreak;

  /// The longest [quizStreak] there has been.
  final int quizBest;

  /// Whether the answer on [quizDay] was right.
  final bool quizCorrect;

  /// The quiz's streak as it stands on [day]: kept while today's or
  /// yesterday's puzzle was answered, since today's can still be, and lost
  /// after a day missed.
  int quizStreakOn(DateTime day) =>
      quizDay == dayKey(day) || quizDay == dayKey(_before(day))
          ? quizStreak
          : 0;

  /// Whether today's puzzle has been answered.
  bool quizAnsweredOn(DateTime day) => quizDay == dayKey(day);

  Progress copyWith({
    int? wins,
    int? hands,
    Set<Nudge>? done,
    bool? muted,
    String? quizDay,
    int? quizStreak,
    int? quizBest,
    bool? quizCorrect,
  }) =>
      Progress(
        wins: wins ?? this.wins,
        hands: hands ?? this.hands,
        done: done ?? this.done,
        muted: muted ?? this.muted,
        quizDay: quizDay ?? this.quizDay,
        quizStreak: quizStreak ?? this.quizStreak,
        quizBest: quizBest ?? this.quizBest,
        quizCorrect: quizCorrect ?? this.quizCorrect,
      );

  String toJson() => jsonEncode({
        'wins': wins,
        'hands': hands,
        'done': [for (final n in done) n.name],
        'muted': muted,
        if (quizDay != null) 'quizDay': quizDay,
        'quizStreak': quizStreak,
        'quizBest': quizBest,
        'quizCorrect': quizCorrect,
      });

  /// A saved record; anything unreadable is a fresh one.
  static Progress fromJson(String? text) {
    if (text == null) return const Progress();
    try {
      final m = jsonDecode(text) as Map<String, dynamic>;
      return Progress(
        wins: (m['wins'] as num?)?.toInt() ?? 0,
        hands: (m['hands'] as num?)?.toInt() ?? 0,
        done: {
          for (final name in (m['done'] as List?) ?? const [])
            for (final n in Nudge.values)
              if (n.name == name) n,
        },
        muted: m['muted'] == true,
        quizDay: m['quizDay'] as String?,
        quizStreak: (m['quizStreak'] as num?)?.toInt() ?? 0,
        quizBest: (m['quizBest'] as num?)?.toInt() ?? 0,
        quizCorrect: m['quizCorrect'] == true,
      );
    } catch (_) {
      return const Progress();
    }
  }
}

/// A local calendar day as `2026-10-20`, the key the quiz's days are kept by.
String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _before(DateTime d) => DateTime(d.year, d.month, d.day - 1);

/// The ruleset a "try something new" suggestion points at from [current], or
/// null when there is no natural next step.
Ruleset? nextRuleset(Ruleset current) => switch (current) {
      Ruleset.hongKong => Ruleset.taiwanese,
      Ruleset.taiwanese => Ruleset.riichi,
      _ => null,
    };

/// The suggestion to offer now, if any: the first of the three whose wins are
/// in and which still makes sense for what is selected on the menu.
Nudge? dueNudge(
  Progress p, {
  required bool simpleGuide,
  required Ruleset ruleset,
  required int minimumFaan,
}) {
  if (p.muted) return null;
  bool open(Nudge n, int wins) => p.wins >= wins && !p.done.contains(n);
  if (open(Nudge.fullGuide, kFullGuideWins) && simpleGuide) {
    return Nudge.fullGuide;
  }
  if (open(Nudge.higherMinimum, kHigherMinimumWins) &&
      ruleset.isHongKong &&
      minimumFaan == 0) {
    return Nudge.higherMinimum;
  }
  if (open(Nudge.newRuleset, kNewRulesetWins) && nextRuleset(ruleset) != null) {
    return Nudge.newRuleset;
  }
  return null;
}

/// The one record this device keeps. It lives in memory and is written to the
/// device's `localStorage` on every change, so on the web it survives a reload;
/// elsewhere there is no storage and it lasts for the session.
class ProgressStore extends ChangeNotifier {
  ProgressStore({
    String? Function(String key)? read,
    void Function(String key, String value)? write,
  })  : _write = write ?? platform.localStorageSet,
        _value =
            Progress.fromJson((read ?? platform.localStorageGet)(storageKey));

  static const storageKey = 'ts_progress';

  /// The one the app uses.
  static ProgressStore instance = ProgressStore();

  /// Whether the menu offers suggestions at all. Tests that open the menu
  /// turn this off, so a win counted by an earlier test can't add a card.
  static bool nudgesEnabled = true;

  final void Function(String key, String value) _write;
  Progress _value;

  Progress get value => _value;

  void _set(Progress next) {
    _value = next;
    _write(storageKey, next.toJson());
    notifyListeners();
  }

  /// A hand ended at the offline table. [won] is true only for a hand you won
  /// yourself, with no Auto-Play in it.
  void recordHand({required bool won}) => _set(_value.copyWith(
      hands: _value.hands + 1, wins: _value.wins + (won ? 1 : 0)));

  /// The daily quiz was answered on [day]. Only the first answer of a day
  /// counts: it extends the streak when yesterday's was answered too, and
  /// starts a new one otherwise.
  void recordQuiz(DateTime day, {required bool correct}) {
    final p = _value;
    if (p.quizAnsweredOn(day)) return;
    final streak = p.quizStreakOn(day) + 1;
    _set(p.copyWith(
      quizDay: dayKey(day),
      quizStreak: streak,
      quizBest: streak > p.quizBest ? streak : p.quizBest,
      quizCorrect: correct,
    ));
  }

  /// A suggestion was accepted or dismissed, so it is not offered again.
  void finish(Nudge n) => _set(_value.copyWith(done: {..._value.done, n}));

  /// Stop all suggestions.
  void mute() => _set(_value.copyWith(muted: true));
}

import 'package:flutter/foundation.dart';
import 'package:mahjong_core/game_timing.dart';

/// The all-caps speech bubble that flashes beside a seat's portrait when its
/// player calls chi / pon / kan / ron / tsumo.
///
/// A process-wide singleton, like [Sfx], because the calls are announced from
/// the game controllers (offline and online) while the bubble is drawn by
/// `TableView`; neither owns the other. Sound and text are independent: the
/// bubble shows whether or not the sound is on.
///
/// This only records *that* a call happened; the bubble widget owns the 1.29s
/// [flash] timer, so a controller announcing a call outside any widget tree
/// (tests, headless) leaves no timer behind.
class CallCallout extends ChangeNotifier {
  CallCallout._();
  static final CallCallout i = CallCallout._();

  /// How long a bubble stays up.
  static const Duration flash = kCallPause;

  DateTime? _lastAt;

  /// How much of the current flash is left (zero when none is showing).
  /// The game loop and the score panel wait this long, so play holds still
  /// while a call is on screen.
  Duration get remaining {
    final at = _lastAt;
    if (at == null) return Duration.zero;
    final left = flash - DateTime.now().difference(at);
    return left.isNegative ? Duration.zero : left;
  }

  int _nextId = 0;
  final Map<int, ({int id, String text})> _latest = {};

  /// The most recent call at [seat] — a new [id] for every announcement, so a
  /// repeat of the same word still re-triggers the flash.
  ({int id, String text})? latest(int seat) => _latest[seat];

  /// Announce [text] (upper-cased) for [seat]. Seats are independent, so a
  /// double ron flashes both bubbles at once.
  void show(int seat, String text) {
    _lastAt = DateTime.now();
    _latest[seat] = (id: ++_nextId, text: text.toUpperCase());
    notifyListeners();
  }

  /// Forget the current flash. [remaining] reads the wall clock, which a
  /// widget test's fake clock cannot advance, so a test that wants a
  /// no-call-in-progress start has to say so explicitly.
  @visibleForTesting
  void clear() {
    _lastAt = null;
    _latest.clear();
  }
}

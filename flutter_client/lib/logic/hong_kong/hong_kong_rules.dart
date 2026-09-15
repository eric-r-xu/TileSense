/// Rules from HKMJ Cheat Sheet 1.0 (April 3, 2025), with a zero-faan minimum.
library;

class HongKongRules {
  /// A complete hand scoring fewer faan than this cannot be declared. Zero
  /// makes every complete hand, including a chicken hand, a legal win.
  static const minimumFaan = 0;

  /// Faan at which the payment table stops rising.
  static const limitFaan = 13;

  /// Seven Pairs is a variant rule on the sheet; it is played here.
  static const sevenPairs = true;

  /// Chips every seat starts a game with.
  static const startingChips = 1000;

  /// The New Style table, indexed by faan up to [limitFaan].
  static const paymentTable = [
    1, 2, 4, 8, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384, //
  ];

  static int basePoints(int faan) {
    if (faan < 0) throw ArgumentError.value(faan, 'faan');
    return paymentTable[faan.clamp(0, limitFaan)];
  }
}

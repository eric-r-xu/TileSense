/// Rules from HKMJ Cheat Sheet 1.0 (April 3, 2025), with a zero-faan minimum.
class HongKongRules {
  static const minimumFaan = 0;
  static const limitFaan = 13;
  static const sevenPairs = true;
  static const paymentTable = [
    1,
    2,
    4,
    8,
    16,
    24,
    32,
    48,
    64,
    96,
    128,
    192,
    256,
    384
  ];
  static int basePoints(int faan) {
    if (faan < 0) throw ArgumentError.value(faan, 'faan');
    return paymentTable[faan.clamp(0, limitFaan)];
  }
}

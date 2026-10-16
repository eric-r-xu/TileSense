/// Sichuan "Bloody Rules" (SBR) mahjong, from the Simple Basic Rules quick
/// reference on mahjongpictureguide.com: 108 suit tiles, a voided suit chosen
/// by every seat, no chows off a discard, and a "bloody battle" in which a
/// seat that has declared Hu stops playing while the others carry on until
/// three have won or the wall runs out. See docs/SICHUAN_RULES.md.
library;

class SichuanRules {
  /// Every seat starts a game on zero; the unit is points.
  static const startingPoints = 0;

  /// Tiles in the wall: three suits of nine, four copies each.
  static const wallSize = 108;

  /// Hand value (points) for [fan]: 0 -> 1, 1 -> 2, 2 -> 4, 3 or more -> 8.
  static int handValue(int fan) => fan >= 3 ? 8 : 1 << (fan < 0 ? 0 : fan);

  /// A self-drawn Hu pays the hand value plus this, from each non-Hu seat.
  static const selfDrawBonus = 1;

  /// Kong payments, in points: a concealed kong and an open kong off a
  /// discard are worth 2 each; an added (small melded) kong is worth 1.
  static const concealedKongPayment = 2;
  static const meldedKongPayment = 2;
  static const addedKongPayment = 1;

  /// Paid to every other seat by a seat that finishes still holding voided-suit
  /// tiles after discarding something else.
  static const voidedSuitPenalty = 48;
}

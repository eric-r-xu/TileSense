import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/safety.dart';
import 'package:tilesense/logic/tile.dart';
import 'helpers.dart';

void main() {
  test('discarded and passed tiles have no immunity', () {
    final hand = parseTiles('1m 4m EE');
    List<SafetyRating> rate(List<TileType> pond, List<TileType> passed) =>
        rankSafety(hand,
            opponentDiscards: pond,
            passedDiscardsAfterRiichi: passed,
            visibleCounts34: toCounts34(hand));
    final plain = rate([], []);
    final history = rate([TileType.man1, TileType.man4], [TileType.ton]);
    expect(history.map((r) => r.rating), plain.map((r) => r.rating));
    expect(history.any((r) => r.isSafe), isFalse);
    expect(history.any((r) => r.label.toLowerCase().contains('suji')), isFalse);
  });
  test('more visible honor copies reduce ordinary pair/pung risk', () {
    final hand = parseTiles('E');
    int rating(int visible) => rankSafety(hand,
            opponentDiscards: [],
            passedDiscardsAfterRiichi: [],
            visibleCounts34: List.filled(34, 0)..[27] = visible)
        .single
        .rating;
    expect(rating(4), greaterThan(rating(3)));
    expect(rating(3), greaterThan(rating(1)));
    expect(rating(4), lessThan(15), reason: 'Thirteen Orphans still possible');
  });
  test('safety is deduplicated and sorted', () {
    final hand = parseTiles('11m 55p EE');
    final ratings = rankSafety(hand,
        opponentDiscards: [],
        passedDiscardsAfterRiichi: [],
        visibleCounts34: toCounts34(hand));
    expect(ratings, hasLength(3));
    for (var i = 1; i < ratings.length; i++) {
      expect(ratings[i].rating, lessThanOrEqualTo(ratings[i - 1].rating));
    }
  });
}

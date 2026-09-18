import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/app_update.dart';

void main() {
  test('same build id is up to date', () {
    expect(compareBuildIds('20260918', '20260918'), UpdateStatus.upToDate);
  });

  test('different build id is an update', () {
    expect(compareBuildIds('20260918', '20260919'),
        UpdateStatus.updateAvailable);
  });

  test('missing ids are inconclusive, never a false update', () {
    expect(compareBuildIds('', '20260919'), UpdateStatus.unknown);
    expect(compareBuildIds('20260918', null), UpdateStatus.unknown);
    expect(compareBuildIds('20260918', ''), UpdateStatus.unknown);
  });

  test('the button is web-only', () {
    expect(updateButtonVisible, isFalse);
  });
}

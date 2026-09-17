import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/ui/character_picker.dart';

void main() {
  testWidgets('all characters remain selectable in a narrow dialog',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Character? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AlertDialog(
          content: SizedBox(
            width: 340,
            child: CharacterRow(
              options: kSelectableCharacters,
              selected: Character.eric,
              onSelect: (value) => picked = value,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final character in kSelectableCharacters) {
      await tester.tap(find.text(kCharacterName[character]!));
      expect(picked, character);
    }
  });

  testWidgets('every portrait and voice is packaged in the asset bundle',
      (tester) async {
    for (final character in Character.values) {
      final portrait = await rootBundle.load(kCharacterPortrait[character]!);
      expect(portrait.lengthInBytes, greaterThan(0));
      for (final kind in VoiceKind.values) {
        final path = Sfx.debugAssetFor(character, kind);
        expect(path, isNotNull, reason: '${character.name}: ${kind.name}');
        final clip = await rootBundle.load('assets/$path');
        expect(clip.lengthInBytes, greaterThan(44));
        expect(String.fromCharCodes(clip.buffer.asUint8List(0, 4)), 'RIFF');
      }
    }
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/ui/phone_menu.dart';

/// Every label in the open phone menu is shown whole: inside its button,
/// never ellipsised, and never split mid-word unless it is already as small
/// as it is allowed to get (a test font is wider than a real one, so a long
/// Latin word can reach that floor here when it would not on a device).
void expectPhoneMenuLabelsWhole(WidgetTester tester) {
  final labels = find.descendant(
      of: find.byType(BottomSheet), matching: find.byType(PhoneMenuLabel));
  final count = labels.evaluate().length;
  expect(count, greaterThan(0));
  for (var i = 0; i < count; i++) {
    final label = labels.at(i);
    final widget = tester.widget<PhoneMenuLabel>(label);
    final reason = '"${widget.text}"';
    final text = tester
        .widget<Text>(find.descendant(of: label, matching: find.byType(Text)));
    final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: label, matching: find.byType(RichText)));

    expect(paragraph.didExceedMaxLines, isFalse, reason: '$reason is clipped');
    final wordFits =
        paragraph.getMinIntrinsicWidth(double.infinity) <= paragraph.size.width + 0.5;
    expect(wordFits || text.style!.fontSize! <= widget.minFontSize + 0.01,
        isTrue,
        reason: '$reason is split mid-word above its smallest size');

    final buttons = find.ancestor(
        of: label, matching: find.byWidgetPredicate((w) => w is OutlinedButton));
    if (buttons.evaluate().isNotEmpty) {
      final button = tester.getRect(buttons.first).inflate(0.5);
      final box = tester.getRect(label);
      expect(button.contains(box.topLeft) && button.contains(box.bottomRight),
          isTrue,
          reason: '$reason $box sticks out of its button $button');
    }
  }
}

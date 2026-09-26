/// One portrait-and-name option in a group of [Character] choices — shared by
/// the online lobby's "choose your character" picker and the offline
/// welcome screen's per-seat picker, so both look and behave identically.
library;

import 'package:flutter/material.dart';

import '../game/sfx.dart' show Character, kCharacterName, kCharacterPortrait;

/// Every character in [options], in a grid with [columns] choices per row.
class CharacterRow extends StatelessWidget {
  const CharacterRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.keyPrefix,
    this.columns = 4,
  }) : assert(columns > 0);

  final List<Character> options;
  final Character selected;
  final ValueChanged<Character> onSelect;

  /// Prefixes each option's [Key] (`'${keyPrefix}_${character.name}'`) so a
  /// screen with more than one row — one per seat — can address them by
  /// widget key without collisions. Left unkeyed when null.
  final String? keyPrefix;

  /// Narrow dialogs use four; the wider offline seat cards use five.
  final int columns;

  @override
  Widget build(BuildContext context) {
    // Each cell takes an equal share of the row and scales its option down
    // if that share is ever narrower than the option (a tight dialog), so a
    // row never overflows and every character stays tappable.
    Widget cell(Character? c) => Expanded(
          child: c == null
              ? const SizedBox.shrink()
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: CharacterOption(
                    character: c,
                    selected: c == selected,
                    onTap: () => onSelect(c),
                    optionKey: keyPrefix == null
                        ? null
                        : Key('${keyPrefix}_${c.name}'),
                  ),
                ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < options.length; i += columns) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            // Top-aligned so every portrait in a row sits level.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = i; j < i + columns; j++)
                cell(j < options.length ? options[j] : null),
            ],
          ),
        ],
      ],
    );
  }
}

/// One portrait + name, highlighted when [selected].
class CharacterOption extends StatelessWidget {
  const CharacterOption({
    super.key,
    required this.character,
    required this.selected,
    required this.onTap,
    this.optionKey,
  });

  final Character character;
  final bool selected;
  final VoidCallback onTap;

  /// The key on the tappable region itself, distinct from this widget's own
  /// [Key] (`key`) so [CharacterRow] can pass one through per option.
  final Key? optionKey;

  static const double width = 64;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: GestureDetector(
          key: optionKey,
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xff0c4747),
                  border: Border.all(
                    color: selected ? const Color(0xffcaa24e) : Colors.white24,
                    width: selected ? 3 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  kCharacterPortrait[character]!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 4),
              // One line, shrunk to fit: a long name (Matityahu) wrapping to
              // two would make its cell taller than the rest of the row.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  kCharacterName[character]!,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color:
                        selected ? const Color(0xffffdf76) : Colors.white70,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 10.56,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// One portrait-and-name option in a row of [Character] choices — shared by
/// the online lobby's "choose your character" picker and the offline
/// welcome screen's per-seat picker, so both look and behave identically.
library;

import 'package:flutter/material.dart';

import '../game/sfx.dart' show Character, kCharacterName, kCharacterPortrait;

/// A row of every character in [options], the current one highlighted.
class CharacterRow extends StatelessWidget {
  const CharacterRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.keyPrefix,
  });

  final List<Character> options;
  final Character selected;
  final ValueChanged<Character> onSelect;

  /// Prefixes each option's [Key] (`'${keyPrefix}_${character.name}'`) so a
  /// screen with more than one row — one per seat — can address them by
  /// widget key without collisions. Left unkeyed when null.
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final c in options)
            CharacterOption(
              character: c,
              selected: c == selected,
              onTap: () => onSelect(c),
              optionKey:
                  keyPrefix == null ? null : Key('${keyPrefix}_${c.name}'),
            ),
        ],
      );
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

  @override
  Widget build(BuildContext context) => Expanded(
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
                    color:
                        selected ? const Color(0xffcaa24e) : Colors.white24,
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
              Text(
                kCharacterName[character]!,
                style: TextStyle(
                  color: selected ? const Color(0xffffdf76) : Colors.white70,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
}

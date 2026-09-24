/// The intermediary screen between the welcome screen and the offline table /
/// the Custom Hand & Context Builder: who sits at each wind.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart' show Wind;

import '../game/sfx.dart'
    show Character, kCharacterName, kCharacterPortrait, kSelectableCharacters;
import 'character_picker.dart';

/// The wind [seat] starts on when [startingDealer] deals first (and so is
/// East); the other seats follow counter-clockwise, as in `Round`.
Wind seatStartingWind(int seat, int startingDealer) =>
    Wind.values[(seat - startingDealer + 4) % 4];

/// Where each seat sits relative to the human, by seat index. With the human
/// as East, "Across" is West.
const List<String> kSeatPositionNames = ['You', 'Right', 'Across', 'Left'];

/// A fresh draw of four distinct characters, in random order — which changes
/// who each seat plays as, and so where every character sits, in one go.
List<Character> randomSeatCharacters([Random? random]) {
  final pool = List.of(kSelectableCharacters)..shuffle(random);
  return pool.take(kSeatPositionNames.length).toList();
}

/// A random seat to deal first — i.e. a random wind for the human to start on.
int randomStartingDealer([Random? random]) =>
    (random ?? Random()).nextInt(kSeatPositionNames.length);

/// One big card per seat — wind, position, portrait, name and the picker — a
/// chooser for the wind you start on, a Randomize button, and an advance
/// button below.
class CharacterSelectPage extends StatelessWidget {
  const CharacterSelectPage({
    super.key,
    required this.seatCharacters,
    required this.onSeatCharacter,
    required this.startingDealer,
    required this.onStartingDealer,
    required this.onRandomize,
    required this.soundOn,
    required this.onSoundOn,
    required this.hanchan,
    required this.onHanchan,
    required this.onAdvance,
    required this.onBack,
    required this.advanceLabel,
    this.ruleset,
    this.onRuleset,
  });

  /// The style to play, pre-selected from the welcome screen's choice and
  /// still changeable here. Null [onRuleset] hides the picker. Once the game
  /// is under way the style is fixed — going back to the menu is the only way
  /// to change it.
  final Ruleset? ruleset;
  final ValueChanged<Ruleset>? onRuleset;

  /// Every seat's persona, index 0 being the human seat.
  final List<Character> seatCharacters;
  final void Function(int seat, Character character) onSeatCharacter;

  /// The seat that deals first and is therefore East; the human is seat 0, so
  /// this is what decides which wind you start on.
  final int startingDealer;
  final ValueChanged<int> onStartingDealer;

  /// Reshuffles the characters and the starting wind together.
  final VoidCallback onRandomize;

  /// The Sound checkbox. Sound is on by default; unchecking turns it off for
  /// the game (and it can still be toggled from the table).
  final bool soundOn;
  final ValueChanged<bool> onSoundOn;

  /// Game length: the full game (hanchan, East + South) when true, East only
  /// when false. Hanchan is the default.
  final bool hanchan;
  final ValueChanged<bool> onHanchan;

  /// Leaves for wherever the player was headed (the table or the builder).
  final VoidCallback onAdvance;
  final VoidCallback onBack;
  final String advanceLabel;

  static const _gold = Color(0xffcaa24e);

  Widget _seatCard(int seat) {
    final character = seatCharacters[seat];
    final wind = seatStartingWind(seat, startingDealer);
    return Container(
      key: Key('seatCard_$seat'),
      // Five 64px choices per row keep the roster and controls on screen.
      width: 344,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x55caa24e)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                wind.kanji,
                key: Key('seatWindKanji_$seat'),
                style: const TextStyle(
                  color: Color(0xffffdf76),
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                wind.label,
                key: Key('seatWind_$seat'),
                style: const TextStyle(
                  color: Color(0xffe9d58f),
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Text(
            seat == 0
                ? kSeatPositionNames[seat].toUpperCase()
                : kSeatPositionNames[seat],
            key: Key('seatPosition_$seat'),
            style: TextStyle(
              color: seat == 0 ? Colors.white : Colors.white54,
              fontSize: 14,
              fontWeight: seat == 0 ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 128,
            height: 128,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xff0c4747),
              border: Border.fromBorderSide(BorderSide(color: _gold, width: 2)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              kCharacterPortrait[character]!,
              key: Key('seatPortrait_$seat'),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            kCharacterName[character]!,
            key: Key('seatCharacterName_$seat'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          CharacterRow(
            options: kSelectableCharacters,
            columns: 5,
            selected: character,
            keyPrefix: 'seatCharacterPick_$seat',
            onSelect: (c) => onSeatCharacter(seat, c),
          ),
        ],
      ),
    );
  }

  /// "You start as: 東 East · 南 South · …" — picking one makes the seat that
  /// many places round from you the dealer, so you are not stuck on East.
  Widget _windChoice() {
    final mine = seatStartingWind(0, startingDealer);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('You start as',
            style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(width: 10),
        for (final w in Wind.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton(
              key: Key('startWind_${w.name}'),
              // You are seat 0, and `wind = (seat - dealer) mod 4`.
              onPressed: () => onStartingDealer((4 - w.index) % 4),
              style: OutlinedButton.styleFrom(
                backgroundColor: w == mine ? const Color(0x33caa24e) : null,
                foregroundColor:
                    w == mine ? const Color(0xffffdf76) : Colors.white54,
                side: BorderSide(
                    color: w == mine ? _gold : Colors.white24,
                    width: w == mine ? 2 : 1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: Text('${w.kanji} ${w.label}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

  /// "Style: 🇯🇵 Riichi · 🇭🇰 Hong Kong · 🇹🇼 Taiwanese", starting on whatever
  /// the welcome screen had selected.
  Widget _rulesetChoice(Ruleset current, ValueChanged<Ruleset> onChange) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Style',
            style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(width: 10),
        for (final r in Ruleset.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton(
              key: Key('startRuleset_${r.name}'),
              onPressed: () => onChange(r),
              style: OutlinedButton.styleFrom(
                backgroundColor: r == current ? const Color(0x33caa24e) : null,
                foregroundColor:
                    r == current ? const Color(0xffffdf76) : Colors.white54,
                side: BorderSide(
                    color: r == current ? _gold : Colors.white24,
                    width: r == current ? 2 : 1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: Text(r.flagLabel,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

  /// "Game length: 半庄 Hanchan · 东风战 East only" — hanchan is the default.
  Widget _lengthChoice() {
    Widget option(Key key, String label, bool value) {
      final on = hanchan == value;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton(
          key: key,
          onPressed: () => onHanchan(value),
          style: OutlinedButton.styleFrom(
            backgroundColor: on ? const Color(0x33caa24e) : null,
            foregroundColor: on ? const Color(0xffffdf76) : Colors.white54,
            side: BorderSide(
                color: on ? _gold : Colors.white24, width: on ? 2 : 1),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Game length',
            style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(width: 10),
        option(const Key('lengthHanchan'), '半庄 Hanchan', true),
        option(const Key('lengthEastOnly'), '东风战 East only', false),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Material ancestor: without one, Text on web can render with a stray
    // underline decoration.
    return Material(
      color: const Color(0xff042020),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'CHOOSE YOUR CHARACTERS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      startingDealer == 0
                          ? 'East deals first — that is you.'
                          : 'East deals first — that is '
                              '${kSeatPositionNames[startingDealer].toLowerCase()}.',
                      key: const Key('dealerNote'),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    _windChoice(),
                    const SizedBox(height: 8),
                    // Style shares the length row: the screen is already
                    // tight against the design canvas's height.
                    if ((ruleset, onRuleset) case (final r?, final set?))
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _rulesetChoice(r, set),
                          const SizedBox(width: 28),
                          _lengthChoice(),
                        ],
                      )
                    else
                      _lengthChoice(),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (var seat = 0; seat < seatCharacters.length; seat++)
                          _seatCard(seat),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('randomizeCharacters'),
                          onPressed: onRandomize,
                          icon: const Icon(Icons.shuffle, size: 18),
                          label: const Text('Randomize characters & seats'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xffe9d58f),
                            side: const BorderSide(color: _gold),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 24),
                        InkWell(
                          key: const Key('soundCheckbox'),
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => onSoundOn(!soundOn),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: soundOn,
                                  onChanged: (v) => onSoundOn(v ?? !soundOn),
                                  activeColor: _gold,
                                  checkColor: Colors.black,
                                  side: const BorderSide(color: Colors.white54),
                                ),
                                Text(
                                  'Sound',
                                  style: TextStyle(
                                    color:
                                        soundOn ? Colors.white : Colors.white54,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      key: const Key('charactersContinue'),
                      onPressed: onAdvance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 14),
                      ),
                      child: Text(
                        advanceLabel,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Overlaid at the top-left rather than given its own row: the screen
          // is tight against the design canvas's height.
          Positioned(
            left: 12,
            top: 12,
            child: TextButton.icon(
              key: const Key('charactersBack'),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xff80cbc4)),
            ),
          ),
        ],
      ),
    );
  }
}

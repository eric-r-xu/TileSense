/// The game bar's controls for a phone, where the bar is drawn at about half
/// size and its tiles end up far too small to tap. The bar folds them all
/// into one Menu button, which opens this sheet.
///
/// The sheet goes on the root navigator, outside the scaled canvas, so it is
/// drawn at the device's real size: every control here is at least 48pt tall.
/// The guide dials show every setting at once rather than cycling on tap, so
/// one tap is always the setting you meant.
library;

import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../logic/efficiency_engine.dart' show HandFocus, PlayStyle, Strategy;
import '../main.dart'
    show handFocusColor, openRules, playStyleColor, strategyColor;

const Color _gold = Color(0xffe9d58f);

Future<void> showPhoneMenu(
  BuildContext context,
  GameController game, {
  required VoidCallback onMainMenu,
  required VoidCallback onNewGame,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff0c3030),
      builder: (sheet) {
        // Closes the sheet first, so whatever the action opens isn't under it.
        VoidCallback closeThen(VoidCallback action) => () {
              Navigator.pop(sheet);
              action();
            };
        return SafeArea(
          child: AnimatedBuilder(
            animation: game,
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Menu',
                          style: TextStyle(
                              color: _gold,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const Spacer(),
                      TextButton(
                        key: const Key('phoneMenuDone'),
                        onPressed: () => Navigator.pop(sheet),
                        child:
                            const Text('Done', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: phoneMenuRows([
                          [
                            phoneMenuAction(
                              key: const Key('phoneMenuPause'),
                              icon:
                                  game.paused ? Icons.play_arrow : Icons.pause,
                              label: game.paused ? 'Resume' : 'Pause',
                              onTap: game.togglePause,
                            ),
                            phoneMenuAction(
                              key: const Key('phoneMenuNewGame'),
                              icon: Icons.add_circle_outline,
                              label: 'New game',
                              onTap: closeThen(onNewGame),
                            ),
                          ],
                          [
                            phoneMenuAction(
                              key: const Key('phoneMenuMainMenu'),
                              icon: Icons.arrow_back,
                              label: 'Main menu',
                              onTap: closeThen(onMainMenu),
                            ),
                            phoneMenuAction(
                              key: const Key('phoneMenuRules'),
                              icon: Icons.menu_book,
                              label: 'Rules',
                              onTap: () => openRules(game.ruleset),
                            ),
                          ],
                          [
                            phoneMenuAction(
                              key: const Key('phoneMenuSound'),
                              icon: game.soundOn
                                  ? Icons.volume_up
                                  : Icons.volume_off,
                              label: game.soundOn ? 'Sound on' : 'Sound off',
                              on: game.soundOn,
                              onTap: () => game.setSoundOn(!game.soundOn),
                            ),
                            phoneMenuAction(
                              key: const Key('phoneMenuSpeed'),
                              icon: Icons.speed,
                              label: game.fastMode ? 'Bots 2x' : 'Bots 1x',
                              on: game.fastMode,
                              onTap: () => game.setFastMode(!game.fastMode),
                            ),
                          ],
                          [
                            phoneMenuAction(
                              key: const Key('phoneMenuLength'),
                              icon: Icons.timelapse,
                              label: game.hanchan ? 'Hanchan' : 'East only',
                              onTap: () => game.setHanchan(!game.hanchan),
                            ),
                          ],
                        ]),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: phoneMenuRows([
                          [
                            phoneMenuAction(
                              key: const Key('phoneMenuAutoplay'),
                              icon: Icons.smart_toy_outlined,
                              label: game.autoplay
                                  ? 'Auto-Play on'
                                  : 'Auto-Play off',
                              on: game.autoplay,
                              onTap: () => game.setAutoplay(!game.autoplay),
                            ),
                          ],
                          // Style and Strategy are hidden under Hong Kong and
                          // Taiwanese rules, as they are in the bar.
                          if (!game.ruleset.isChineseStyle)
                            [
                              phoneMenuDial<PlayStyle>(
                                caption: 'Style',
                                keyPrefix: 'phoneMenuStyle',
                                values: PlayStyle.values,
                                current: game.playStyle,
                                label: (v) => v.label,
                                colour: playStyleColor,
                                onPick: game.setPlayStyle,
                              ),
                            ],
                          [
                            phoneMenuDial<HandFocus>(
                              caption: 'Focus',
                              keyPrefix: 'phoneMenuFocus',
                              values: HandFocus.values,
                              current: game.handFocus,
                              label: (v) => v.label,
                              colour: handFocusColor,
                              onPick: game.setHandFocus,
                            ),
                          ],
                          if (!game.ruleset.isChineseStyle)
                            [
                              phoneMenuDial<Strategy>(
                                caption: 'Strategy',
                                keyPrefix: 'phoneMenuStrategy',
                                values: Strategy.values,
                                current: game.strategy,
                                label: (v) => v.label,
                                colour: strategyColor,
                                onPick: game.setStrategy,
                              ),
                            ],
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

/// A phone's Menu: under the right thumb, mirroring the guide button under
/// the left, and square enough to clear 44pt each way on a phone. Says when
/// the game is [paused], since the phone's bar has no Pause of its own.
class PhoneMenuButton extends StatelessWidget {
  const PhoneMenuButton({super.key, required this.onTap, this.paused = false});

  final VoidCallback onTap;
  final bool paused;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const Key('phoneMenu'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 120,
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0x14ffffff),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffcaa24e), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.menu, size: 40, color: _gold),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(paused ? 'PAUSED' : 'MENU',
                      style: const TextStyle(
                          color: _gold,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Rows of equal-width controls, 8pt apart each way.
Widget phoneMenuRows(List<List<Widget>> rows) => Column(
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (final (j, cell) in row.indexed) ...[
                if (j > 0) const SizedBox(width: 8),
                Expanded(child: cell),
              ],
            ],
          ),
        ],
      ],
    );

/// A 48pt button; [on] lights it gold for a toggle that is switched on.
Widget phoneMenuAction({
  required Key key,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  bool on = false,
}) =>
    SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        key: key,
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15)),
        style: OutlinedButton.styleFrom(
          foregroundColor: on ? _gold : Colors.white,
          backgroundColor: on ? const Color(0x33caa24e) : null,
          side: BorderSide(color: on ? _gold : Colors.white30),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );

/// A guide dial with every setting showing, the current one lit in its own
/// colour. Each setting's label carries `'${keyPrefix}_${value.name}'` — or
/// `'${keyPrefix}_$value'` for a number.
Widget phoneMenuDial<T extends Object>({
  required String caption,
  required String keyPrefix,
  required List<T> values,
  required T current,
  required String Function(T) label,
  required Color Function(T) colour,
  required ValueChanged<T> onPick,
}) =>
    Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(caption,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        Expanded(
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            segments: [
              for (final v in values)
                ButtonSegment(
                  value: v,
                  label: Text(label(v),
                      key: Key('${keyPrefix}_${v is Enum ? v.name : v}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            selected: {current},
            onSelectionChanged: (s) => onPick(s.single),
            style: SegmentedButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: Colors.white70,
              selectedForegroundColor: colour(current),
              selectedBackgroundColor: colour(current).withValues(alpha: 0.2),
              textStyle: const TextStyle(fontSize: 14),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
        ),
      ],
    );

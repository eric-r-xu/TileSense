/// The Hand Builder's answer for a hand that is already complete: what it is
/// worth, and the choices that change it (which tile won it, and how).
///
/// It stands where the guide's discard table would, because a hand that has
/// won has no discard left to choose.
library;

import 'package:flutter/material.dart';
import 'package:mahjong_core/tile.dart';

import '../game/game_controller.dart' show kHumanSeat;
import '../l10n/l10n.dart';
import '../scenario/scenario.dart';
import '../scenario/scenario_controller.dart';
import 'score_text.dart';
import 'theme.dart';
import 'tile_face.dart';

class ScenarioWinPanel extends StatelessWidget {
  const ScenarioWinPanel({
    super.key,
    required this.controller,
    required this.onEdit,
    required this.maxHeight,
    this.phone = false,
  });

  /// On a phone the chips and tiles are drawn big enough to tap (the canvas
  /// is shown at about half size there).
  final bool phone;

  final ScenarioController controller;

  /// Applies a change to the scenario and re-scores it.
  final void Function(void Function(Scenario s) change) onEdit;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final win = controller.win!;
    final s = controller.scenario;
    final l10n = context.l10n;
    final r = s.ruleset;
    final score = win.score;
    final width =
        (MediaQuery.sizeOf(context).width - 16).clamp(260.0, 480.0).toDouble();
    final human = s.seats[kHumanSeat];
    final closed = !human.melds.any((m) => !m.concealed);
    final riichi = s.riichi || human.riichi;

    final winTypes = <TileType>[
      ...{for (final t in s.hand) t.type}
    ]..sort((a, b) => a.index.compareTo(b.index));

    return Material(
      color: const Color(0xdd031213),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        key: const Key('builderWinPanel'),
        width: width,
        constraints: BoxConstraints(maxHeight: maxHeight.clamp(160.0, 4000.0)),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 18, color: AppColors.goldBright),
                  SizedBox(width: 6),
                  Text('Winning hand',
                      style: TextStyle(
                          color: AppColors.goldBright,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              if (!win.fromOffer) ...[
                _label('How it was won'),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _chip('Tsumo', win.byTsumo, () {
                    onEdit((x) {
                      x.winByTsumo = true;
                      x.chankan = false;
                    });
                  }, key: const Key('winTsumo')),
                  _chip('Ron', !win.byTsumo, () {
                    onEdit((x) {
                      x.winByTsumo = false;
                      x.rinshan = false;
                    });
                  }, key: const Key('winRon')),
                ]),
                const SizedBox(height: 8),
                _label('Winning tile (tap to change)'),
                Wrap(spacing: 4, runSpacing: 4, children: [
                  for (final t in winTypes)
                    InkWell(
                      key: Key('winTile_${t.code}'),
                      onTap: () => onEdit((x) => x.winType = t),
                      child: TileFace(
                        type: t,
                        size: TileSize.small,
                        scale: phone ? 2.0 : 1.0,
                        highlight: win.winTile.type == t,
                        highlightColor: AppColors.right,
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
              ],
              if (r.isJapanese) ...[
                _label('Situation'),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _chip(
                      'Riichi',
                      riichi,
                      closed
                          ? () {
                              onEdit((x) {
                                final on =
                                    !(x.riichi || x.seats[kHumanSeat].riichi);
                                x.riichi = on;
                                if (!on) {
                                  x.seats[kHumanSeat].riichi = false;
                                  x.seats[kHumanSeat].riichiPondIndex = -1;
                                  x.ippatsu = false;
                                }
                              });
                            }
                          : null,
                      key: const Key('winRiichi')),
                  _chip(
                      'Ippatsu',
                      riichi && s.ippatsu,
                      riichi
                          ? () => onEdit((x) => x.ippatsu = !x.ippatsu)
                          : null,
                      key: const Key('winIppatsu')),
                  _chip(
                      'After a kan',
                      win.byTsumo && s.rinshan,
                      win.byTsumo
                          ? () => onEdit((x) => x.rinshan = !x.rinshan)
                          : null,
                      key: const Key('winRinshan')),
                  _chip(
                      'Robbing a kan',
                      !win.byTsumo && s.chankan,
                      win.byTsumo
                          ? null
                          : () => onEdit((x) => x.chankan = !x.chankan),
                      key: const Key('winChankan')),
                ]),
                const SizedBox(height: 4),
                const Text(
                    'Set Wall to 0 in the Menu for the last tile (haitei / houtei).',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 8),
              ],
              const Divider(height: 1, color: Colors.white24),
              const SizedBox(height: 8),
              for (final y in score.yaku)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(yakuLine(l10n, y, r),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13)),
                ),
              const SizedBox(height: 6),
              Text(scoreTotalLine(l10n, score, r),
                  key: const Key('winTotal'),
                  style: const TextStyle(
                      color: AppColors.goldBright,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              if (r.isJapanese)
                Text(_payment(s, win),
                    key: const Key('winPayment'),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  /// Who pays what, in riichi's terms.
  String _payment(Scenario s, ScenarioWin win) {
    final score = win.score;
    if (!win.byTsumo) {
      final from =
          win.fromOffer ? kScenarioSeatNames[s.offeredFrom] : 'the discarder';
      return 'Ron: ${score.points} from $from';
    }
    return s.isDealer
        ? 'Tsumo: ${score.nonDealerPays} each'
        : 'Tsumo: dealer ${score.dealerPays}, others ${score.nonDealerPays}';
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      );

  Widget _chip(String label, bool on, VoidCallback? onTap, {Key? key}) {
    final enabled = onTap != null;
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        constraints:
            phone ? const BoxConstraints(minWidth: 92, minHeight: 92) : null,
        alignment: phone ? Alignment.center : null,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: on ? const Color(0xff00695c) : const Color(0xff294342),
          borderRadius: BorderRadius.circular(6),
          border:
              Border.all(color: on ? AppColors.goldText : Colors.transparent),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: phone ? 20 : 12,
                fontWeight: FontWeight.w600,
                color: !enabled
                    ? Colors.white24
                    : (on ? Colors.white : Colors.white60))),
      ),
    );
  }
}

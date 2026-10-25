/// A searchable list of the mahjong terms a new player meets, worded for the
/// rules in play: call names follow the ruleset, and a term that only exists
/// under some rulesets (flowers, riichi, a void suit) shows only under them.
library;

import 'package:flutter/material.dart';
import 'package:mahjong_core/round.dart' show CallType;
import 'package:mahjong_core/ruleset.dart';

import '../l10n/l10n.dart';
import '../l10n/mahjong_terms.dart';
import 'e2e_id.dart';
import 'theme.dart';

class GlossaryEntry {
  const GlossaryEntry(this.id, this.term, this.definition);

  /// Stable name, for keys and tests.
  final String id;
  final String term;
  final String definition;

  /// True when [query] (already lower-cased and trimmed) is in the term or
  /// its definition.
  bool matches(String query) =>
      query.isEmpty ||
      term.toLowerCase().contains(query) ||
      definition.toLowerCase().contains(query);
}

/// Every term that applies under [ruleset], in the order a lesson would meet
/// them: the hand, the calls, winning, scoring, then the guide's own words.
List<GlossaryEntry> glossaryEntries(AppLocalizations l10n, Ruleset ruleset) {
  final r = ruleset;
  final sichuan = r.isSichuan;
  // Sichuan claims no chows, and sanma has no chi at all.
  final chi = !sichuan && !r.isSanma;
  final flowers = r.isChineseStyle && !sichuan;
  final scoreUnit = switch (r) {
    Ruleset.riichi || Ruleset.sanma => l10n.glossaryUnitHan,
    Ruleset.hongKong => l10n.glossaryUnitFaan,
    Ruleset.taiwanese => l10n.glossaryUnitTai,
    _ => l10n.glossaryUnitFan,
  };
  return [
    GlossaryEntry('set', l10n.glossaryTermSet, l10n.glossaryDefSet),
    GlossaryEntry('pair', l10n.glossaryTermPair, l10n.glossaryDefPair),
    if (chi)
      GlossaryEntry('chi', l10n.callLabel(CallType.chi, r), l10n.glossaryDefChi),
    GlossaryEntry('pon', l10n.callLabel(CallType.pon, r), l10n.glossaryDefPon),
    GlossaryEntry('kan', l10n.callLabel(CallType.kan, r), l10n.glossaryDefKan),
    GlossaryEntry('discard', l10n.glossaryTermDiscard, l10n.glossaryDefDiscard),
    GlossaryEntry('tsumo', l10n.tsumoLabel(r), l10n.glossaryDefTsumo),
    GlossaryEntry(
        'ron', l10n.callLabel(CallType.ron, r), l10n.glossaryDefRon),
    GlossaryEntry('dealer', l10n.glossaryTermDealer, l10n.glossaryDefDealer),
    if (!sichuan) ...[
      GlossaryEntry('winds', l10n.glossaryTermWinds, l10n.glossaryDefWinds),
      GlossaryEntry(
          'dragons', l10n.glossaryTermDragons, l10n.glossaryDefDragons),
    ],
    if (flowers)
      GlossaryEntry('flowers', l10n.glossaryTermFlowers, l10n.glossaryDefFlowers),
    if (sichuan)
      GlossaryEntry('void', l10n.glossaryTermVoid, l10n.glossaryDefVoid),
    GlossaryEntry('score', scoreUnit, l10n.glossaryDefScore),
    if (r.isJapanese) ...[
      GlossaryEntry('riichi', l10n.glossaryTermRiichi, l10n.glossaryDefRiichi),
      GlossaryEntry('dora', l10n.glossaryTermDora, l10n.glossaryDefDora),
      GlossaryEntry(
          'furiten', l10n.glossaryTermFuriten, l10n.glossaryDefFuriten),
    ],
    if (r.isSanma) ...[
      GlossaryEntry('sanma', l10n.glossaryTermSanma, l10n.glossaryDefSanma),
      GlossaryEntry('kita', l10n.glossaryTermKita, l10n.glossaryDefKita),
    ],
    GlossaryEntry('ready', l10n.glossaryTermReady, l10n.glossaryDefReady),
    GlossaryEntry('away', l10n.glossaryTermAway, l10n.glossaryDefAway),
    GlossaryEntry('helpful', l10n.glossaryTermHelpful, l10n.glossaryDefHelpful),
  ];
}

/// Opens the glossary over the current screen.
Future<void> showGlossary(BuildContext context, Ruleset ruleset) =>
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.sheet,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: GlossaryView(
            ruleset: ruleset,
            onClose: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ),
      ),
    );

class GlossaryView extends StatefulWidget {
  const GlossaryView({super.key, required this.ruleset, this.onClose});

  final Ruleset ruleset;
  final VoidCallback? onClose;

  @override
  State<GlossaryView> createState() => _GlossaryViewState();
}

class _GlossaryViewState extends State<GlossaryView> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shown = [
      for (final e in glossaryEntries(l10n, widget.ruleset))
        if (e.matches(_query)) e,
    ];
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.glossaryTitle,
                      style: const TextStyle(
                          color: AppColors.goldText,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                ),
                if (widget.onClose != null)
                  IconButton(
                    key: const Key('glossaryClose'),
                    tooltip: l10n.done,
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            e2eId(
              'glossarySearch',
              TextField(
                key: const Key('glossarySearch'),
                controller: _controller,
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  hintText: l10n.glossarySearchHint,
                  hintStyle: const TextStyle(color: Colors.white38),
                  enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.gold)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: shown.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(l10n.glossaryNoMatch,
                            key: const Key('glossaryEmpty'),
                            style: const TextStyle(color: Colors.white54)),
                      ),
                    )
                  : SingleChildScrollView(
                      // A short list, so built in full rather than lazily.
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < shown.length; i++) ...[
                            if (i > 0)
                              const Divider(height: 14, color: Colors.white12),
                            Column(
                              key: Key('glossary_${shown[i].id}'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(shown[i].term,
                                    style: const TextStyle(
                                        color: AppColors.goldText,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(shown[i].definition,
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        height: 1.4)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

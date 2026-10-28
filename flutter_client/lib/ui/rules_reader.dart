import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../l10n/mahjong_terms.dart';
import 'e2e_id.dart';
import 'rules_content.dart';
import 'rules_text.dart';
import 'theme.dart';
import 'tile_face.dart';

/// A reference overlay only: opening it never changes the table or its clock.
Future<void> showRulesReader(BuildContext context, Ruleset ruleset,
        {int? minimumFaan, int? minimumPoints}) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.sheet,
        insetPadding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
          child: RulesReader(
            ruleset: ruleset,
            minimumFaan: minimumFaan,
            minimumPoints: minimumPoints,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );

class RulesReader extends StatefulWidget {
  const RulesReader({
    super.key,
    required this.ruleset,
    this.minimumFaan,
    this.minimumPoints,
    required this.onClose,
    this.openReference,
  });

  final Ruleset ruleset;
  final int? minimumFaan;
  final int? minimumPoints;
  final VoidCallback onClose;
  final Future<bool> Function(Uri)? openReference;

  @override
  State<RulesReader> createState() => _RulesReaderState();
}

class _RulesReaderState extends State<RulesReader> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  bool _referenceFailed = false;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _filter(String value) {
    setState(() => _query = value.trim().toLowerCase());
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _openReference() async {
    var opened = false;
    try {
      final uri = Uri.parse(widget.ruleset.rulesUrl);
      opened = await (widget.openReference?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
    } on PlatformException {
      opened = false;
    }
    if (mounted) setState(() => _referenceFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sections = rulesSections(widget.ruleset,
            l10n: l10n,
            minimumFaan: widget.minimumFaan,
            minimumPoints: widget.minimumPoints)
        .map((section) => section.filtered(_query))
        .nonNulls
        .toList();
    return Material(
      key: const Key('rulesReader'),
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text(l10n.rulesetName(widget.ruleset),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.goldText,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                key: const Key('rulesReaderClose'),
                onPressed: widget.onClose,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(l10n.back),
              ),
            ]),
            e2eId(
              'rulesSearch',
              TextField(
                key: const Key('rulesSearch'),
                controller: _search,
                onChanged: _filter,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: l10n.rulesSearchHint,
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('rulesSearchClear'),
                          tooltip: l10n.rulesClearSearch,
                          icon: const Icon(Icons.clear, color: Colors.white70),
                          onPressed: () {
                            _search.clear();
                            _filter('');
                          },
                        ),
                  enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.gold)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              // Plain Text, each its own semantics node: on the web a
              // SelectableText (or a SelectionArea) is an empty text field to
              // accessibility, and plain Texts merge into one long label.
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: ListView(
                  key: const Key('rulesList'),
                  controller: _scroll,
                  padding: const EdgeInsets.only(right: 14),
                  children: [
                    Text(l10n.rulesSummaryNotice,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14, height: 1.4)),
                    if (sections.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(l10n.rulesNoMatch,
                            key: const Key('rulesEmpty'),
                            style: const TextStyle(color: Colors.white70)),
                      ),
                    for (final section in sections)
                      Padding(
                        key: Key('rule_${section.id}'),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              container: true,
                              header: true,
                              child: Text(section.title,
                                  style: const TextStyle(
                                      color: AppColors.goldText,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ),
                            if (section.points.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _Points(section.points),
                            ],
                            if (section.entries.isNotEmpty)
                              _CatalogueTable(section.entries,
                                  text: RulesText.of(l10n),
                                  nameHeading: section.nameHeading,
                                  valueHeading: section.valueHeading),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_referenceFailed)
              Text(l10n.rulesReferenceFailed,
                  key: const Key('rulesReferenceError'),
                  style: const TextStyle(color: AppColors.goldText)),
            TextButton.icon(
              key: const Key('rulesExternalReference'),
              onPressed: _openReference,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l10n.rulesLinkLabel(widget.ruleset)),
              style: TextButton.styleFrom(foregroundColor: AppColors.link),
            ),
          ],
        ),
      ),
    );
  }
}

const _bodyStyle = TextStyle(color: Colors.white, fontSize: 16, height: 1.5);

/// A section's text: one point as a paragraph, several as bullets.
class _Points extends StatelessWidget {
  const _Points(this.points);

  final List<String> points;

  @override
  Widget build(BuildContext context) {
    if (points.length == 1) {
      return Semantics(
          container: true, child: Text(points.single, style: _bodyStyle));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Semantics(
              container: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ',
                      style:
                          TextStyle(color: AppColors.goldText, fontSize: 16)),
                  Expanded(child: Text(point, style: _bodyStyle)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A catalogue as a table: each pattern's name with its definition beneath,
/// its value, and tiles that show it. The tiles column is left out when no
/// row has any (a table of minimums); [nameHeading] and [valueHeading]
/// replace the catalogue's own headings for a table that is not one.
class _CatalogueTable extends StatelessWidget {
  const _CatalogueTable(this.entries,
      {required this.text, this.nameHeading, this.valueHeading});

  final List<RuleEntry> entries;
  final RulesText text;
  final String? nameHeading;
  final String? valueHeading;

  static const _heading = TextStyle(
      color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final tiles =
              constraints.maxWidth >= 600 ? TileSize.small : TileSize.tiny;
          Widget cell(Widget child) => Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 10, 8), child: child);
          final showExample = entries.any((e) => e.example.isNotEmpty);
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Table(
              columnWidths: {
                0: const FlexColumnWidth(4),
                1: FlexColumnWidth(showExample ? 2 : 3),
                if (showExample) 2: const FlexColumnWidth(5),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              border: const TableBorder(
                  horizontalInside: BorderSide(color: Colors.white12)),
              children: [
                TableRow(children: [
                  cell(Text(nameHeading ?? text.nameHeading, style: _heading)),
                  cell(
                      Text(valueHeading ?? text.valueHeading, style: _heading)),
                  if (showExample)
                    cell(Text(text.exampleHeading, style: _heading)),
                ]),
                for (final entry in entries)
                  TableRow(children: [
                    cell(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        if (entry.note.isNotEmpty)
                          Text(entry.note,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.4)),
                      ],
                    )),
                    cell(Text(entry.value.isEmpty ? '—' : entry.value,
                        style: const TextStyle(
                            color: AppColors.goldText, fontSize: 15))),
                    if (showExample) cell(_Example(entry.example, size: tiles)),
                  ]),
              ],
            ),
          );
        },
      );
}

/// An example's tiles, set by set, wrapping on a narrow screen.
class _Example extends StatelessWidget {
  const _Example(this.example, {required this.size});

  final String example;
  final TileSize size;

  @override
  Widget build(BuildContext context) {
    if (example.isEmpty) {
      return const Text('—', style: TextStyle(color: Colors.white38));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final set in example.split(' '))
          set == '→'
              ? const Icon(Icons.arrow_forward, size: 14, color: Colors.white70)
              // A long set (Nine Gates) wraps too.
              : Wrap(
                  runSpacing: 2,
                  children: [
                    for (final tile in exampleSet(set))
                      TileFace(tile: tile, size: size),
                  ],
                ),
      ],
    );
  }
}

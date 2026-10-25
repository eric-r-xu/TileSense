import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../l10n/mahjong_terms.dart';
import 'e2e_id.dart';
import 'rules_content.dart';
import 'theme.dart';

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
            minimumFaan: widget.minimumFaan,
            minimumPoints: widget.minimumPoints)
        .where((section) => section.matches(_query))
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
                              header: true,
                              child: Text(section.title,
                                  style: const TextStyle(
                                      color: AppColors.goldText,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(section.body,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    height: 1.5)),
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

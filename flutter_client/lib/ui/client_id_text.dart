/// This device's client id — the one telemetry reports — behind a small "ID"
/// button in the online screens' app bar, well away from Back. Tapping it
/// opens a dialog that shows the id, selectable, with a Copy button.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../telemetry/telemetry.dart' show persistentClientId;

/// The "ID" chip for an app bar's actions, [height] tall to tap.
class ClientIdButton extends StatelessWidget {
  const ClientIdButton({super.key, this.height = 40});

  final double height;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: context.l10n.clientIdTitle,
        child: OutlinedButton.icon(
          key: const Key('clientIdButton'),
          onPressed: () => showClientIdDialog(context),
          icon: const Icon(Icons.badge_outlined, size: 18),
          label: Text(context.l10n.clientIdShort),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white30),
            minimumSize: Size(64, height),
          ),
        ),
      );
}

/// Shows this device's client id with a Copy button. Dialogs sit on the root
/// navigator, outside the scaled canvas, so it is drawn at the device's real
/// size even on a phone.
Future<void> showClientIdDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const _ClientIdDialog(),
    );

class _ClientIdDialog extends StatefulWidget {
  const _ClientIdDialog();

  @override
  State<_ClientIdDialog> createState() => _ClientIdDialogState();
}

class _ClientIdDialogState extends State<_ClientIdDialog> {
  final String _id = persistentClientId();
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _id));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(context.l10n.clientIdTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              _id,
              key: const Key('clientIdValue'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(context.l10n.clientIdHelp,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('clientIdClose'),
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.close),
          ),
          FilledButton.icon(
            key: const Key('clientIdCopy'),
            onPressed: _copy,
            icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
            label: Text(_copied ? context.l10n.copied : context.l10n.copy),
          ),
        ],
      );
}

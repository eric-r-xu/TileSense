/// This device's client id in plain white lettering — shown in the top-left of
/// the online screens, right after the back arrow. Tap it to copy; it can also
/// be selected like any text.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../telemetry/telemetry.dart' show persistentClientId;

class ClientIdText extends StatefulWidget {
  const ClientIdText({super.key});

  @override
  State<ClientIdText> createState() => _ClientIdTextState();
}

class _ClientIdTextState extends State<ClientIdText> {
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        // Scales down rather than overflowing if the bar is ever tight.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SelectableText(
            _copied ? 'Copied!' : _id,
            key: const Key('clientId'),
            onTap: _copy,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
}

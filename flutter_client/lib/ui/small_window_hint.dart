/// A one-line note for a mouse-and-keyboard user whose window has shrunk far
/// enough that the table switches to the phone layout (see [isPhoneLayout]):
/// the toolbar has moved into the Menu button by the hand, which can look like
/// buttons going missing. Touch devices already expect that layout, so they
/// never see it; closing it keeps it away for the rest of the session.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../main.dart' show isPhoneLayout;

class SmallWindowHint extends StatefulWidget {
  const SmallWindowHint({super.key, this.online = false});

  /// Online, the note names Leave Room, the control people go looking for.
  final bool online;

  /// Shown at most until closed once, per run of the app.
  static bool dismissed = false;

  /// Whether the platform is driven by touch, where the phone layout is
  /// expected rather than a surprise.
  static bool get touchPlatform => switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.fuchsia =>
          true,
        _ => false,
      };

  @override
  State<SmallWindowHint> createState() => _SmallWindowHintState();
}

class _SmallWindowHintState extends State<SmallWindowHint> {
  @override
  Widget build(BuildContext context) {
    if (SmallWindowHint.dismissed ||
        SmallWindowHint.touchPlatform ||
        !isPhoneLayout(context)) {
      return const SizedBox.shrink();
    }
    return Material(
      key: const Key('smallWindowHint'),
      color: const Color(0xe6042020),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.online
                    ? context.l10n.smallWindowHintOnline
                    : context.l10n.smallWindowHint,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
            IconButton(
              key: const Key('smallWindowHintClose'),
              tooltip: context.l10n.done,
              iconSize: 18,
              color: Colors.white54,
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => SmallWindowHint.dismissed = true),
            ),
          ],
        ),
      ),
    );
  }
}

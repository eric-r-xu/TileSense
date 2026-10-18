/// Stable, language-independent handles for the Playwright suite (e2e/).
///
/// CanvasKit paints to a canvas, so Flutter `Key`s never reach the DOM. With
/// semantics enabled, [Semantics.identifier] shows up as the
/// `flt-semantics-identifier` attribute, which e2e tests select on.
library;

import 'package:flutter/material.dart';

Widget e2eId(String id, Widget child) =>
    Semantics(identifier: id, child: child);

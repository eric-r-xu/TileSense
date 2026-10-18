import 'dart:async';

import 'package:tilesense/logic/progress.dart';
import 'package:tilesense/ui/beginner_guide.dart';
import 'package:tilesense/ui/learn_to_play_page.dart';

/// Runs before every test file. Tests that tap Start expect the character
/// screen next, so the first-run lesson is off unless a test turns it on; the
/// guide shows its full table unless a test asks for the simple view; and the
/// menu offers no suggestions unless a test turns them on.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LearnToPlay.autoShow = false;
  BeginnerGuide.defaultOn = false;
  ProgressStore.nudgesEnabled = false;
  await testMain();
}

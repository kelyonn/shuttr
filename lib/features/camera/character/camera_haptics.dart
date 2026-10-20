import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shuttr/features/looks/look_spec.dart';

/// How each camera feels in the hand: a firm shutter, then the film advance
/// under your thumb (a run of ticks for a disposable's thumbwheel, a few
/// for a motor winder or a print ejecting). Haptics only; sounds are off
/// for now (tool/sounds/gen_sounds.py can bring them back).
abstract final class CameraHaptics {
  static void shutter() => unawaited(HapticFeedback.heavyImpact());

  static void advance(SoundSet set) {
    switch (set) {
      case SoundSet.disposable:
        unawaited(_ticks(8, const Duration(milliseconds: 60)));
      case SoundSet.instant || SoundSet.film:
        unawaited(_ticks(4, const Duration(milliseconds: 90)));
      case SoundSet.digicam || SoundSet.phone:
        break;
    }
  }

  static Future<void> _ticks(int n, Duration gap) async {
    for (var i = 0; i < n; i++) {
      await HapticFeedback.selectionClick();
      await Future<void>.delayed(gap);
    }
  }
}

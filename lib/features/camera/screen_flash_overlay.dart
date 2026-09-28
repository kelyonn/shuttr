import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// Drives the front-camera "screen flash": a full-white overlay plus max
/// screen brightness, since most Android front cameras have no hardware
/// flash (docs/ARCHITECTURE.md "Flash"). Mechanically confirmed to
/// measurably brighten a capture in the S4 spike
/// (integration_test/screen_flash_spike_test.dart) — whether a lit face
/// looks convincing needs your own eyes on a device.
class ScreenFlashController {
  final ValueNotifier<bool> visible = ValueNotifier(false);
  double? _previousBrightness;

  /// Cranks brightness and shows the overlay, then waits for it to actually
  /// hit the screen/subject before the caller takes the photo.
  Future<void> engage() async {
    try {
      _previousBrightness = await ScreenBrightness().application;
    } on Exception {
      _previousBrightness = null;
    }
    await ScreenBrightness().setApplicationScreenBrightness(1);
    visible.value = true;
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  /// Hides the overlay and restores whatever brightness the app had before.
  Future<void> disengage() async {
    visible.value = false;
    final previous = _previousBrightness;
    if (previous != null) {
      await ScreenBrightness().setApplicationScreenBrightness(previous);
    } else {
      await ScreenBrightness().resetApplicationScreenBrightness();
    }
  }

  void dispose() {
    visible.dispose();
  }
}

class ScreenFlashOverlay extends StatelessWidget {
  const new({required this.controller, super.key});

  final ScreenFlashController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.visible,
      builder: (context, visible, _) => IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: visible ? 1 : 0,
          child: const ColoredBox(color: Colors.white),
        ),
      ),
    );
  }
}

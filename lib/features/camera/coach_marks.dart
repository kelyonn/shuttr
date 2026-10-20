import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shuttr/app/theme.dart';
import 'package:shuttr/core/ui/shuttr_ui.dart';
import 'package:shuttr/features/settings/settings_repository.dart';

const _seenKey = 'coachMarksSeen';

/// A one-time card over the camera listing the gestures nothing else
/// teaches. Tap anywhere to dismiss; it never shows again.
class CoachMarks extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CoachMarks> createState() => _CoachMarksState();
}

class _CoachMarksState extends ConsumerState<CoachMarks> {
  late bool _visible =
      !(ref.read(sharedPreferencesProvider).getBool(_seenKey) ?? false);

  void _dismiss() {
    setState(() => _visible = false);
    unawaited(ref.read(sharedPreferencesProvider).setBool(_seenKey, true));
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    const tips = [
      ('PINCH', 'Zoom in. Double-tap jumps to 2x.'),
      ('TAP', 'Tap the picture to focus.'),
      ('SWIPE THE NAME', 'Swipe the camera name to change camera.'),
      ('HOLD A PHOTO', 'In the gallery, hold a photo to select several.'),
    ];
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: ColoredBox(
          color: const Color(0xD9141210),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUICK TIPS',
                      style: Typo.display.copyWith(
                        fontSize: 48,
                        color: Palette.cream,
                      ),
                    ),
                    const SizedBox(height: 24),
                    for (final (head, body) in tips) ...[
                      Text(
                        head,
                        style: Typo.labelBold.copyWith(color: Palette.cream),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: Typo.body.copyWith(color: Palette.cream),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 8),
                    TapCell(
                      onTap: _dismiss,
                      height: 52,
                      alignment: Alignment.center,
                      background: Palette.cream,
                      child: const Text('GOT IT', style: Typo.labelBold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

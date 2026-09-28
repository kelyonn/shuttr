import 'package:flutter/material.dart';

/// A thin decorative bezel around the preview, so the viewfinder reads as
/// an LCD screen set into a digicam body rather than a bare camera feed
/// (S16). Purely cosmetic — never intercepts touches.
class LcdFrame extends StatelessWidget {
  const new({required this.bodyColor, super.key});

  final Color bodyColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: bodyColor.withValues(alpha: 0.6),
              width: 3,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

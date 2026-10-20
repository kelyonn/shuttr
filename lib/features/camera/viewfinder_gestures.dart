import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shuttr/app/theme.dart';

/// Pinch to zoom, double-tap to flip between 1x and 2x, tap to focus (with
/// a ring that settles on the spot) over the live viewfinder. Zoom happens
/// on the sensor, so the saved photo matches what the finder shows.
class ViewfinderGestures extends StatefulWidget {
  const new({required this.controller, required this.child, super.key});

  final CameraController controller;
  final Widget child;

  @override
  State<ViewfinderGestures> createState() => _ViewfinderGesturesState();
}

class _ViewfinderGesturesState extends State<ViewfinderGestures>
    with SingleTickerProviderStateMixin {
  double _min = 1;
  double _max = 1;
  double _zoom = 1;
  double _baseZoom = 1;
  bool _showPill = false;
  Timer? _pillTimer;
  Offset? _focusAt;
  Timer? _focusTimer;
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadRange());
  }

  Future<void> _loadRange() async {
    try {
      final lo = await widget.controller.getMinZoomLevel();
      final hi = await widget.controller.getMaxZoomLevel();
      if (!mounted) return;
      setState(() {
        _min = lo;
        // Past ~10x a phone's digital zoom is mush.
        _max = hi.clamp(lo, 10.0);
        _zoom = _zoom.clamp(_min, _max);
      });
    } on Object {
      // No zoom on this camera: gestures just do nothing.
    }
  }

  Future<void> _applyZoom(double value) async {
    final z = value.clamp(_min, _max);
    if (z == _zoom) return;
    setState(() {
      _zoom = z;
      _showPill = true;
    });
    _pillTimer?.cancel();
    _pillTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _showPill = false);
    });
    try {
      await widget.controller.setZoomLevel(z);
    } on Object {
      // A zoom call can lose a race with a lens switch; harmless.
    }
  }

  void _focus(Offset local, Size size) {
    setState(() => _focusAt = local);
    _ring.forward(from: 0);
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _focusAt = null);
    });
    final point = Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
    unawaited(HapticFeedback.selectionClick());
    unawaited(() async {
      try {
        await widget.controller.setFocusPoint(point);
        await widget.controller.setExposurePoint(point);
      } on Object {
        // Not every camera supports metering points.
      }
    }());
  }

  @override
  void dispose() {
    _pillTimer?.cancel();
    _focusTimer?.cancel();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onScaleStart: (_) => _baseZoom = _zoom,
          onScaleUpdate: (d) {
            if (d.pointerCount < 2) return;
            unawaited(_applyZoom(_baseZoom * d.scale));
          },
          onTapUp: (d) => _focus(d.localPosition, size),
          onDoubleTap: () {
            unawaited(HapticFeedback.lightImpact());
            unawaited(_applyZoom(_zoom > _min + 0.05 ? _min : 2));
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (_focusAt != null)
                Positioned(
                  left: _focusAt!.dx - 34,
                  top: _focusAt!.dy - 34,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _ring,
                      builder: (context, _) {
                        final t = Curves.easeOutCubic.transform(_ring.value);
                        return Opacity(
                          opacity: 1 - 0.35 * t,
                          child: Transform.scale(
                            scale: 1.5 - 0.5 * t,
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Palette.cream,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showPill ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        color: const Color(0xB3111111),
                        child: Text(
                          '${_zoom.toStringAsFixed(1)}×',
                          style: Typo.label.copyWith(color: Palette.cream),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

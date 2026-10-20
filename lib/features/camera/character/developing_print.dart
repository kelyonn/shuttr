import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/render/frame_composite.dart';

/// An instant print developing: for the first [seconds] after the shot the
/// image rises out of a flat blue-grey sheet, shadows first, colour last,
/// the way the chemistry comes up. Purely a display effect; the stored JPEG
/// is always the finished print.
class DevelopingPrint extends StatefulWidget {
  const new({
    required this.child,
    required this.shotAt,
    required this.seconds,
    this.window,
    super.key,
  });

  final Widget child;
  final DateTime shotAt;
  final int seconds;

  /// The image area inside the print's white border, as fractions of the
  /// whole (from `frameWindowFraction`). Only this part develops; the
  /// border is white from the start. Null = the whole child develops.
  final Rect? window;

  @override
  State<DevelopingPrint> createState() => _DevelopingPrintState();
}

class _DevelopingPrintState extends State<DevelopingPrint>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  double _progress = 1;

  @override
  void initState() {
    super.initState();
    _progress = _now();
    if (_progress < 1) {
      _ticker = createTicker((_) {
        final p = _now();
        if (p >= 1) _ticker?.stop();
        setState(() => _progress = p);
      })..start();
    }
  }

  double _now() {
    if (widget.seconds <= 0) return 1;
    final ms = DateTime.now().difference(widget.shotAt).inMilliseconds;
    return (ms / (widget.seconds * 1000)).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_progress >= 1) return widget.child;
    // Density comes up fast then slows; colour lags behind density.
    final density = 1 - math.pow(1 - _progress, 2.2).toDouble();
    final colour = math.pow(_progress, 1.4).toDouble();
    final developing = ColorFiltered(
      colorFilter: ColorFilter.matrix(_developMatrix(density, colour)),
      child: widget.child,
    );
    final window = widget.window;
    if (window == null) return developing;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        ClipRect(clipper: _FractionClipper(window), child: developing),
      ],
    );
  }
}

/// Blends from a pale blue-grey sheet (density 0) to the image, with
/// saturation trailing behind.
List<double> _developMatrix(double density, double colour) {
  const lr = 0.2126;
  const lg = 0.7152;
  const lb = 0.0722;
  final s = colour;
  // Saturation matrix.
  final sat = <double>[
    lr * (1 - s) + s,
    lg * (1 - s),
    lb * (1 - s),
    lr * (1 - s),
    lg * (1 - s) + s,
    lb * (1 - s),
    lr * (1 - s),
    lg * (1 - s),
    lb * (1 - s) + s,
  ];
  // Sheet colour, 0-255.
  const sheet = [196.0, 204.0, 200.0];
  final d = density;
  return <double>[
    sat[0] * d, sat[1] * d, sat[2] * d, 0, sheet[0] * (1 - d), //
    sat[3] * d, sat[4] * d, sat[5] * d, 0, sheet[1] * (1 - d),
    sat[6] * d, sat[7] * d, sat[8] * d, 0, sheet[2] * (1 - d),
    0, 0, 0, 1, 0,
  ];
}

class _FractionClipper extends CustomClipper<Rect> {
  const new(this.fraction);
  final Rect fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    fraction.left * size.width,
    fraction.top * size.height,
    fraction.right * size.width,
    fraction.bottom * size.height,
  );

  @override
  bool shouldReclip(_FractionClipper old) => old.fraction != fraction;
}

/// A stored/reviewed photo, developing on screen if its camera's prints
/// develop ([LookSpec.developSeconds]) and it was shot recently enough.
/// [fit] is how the photo sits in its box; `BoxFit.cover` thumbnails skip
/// the border-only precision and develop the whole tile.
class PrintImage extends StatefulWidget {
  const new({
    required this.path,
    required this.spec,
    required this.shotAt,
    this.fit = BoxFit.contain,
    super.key,
  });

  final String path;
  final LookSpec? spec;
  final DateTime shotAt;
  final BoxFit fit;

  @override
  State<PrintImage> createState() => _PrintImageState();
}

class _PrintImageState extends State<PrintImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;

  /// The stored print's own width/height. A print shot upright is taller
  /// than it is wide and one shot sideways the opposite, so the box must
  /// follow the file, never the look's nominal aspect.
  double? _aspect;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PrintImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _aspect = null;
      _resolve();
    }
  }

  void _resolve() {
    _unlisten();
    final stream = FileImage(File(widget.path))
        .resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      final a = info.image.width / info.image.height;
      if (mounted && a != _aspect) setState(() => _aspect = a);
    }, onError: (_, _) {});
    _stream = stream..addListener(listener);
    _listener = listener;
  }

  void _unlisten() {
    final l = _listener;
    if (l != null) _stream?.removeListener(l);
  }

  @override
  void dispose() {
    _unlisten();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.spec;
    final seconds = look?.developSeconds ?? 0;
    final fresh =
        seconds > 0 &&
        DateTime.now().difference(widget.shotAt).inSeconds < seconds;
    if (look == null || !fresh) {
      return Image.file(File(widget.path), fit: widget.fit);
    }
    if (widget.fit == BoxFit.cover || look.frameAsset == null) {
      return DevelopingPrint(
        shotAt: widget.shotAt,
        seconds: seconds,
        child: Image.file(File(widget.path), fit: widget.fit),
      );
    }
    final aspect = _aspect;
    if (aspect == null) return const SizedBox.shrink();
    return Center(
      child: AspectRatio(
        aspectRatio: aspect,
        child: DevelopingPrint(
          shotAt: widget.shotAt,
          seconds: seconds,
          window: frameWindowFraction(),
          child: Image.file(File(widget.path), fit: BoxFit.fill),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// A colour variant for the digicam body chrome (S16) — real digicams came
/// in a handful of body colours; this is that, not a light/dark mode. The
/// app's Material theme (see `app.dart`) is separate and unaffected.
enum CameraBodyTheme {
  pastel(accentColor: Color(0xFFFF8FB1), bodyColor: Color(0xFFFFF3F6)),
  chrome(accentColor: Color(0xFFB0B8C1), bodyColor: Color(0xFFE7EAED));

  new({required this.accentColor, required this.bodyColor});

  /// The dial/button highlight colour.
  final Color accentColor;

  /// The body/bezel colour behind the preview.
  final Color bodyColor;
}

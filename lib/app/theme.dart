import 'package:flutter/material.dart';

/// Colour variant for the digicam body (the paper the dashboard is printed
/// on) — real digicams came in a handful of body colours; this is that,
/// not a light/dark mode. Persisted in settings (S17).
enum CameraBodyTheme {
  bone(paperColor: Color(0xFFE5E0D4), label: 'Bone'),
  chrome(paperColor: Color(0xFFD9DCDC), label: 'Chrome'),
  pastel(paperColor: Color(0xFFEBD8DF), label: 'Pastel');

  new({required this.paperColor, required this.label});

  final Color paperColor;
  final String label;
}

/// Design tokens from the locked visual system (design/camera-directions.html
/// refined on the "Shuttr Visual System" canvas). Everything on screen reads
/// from here so the look changes in one place.
abstract final class Palette {
  static const ink = Color(0xFF111111);
  static const paper = Color(0xFFE5E0D4);
  static const cream = Color(0xFFF3EBDD);
  static const stage = Color(0xFF141210);
  static const press = Color(0xFFB32D21);
  static const stamp = Color(0xFFE25A1C);
}

abstract final class Typo {
  static const _mono = 'IBMPlexMono';

  /// Big camera / page names: DIGI, ROLL, SET.
  static const display = TextStyle(
    fontFamily: 'Anton',
    fontSize: 72,
    height: 0.82,
    letterSpacing: 0.4,
  );

  /// Review-size name.
  static const name = TextStyle(fontFamily: 'Anton', fontSize: 48, height: 0.9);

  /// The italic "'03" under the name.
  static const sub = TextStyle(
    fontFamily: 'CormorantGaramond',
    fontStyle: FontStyle.italic,
    fontSize: 32,
    height: 1,
    fontVariations: [FontVariation('wght', 500)],
  );

  static const subSmall = TextStyle(
    fontFamily: 'CormorantGaramond',
    fontStyle: FontStyle.italic,
    fontSize: 26,
    height: 1,
    fontVariations: [FontVariation('wght', 500)],
  );

  static const statement = TextStyle(
    fontFamily: 'CormorantGaramond',
    fontStyle: FontStyle.italic,
    fontSize: 28,
    height: 1.05,
    fontVariations: [FontVariation('wght', 500)],
  );

  static const label = TextStyle(
    fontFamily: _mono,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.76,
    height: 1,
  );

  static const labelBold = TextStyle(
    fontFamily: _mono,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.3,
    height: 1,
  );

  static const body = TextStyle(fontFamily: _mono, fontSize: 12, height: 1.35);

  static const small = TextStyle(fontFamily: _mono, fontSize: 11, height: 1.25);

  static const micro = TextStyle(
    fontFamily: _mono,
    fontSize: 11,
    letterSpacing: 1,
    height: 1,
  );
}

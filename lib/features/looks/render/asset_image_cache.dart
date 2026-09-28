import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

/// Decodes and caches image assets (LUTs, frames) as [ui.Image]s, so
/// re-rendering the same look repeatedly — including every live preview
/// frame — doesn't re-decode the same PNG from disk each time.
abstract final class AssetImageCache {
  static final Map<String, ui.Image> _cache = {};

  static Future<ui.Image> load(String assetPath) async {
    final cached = _cache[assetPath];
    if (cached != null) return cached;

    final bytes = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _cache[assetPath] = frame.image;
    return frame.image;
  }
}

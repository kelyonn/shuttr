import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/features/camera/capture_service.dart';

/// Roll mode: like a real film camera, you shoot a whole roll without
/// seeing anything, then it develops all at once.
const rollLength = 27;

/// Frames still developing in the background (shot, not yet stored).
final inFlightFrames = ValueNotifier<int>(0);

/// Stored-but-undeveloped frames on the current roll.
final FutureProvider<int> exposuresOnRollProvider = FutureProvider.autoDispose(
  (ref) => PhotoStore().exposuresOnRoll(),
);

/// Renders queue one after another (never in parallel, so a burst of
/// shots can't blow the memory budget on a budget phone), each stored as an
/// undeveloped frame. Returns once this frame is stored.
class RollQueue {
  static Future<void> _tail = Future.value();

  static Future<void> add(PendingCapture pending, {PhotoStore? store}) {
    inFlightFrames.value++;
    final done = _tail.then((_) async {
      try {
        final result = await pending.renderFuture;
        await (store ?? PhotoStore()).save(
          originalCapturePath: result.originalPath,
          renderedPath: result.renderedPath,
          spec: result.spec,
          seed: result.seed,
          dateStamp: result.dateStamp,
          flashFired: result.flashFired,
          accidents: result.accidents,
          capturedAt: result.capturedAt,
          developed: false,
        );
        for (final path in [result.originalPath, result.renderedPath]) {
          final f = File(path);
          if (f.existsSync()) await f.delete();
        }
      } on Object catch (error) {
        debugPrint('Roll frame failed to develop: $error');
      } finally {
        inFlightFrames.value--;
      }
    });
    _tail = done;
    return done;
  }

  /// Waits for every in-flight frame to land.
  static Future<void> drain() => _tail;
}

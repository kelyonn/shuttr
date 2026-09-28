import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shuttr/core/platform/codec_channel.dart';
import 'package:shuttr/features/looks/date_stamp.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/render/look_renderer.dart';

/// A capture whose original has already been written to disk (crash-safe)
/// but whose look render is still running in the background — the review
/// screen awaits [renderFuture] behind its "developing" animation instead
/// of blocking the shutter on a full render (CLAUDE.md rule 2).
class PendingCapture {
  const new({required this.originalPath, required this.renderFuture});

  final String originalPath;
  final Future<CaptureResult> renderFuture;
}

/// Everything `PhotoStore.save` (S15) needs to persist this capture
/// permanently, plus what the review screen shows meanwhile.
class CaptureResult {
  const new({
    required this.originalPath,
    required this.renderedPath,
    required this.renderMs,
    required this.spec,
    required this.seed,
    this.dateStamp,
  });

  final String originalPath;
  final String renderedPath;
  final int renderMs;
  final LookSpec spec;

  /// The seed used for this render's grain/light-leak randomisation —
  /// generated here (rather than left to [LookRenderer]'s default) so it
  /// can be persisted and a re-develop can reproduce the same result.
  final double seed;
  final DateStampSettings? dateStamp;
}

/// Turns a shutter press into a capture: takes the photo (optionally behind
/// a screen-flash sequence via `beforeCapture`/`afterCapture`), writes the
/// original immediately, then kicks off the look render without waiting
/// for it. Both files land in the temp dir — the review screen's Save
/// action hands them to `PhotoStore` (S15) for permanent storage.
class CaptureService {
  new({LookRenderer? renderer})
    : _renderer = renderer ?? LookRenderer(codec: MethodChannelCodec());

  final LookRenderer _renderer;

  Future<PendingCapture> capture({
    required CameraController controller,
    required LookSpec spec,
    required bool flashFired,
    Future<void> Function()? beforeCapture,
    Future<void> Function()? afterCapture,
  }) async {
    if (beforeCapture != null) await beforeCapture();
    final captured = await controller.takePicture();
    if (afterCapture != null) await afterCapture();

    final tempDir = await getTemporaryDirectory();
    final id = DateTime.now().microsecondsSinceEpoch;
    final originalPath = '${tempDir.path}/shuttr_original_$id.jpg';
    await File(captured.path).copy(originalPath);

    final outPath = '${tempDir.path}/shuttr_rendered_$id.jpg';
    final dateStamp = spec.dateStampDefaultOn
        ? const DateStampSettings(enabled: true)
        : null;
    final seed = math.Random().nextDouble() * 1000;

    final renderFuture = _renderer
        .render(
          sourcePath: originalPath,
          spec: spec,
          outPath: outPath,
          flashFired: flashFired,
          seed: seed,
          dateStamp: dateStamp,
        )
        .then(
          (result) => CaptureResult(
            originalPath: originalPath,
            renderedPath: outPath,
            renderMs: result.renderMs,
            spec: spec,
            seed: seed,
            dateStamp: dateStamp,
          ),
        );

    return PendingCapture(
      originalPath: originalPath,
      renderFuture: renderFuture,
    );
  }
}

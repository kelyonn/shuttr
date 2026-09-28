import 'dart:io';

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

class CaptureResult {
  const new({
    required this.originalPath,
    required this.renderedPath,
    required this.renderMs,
  });

  final String originalPath;
  final String renderedPath;
  final int renderMs;
}

/// Turns a shutter press into a capture: takes the photo (optionally behind
/// a screen-flash sequence via `beforeCapture`/`afterCapture`), writes the
/// original immediately, then kicks off the look render without waiting
/// for it.
///
/// Storage here is temporary (app temp dir) — S15 replaces this with the
/// permanent `photos/`/`originals/`/`meta/` layout and gallery save.
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

    final renderFuture = _renderer
        .render(
          sourcePath: originalPath,
          spec: spec,
          outPath: outPath,
          flashFired: flashFired,
          dateStamp: dateStamp,
        )
        .then(
          (result) => CaptureResult(
            originalPath: originalPath,
            renderedPath: outPath,
            renderMs: result.renderMs,
          ),
        );

    return PendingCapture(
      originalPath: originalPath,
      renderFuture: renderFuture,
    );
  }
}

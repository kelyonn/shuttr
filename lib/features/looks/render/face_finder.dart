import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shuttr/core/platform/codec_channel.dart';
import 'package:shuttr/features/looks/render/shader_uniforms.dart';

/// Finds the main face in a (cropped, already-mirrored) frame so the flash
/// hotspot can land on it and red-eye can find the pupils. On-device only,
/// nothing leaves the phone (D-041).
abstract class FaceFinder {
  Future<FaceHint?> find(ui.Image frame);
}

/// ML Kit face detection on a small JPEG of the frame. Detecting on our own
/// downscaled copy (rather than the original file) means the coordinates
/// are already in the cropped/mirrored frame's space.
class MlKitFaceFinder implements FaceFinder {
  new({CodecChannel? codec}) : _codec = codec ?? MethodChannelCodec();

  static const _longEdge = 720;
  final CodecChannel _codec;

  static final _detector = FaceDetector(
    options: FaceDetectorOptions(enableLandmarks: true, minFaceSize: 0.08),
  );

  @override
  Future<FaceHint?> find(ui.Image frame) async {
    final scale = _longEdge / math.max(frame.width, frame.height);
    final w = (frame.width * scale).round();
    final h = (frame.height * scale).round();

    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImageRect(
      frame,
      ui.Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final small = recorder.endRecording().toImageSync(w, h);
    final bytes = await small.toByteData();
    small.dispose();
    if (bytes == null) return null;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/shuttr_face_${DateTime.now().microsecondsSinceEpoch}.jpg';
    try {
      await _codec.encodeJpeg(
        rgba: bytes.buffer.asUint8List(),
        width: w,
        height: h,
        quality: 85,
        outPath: path,
      );
      final faces = await _detector.processImage(InputImage.fromFilePath(path));
      if (faces.isEmpty) return null;
      final face = faces.reduce(
        (a, b) =>
            a.boundingBox.width * a.boundingBox.height >=
                b.boundingBox.width * b.boundingBox.height
            ? a
            : b,
      );
      return faceHintFrom(
        box: face.boundingBox,
        leftEye: face.landmarks[FaceLandmarkType.leftEye]?.position,
        rightEye: face.landmarks[FaceLandmarkType.rightEye]?.position,
        width: w.toDouble(),
        height: h.toDouble(),
      );
    } on Object {
      // No face data is never worth failing a render over.
      return null;
    } finally {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    }
  }
}

/// Converts a detection in pixel space to a normalised [FaceHint]. Eyes
/// missing from the detection are estimated from the face box (they sit
/// ~40% down, ~30% in from each side).
FaceHint faceHintFrom({
  required ui.Rect box,
  required math.Point<int>? leftEye,
  required math.Point<int>? rightEye,
  required double width,
  required double height,
}) {
  final lx = leftEye?.x.toDouble() ?? box.left + box.width * 0.3;
  final ly = leftEye?.y.toDouble() ?? box.top + box.height * 0.4;
  final rx = rightEye?.x.toDouble() ?? box.left + box.width * 0.7;
  final ry = rightEye?.y.toDouble() ?? box.top + box.height * 0.4;
  return FaceHint(
    centerX: box.center.dx / width,
    centerY: box.center.dy / height,
    leftEyeX: lx / width,
    leftEyeY: ly / height,
    rightEyeX: rx / width,
    rightEyeY: ry / height,
    // A dilated pupil in a dark room is ~6-7 mm on a ~150 mm wide face.
    eyeRadius: box.width * 0.026 / height,
  );
}

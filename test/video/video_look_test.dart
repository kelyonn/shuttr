import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/features/camera/body/camera_catalog.dart';
import 'package:shuttr/features/camera/body/camera_dash.dart';
import 'package:shuttr/features/video/video_look.dart';
import 'package:shuttr/features/video/video_looks.dart';

void main() {
  test('video look ids are unique', () {
    final ids = videoLooks.map((l) => l.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every video look survives a JSON round trip', () {
    for (final look in videoLooks) {
      expect(VideoLook.fromJson(look.toJson()).toJson(), look.toJson());
    }
  });

  test('outputs stay at or under 1080p (CLAUDE.md rule 5)', () {
    for (final l in videoLooks) {
      expect(l.outputHeight, lessThanOrEqualTo(1080), reason: l.id);
      expect(l.outputWidth, lessThanOrEqualTo(1920), reason: l.id);
      expect(
        l.outputWidth.isEven && l.outputHeight.isEven,
        isTrue,
        reason: '${l.id}: encoders want even sizes',
      );
    }
  });

  test('every referenced LUT exists', () {
    for (final l in videoLooks.where((l) => l.lutAsset != null)) {
      expect(File(l.lutAsset!).existsSync(), isTrue, reason: l.id);
    }
  });

  test('every video look has a card and a name mark', () {
    for (final p in videoPreviewLooks) {
      expect(cameraInfo(p.id).story, isNotEmpty, reason: p.id);
      expect(cameraMark(p).name, isNotEmpty, reason: p.id);
      expect(videoLookForPreview(p).id, p.id.replaceFirst('video_', ''));
    }
  });

  test('the shader declares every uniform the plugin sets', () {
    final glsl = File('android/app/src/main/assets/shaders/video_look.glsl')
        .readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/dev/shuttr/shuttr/VideoLookEffect.kt',
    ).readAsStringSync();
    final names = RegExp(r'set(?:Float|Floats|SamplerTexId)Uniform\("(\w+)"')
        .allMatches(kotlin)
        .map((m) => m.group(1)!)
        .toSet();
    expect(names, isNotEmpty);
    for (final name in names) {
      expect(
        RegExp('uniform \\w+ $name;').hasMatch(glsl),
        isTrue,
        reason: '$name is set in Kotlin but not declared in the shader',
      );
    }
  });
}

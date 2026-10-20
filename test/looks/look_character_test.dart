import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/core/platform/codec_channel.dart';
import 'package:shuttr/features/looks/render/look_renderer.dart';
import 'package:shuttr/features/looks/specs/identity.dart';

import '../support/fake_codec_channel.dart';

/// A flat grey "photo" of the given level.
class _FlatCodec extends FakeCodecChannel {
  new(this.v);
  final int v;

  @override
  Future<DecodedImage> decodeForRender(String path, int maxLongEdge) async {
    const w = 64;
    const h = 48;
    final rgba = Uint8List(w * h * 4)..fillRange(0, w * h * 4, v);
    for (var i = 3; i < rgba.length; i += 4) {
      rgba[i] = 255;
    }
    return DecodedImage(rgba: rgba, width: w, height: h);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  setUp(() => tempDir = Directory.systemTemp.createTempSync('look_character'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  test('de-HDR blows a bright region and sinks a dark one', () async {
    Future<int> lumaOf(int v, double hdr) async {
      final codec = _FlatCodec(v);
      await LookRenderer(codec: codec).render(
        sourcePath: 'fake.jpg',
        spec: identityLook.copyWith(hdrUndo: hdr),
        outPath: '${tempDir.path}/hdr.jpg',
        seed: 1,
        develop: false,
      );
      final px = codec.encodedRgba.single;
      return px[(24 * 64 + 32) * 4];
    }

    // develop: false means no wide blur is bound, so the stage reads the
    // small blur; a flat patch is unaffected by which blur it is.
    expect(await lumaOf(200, 1), greaterThan(await lumaOf(200, 0)));
    expect(await lumaOf(40, 1), lessThan(await lumaOf(40, 0)));
  });

  test('shadow crush and highlight blow clip the ends', () async {
    Future<int> out(int v) async {
      final codec = _FlatCodec(v);
      await LookRenderer(codec: codec).render(
        sourcePath: 'fake.jpg',
        spec: identityLook.copyWith(shadowCrush: 0.1, highlightBlow: 0.1),
        outPath: '${tempDir.path}/clip.jpg',
        seed: 1,
        develop: false,
      );
      return codec.encodedRgba.single[(24 * 64 + 32) * 4];
    }

    expect(await out(20), lessThan(8));
    expect(await out(235), greaterThan(250));
  });
}

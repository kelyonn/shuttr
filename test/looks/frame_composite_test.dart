import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/features/looks/render/frame_composite.dart';

void main() {
  group('frameCanvasSize', () {
    test('adds side margins to width and top+bottom margins to height', () {
      final size = frameCanvasSize(photoWidth: 1000, photoHeight: 1000);
      expect(size.width, 1000 * (1 + 2 * sideMargin));
      expect(size.height, 1000 * (1 + topMargin + bottomMargin));
    });

    test('bottom margin is larger than the side/top margins', () {
      expect(bottomMargin, greaterThan(sideMargin));
      expect(bottomMargin, greaterThan(topMargin));
    });
  });

  group('frameWindowRect', () {
    test('insets the photo by the side/top margins', () {
      final rect = frameWindowRect(photoWidth: 1000, photoHeight: 1000);
      expect(rect.left, 1000 * sideMargin);
      expect(rect.top, 1000 * topMargin);
      expect(rect.width, 1000);
      expect(rect.height, 1000);
    });

    test('fits inside the canvas produced by frameCanvasSize', () {
      const photoWidth = 800.0;
      const photoHeight = 600.0;
      final canvas = frameCanvasSize(
        photoWidth: photoWidth,
        photoHeight: photoHeight,
      );
      final window = frameWindowRect(
        photoWidth: photoWidth,
        photoHeight: photoHeight,
      );
      expect(window.right, lessThanOrEqualTo(canvas.width));
      expect(window.bottom, lessThanOrEqualTo(canvas.height));
    });
  });
}

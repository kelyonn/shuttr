import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/features/camera/camera_screen.dart';

void main() {
  Future<Size> frameSize(
    WidgetTester tester,
    Size screen,
    double aspect,
  ) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CameraFrame(aspect: aspect, child: const SizedBox.expand()),
      ),
    );
    return tester.getSize(find.byType(AspectRatio));
  }

  testWidgets('keeps the camera shape in a tall (portrait) plate', (t) async {
    final size = await frameSize(t, const Size(400, 800), 2 / 3);
    expect(size.width / size.height, closeTo(2 / 3, 0.001));
    expect(size.width, lessThanOrEqualTo(400));
  });

  testWidgets('keeps the camera shape in a wide (landscape) plate', (t) async {
    final size = await frameSize(t, const Size(800, 400), 4 / 3);
    expect(size.width / size.height, closeTo(4 / 3, 0.001));
    expect(size.height, lessThanOrEqualTo(400));
  });

  testWidgets('square cameras stay square', (t) async {
    final size = await frameSize(t, const Size(800, 400), 1);
    expect(size.width, closeTo(size.height, 0.001));
  });
}

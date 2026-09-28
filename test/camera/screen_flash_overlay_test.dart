import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/features/camera/screen_flash_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('github.com/aaassseee/screen_brightness');
  final calls = <MethodCall>[];
  var applicationBrightness = 0.4;

  setUp(() {
    calls.clear();
    applicationBrightness = 0.4;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getApplicationScreenBrightness':
          return applicationBrightness;
        case 'setApplicationScreenBrightness':
          final args = call.arguments as Map<Object?, Object?>;
          applicationBrightness = args['brightness']! as double;
          return null;
        case 'resetApplicationScreenBrightness':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('engage shows the overlay and cranks brightness to max', () async {
    final controller = ScreenFlashController();
    addTearDown(controller.dispose);

    await controller.engage();

    expect(controller.visible.value, isTrue);
    expect(applicationBrightness, 1);
  });

  test('disengage hides the overlay and restores prior brightness', () async {
    final controller = ScreenFlashController();
    addTearDown(controller.dispose);

    await controller.engage();
    await controller.disengage();

    expect(controller.visible.value, isFalse);
    expect(applicationBrightness, 0.4);
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/app/app.dart';

void main() {
  // No real camera hardware under `flutter test` — stub the `camera`
  // plugin's method channel to report no cameras, so CameraScreen settles
  // deterministically on its error state instead of throwing
  // MissingPluginException.
  const cameraChannel = MethodChannel('plugins.flutter.io/camera');

  setUp(() {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, (call) async {
      if (call.method == 'availableCameras') return <Object?>[];
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, null);
  });

  testWidgets('app boots to the camera screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShuttrApp()));
    await tester.pumpAndSettle();

    // No cameras in the test environment, so CameraScreen settles on its
    // error state rather than a live preview — this just proves the app
    // boots and routes to /camera without crashing.
    expect(find.textContaining("Couldn't start the camera"), findsOneWidget);
  });
}

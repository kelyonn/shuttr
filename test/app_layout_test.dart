import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuttr/app/app.dart';
import 'package:shuttr/features/settings/settings_repository.dart';

/// The screens must fit small and normal phones without overflowing.
/// Layout overflows throw in tests, so a clean pump is the assertion.
void main() {
  const cameraChannel = MethodChannel('plugins.flutter.io/camera');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, (call) async {
          if (call.method == 'availableCameras') return <Object?>[];
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, null);
  });

  Future<void> boot(
    WidgetTester tester, {
    required Size size,
    required bool onboarded,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'onboarded': onboarded,
      'coachMarksSeen': true,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const ShuttrApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  const portraitSmall = Size(360, 640);
  const portrait = Size(412, 915);

  for (final size in [portraitSmall, portrait]) {
    final name = size == portraitSmall ? 'small' : 'normal';

    testWidgets('camera screen lays out $name', (tester) async {
      await boot(tester, size: size, onboarded: true);
      expect(find.text('SHOOT'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Opening the camera picker must still fit.
      await tester.tap(find.text('OPEN +'));
      await tester.pumpAndSettle();
      expect(find.text('CLOSE −'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onboarding lays out $name', (tester) async {
      await boot(tester, size: size, onboarded: false);
      expect(find.text('NEXT'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

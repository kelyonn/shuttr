import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuttr/features/looks/date_stamp.dart';
import 'package:shuttr/features/settings/settings_repository.dart';

void main() {
  Future<ProviderContainer> buildContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('defaults to no date-stamp override and mirror off', () async {
    final container = await buildContainer();

    final settings = container.read(settingsProvider);

    expect(settings.dateStampOverride, isNull);
    expect(settings.mirrorFrontPhotos, isFalse);
  });

  test('setDateStamp updates state and persists across a rebuild', () async {
    final container = await buildContainer();
    const settings = DateStampSettings(
      enabled: true,
      format: DateStampFormat.isoDotted,
      position: DateStampPosition.topRight,
      colorStyle: DateStampColorStyle.white,
      yearOverride: 1999,
    );

    await container.read(settingsProvider.notifier).setDateStamp(settings);

    expect(container.read(settingsProvider).dateStampOverride?.enabled, true);
    expect(
      container.read(settingsProvider).dateStampOverride?.format,
      DateStampFormat.isoDotted,
    );

    // A fresh container reads from the same SharedPreferences instance —
    // simulates the app restarting.
    final prefs = await SharedPreferences.getInstance();
    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);

    final reloaded = restarted.read(settingsProvider).dateStampOverride;
    expect(reloaded?.enabled, true);
    expect(reloaded?.yearOverride, 1999);
    expect(reloaded?.colorStyle, DateStampColorStyle.white);
  });

  test('setMirrorFrontPhotos updates state and persists', () async {
    final container = await buildContainer();

    await container.read(settingsProvider.notifier).setMirrorFrontPhotos(true);

    expect(container.read(settingsProvider).mirrorFrontPhotos, isTrue);

    final prefs = await SharedPreferences.getInstance();
    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);
    expect(restarted.read(settingsProvider).mirrorFrontPhotos, isTrue);
  });
}

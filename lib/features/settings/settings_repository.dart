import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuttr/features/looks/date_stamp.dart';

/// Overridden in `main()` once `SharedPreferences.getInstance()` resolves,
/// so the rest of the app can read settings synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  );
});

/// The user-facing settings a capture needs (S17). `dateStampOverride` is
/// null until the user has visited Settings and changed something — until
/// then, each look's own `dateStampDefaultOn` decides (docs/LOOKS.md);
/// after that, this one setting applies to every look, matching Settings
/// being a single global screen rather than a per-look one.
class SettingsState {
  const new({
    required this.dateStampOverride,
    required this.mirrorFrontPhotos,
  });

  final DateStampSettings? dateStampOverride;
  final bool mirrorFrontPhotos;
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _dateStampKey = 'dateStamp.override';
  static const _mirrorFrontPhotosKey = 'mirrorFrontPhotos';

  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final dateStampJson = prefs.getString(_dateStampKey);
    return SettingsState(
      dateStampOverride: dateStampJson == null
          ? null
          : DateStampSettings.fromJson(
              jsonDecode(dateStampJson) as Map<String, dynamic>,
            ),
      // Selfies land the same way they'll be seen by others by default;
      // mirroring to match the viewfinder is opt-in.
      mirrorFrontPhotos: prefs.getBool(_mirrorFrontPhotosKey) ?? false,
    );
  }

  Future<void> setDateStamp(DateStampSettings settings) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_dateStampKey, jsonEncode(settings.toJson()));
    state = SettingsState(
      dateStampOverride: settings,
      mirrorFrontPhotos: state.mirrorFrontPhotos,
    );
  }

  // Kept positional so it tears off directly as a `ValueChanged<bool>` for
  // SwitchListTile.onChanged.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setMirrorFrontPhotos(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_mirrorFrontPhotosKey, value);
    state = SettingsState(
      dateStampOverride: state.dateStampOverride,
      mirrorFrontPhotos: value,
    );
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

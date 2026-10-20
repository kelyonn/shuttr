import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuttr/app/theme.dart';
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
    this.mirrorCount = false,
    this.bodyTheme = CameraBodyTheme.bone,
    this.rollMode = false,
    this.happyAccidents = false,
    this.authenticViewfinder = false,
  });

  final DateStampSettings? dateStampOverride;
  final bool mirrorFrontPhotos;

  /// Rear-lens 3-2-1 countdown before the shutter fires, for mirror shots.
  final bool mirrorCount;
  final CameraBodyTheme bodyTheme;

  /// 27 exposures per roll, no peeking until the roll is developed.
  final bool rollMode;

  /// Per-shot exposure drift, rare flash misfires, rare missed focus.
  final bool happyAccidents;

  /// Viewfinder shows the camera's own finder (tiny LCD / optical window)
  /// instead of the graded look preview.
  final bool authenticViewfinder;

  SettingsState copyWith({
    DateStampSettings? dateStampOverride,
    bool? mirrorFrontPhotos,
    bool? mirrorCount,
    CameraBodyTheme? bodyTheme,
    bool? rollMode,
    bool? happyAccidents,
    bool? authenticViewfinder,
  }) {
    return SettingsState(
      dateStampOverride: dateStampOverride ?? this.dateStampOverride,
      mirrorFrontPhotos: mirrorFrontPhotos ?? this.mirrorFrontPhotos,
      mirrorCount: mirrorCount ?? this.mirrorCount,
      bodyTheme: bodyTheme ?? this.bodyTheme,
      rollMode: rollMode ?? this.rollMode,
      happyAccidents: happyAccidents ?? this.happyAccidents,
      authenticViewfinder: authenticViewfinder ?? this.authenticViewfinder,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _dateStampKey = 'dateStamp.override';
  static const _mirrorFrontPhotosKey = 'mirrorFrontPhotos';
  static const _mirrorCountKey = 'mirrorCount';
  static const _bodyThemeKey = 'bodyTheme';
  static const _rollModeKey = 'rollMode';
  static const _happyAccidentsKey = 'happyAccidents';
  static const _authenticViewfinderKey = 'authenticViewfinder';

  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final dateStampJson = prefs.getString(_dateStampKey);
    final bodyName = prefs.getString(_bodyThemeKey);
    return SettingsState(
      dateStampOverride: dateStampJson == null
          ? null
          : DateStampSettings.fromJson(
              jsonDecode(dateStampJson) as Map<String, dynamic>,
            ),
      // Selfies land the same way they'll be seen by others by default;
      // mirroring to match the viewfinder is opt-in.
      mirrorFrontPhotos: prefs.getBool(_mirrorFrontPhotosKey) ?? false,
      mirrorCount: prefs.getBool(_mirrorCountKey) ?? false,
      bodyTheme:
          CameraBodyTheme.values.asNameMap()[bodyName] ?? CameraBodyTheme.bone,
      rollMode: prefs.getBool(_rollModeKey) ?? false,
      happyAccidents: prefs.getBool(_happyAccidentsKey) ?? false,
      authenticViewfinder: prefs.getBool(_authenticViewfinderKey) ?? false,
    );
  }

  Future<void> setDateStamp(DateStampSettings settings) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_dateStampKey, jsonEncode(settings.toJson()));
    state = state.copyWith(dateStampOverride: settings);
  }

  // Kept positional so it tears off directly as a `ValueChanged<bool>`.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setMirrorFrontPhotos(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_mirrorFrontPhotosKey, value);
    state = state.copyWith(mirrorFrontPhotos: value);
  }

  // Positional so it tears off as a ValueChanged<bool>, like the one above.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setMirrorCount(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_mirrorCountKey, value);
    state = state.copyWith(mirrorCount: value);
  }

  // Positional so it tears off as a ValueChanged<bool>.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setRollMode(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(_rollModeKey, value);
    state = state.copyWith(rollMode: value);
  }

  // Positional so it tears off as a ValueChanged<bool>.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setHappyAccidents(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_happyAccidentsKey, value);
    state = state.copyWith(happyAccidents: value);
  }

  // Positional so it tears off as a ValueChanged<bool>.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setAuthenticViewfinder(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_authenticViewfinderKey, value);
    state = state.copyWith(authenticViewfinder: value);
  }

  Future<void> setBodyTheme(CameraBodyTheme theme) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_bodyThemeKey, theme.name);
    state = state.copyWith(bodyTheme: theme);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

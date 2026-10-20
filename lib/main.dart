import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuttr/app/app.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/features/paywall/entitlement_repository.dart';
import 'package:shuttr/features/settings/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only, like a normal camera app: the screen never flips. The
  // controls' labels turn to face you when the phone is held sideways, and
  // the photo is still saved in the orientation it was shot in.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  // Anything deleted last session and not undone is gone for good.
  unawaited(PhotoStore().emptyTrash());

  // Pass the RevenueCat key at build time: --dart-define=RC_API_KEY=goog_...
  // (never committed). Without it nothing is for sale and the paywall says so.
  const revenueCatKey = String.fromEnvironment('RC_API_KEY');
  final entitlements = revenueCatKey.isEmpty
      ? const DisabledEntitlementRepository()
      : await RevenueCatEntitlementRepository.create(revenueCatKey);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        entitlementRepositoryProvider.overrideWithValue(entitlements),
      ],
      child: const ShuttrApp(),
    ),
  );
}

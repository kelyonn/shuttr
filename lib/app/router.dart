import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shuttr/core/ui/shuttr_route.dart';
import 'package:shuttr/features/camera/camera_screen.dart';
import 'package:shuttr/features/gallery/gallery_screen.dart';
import 'package:shuttr/features/looks/tuning/tuning_screen.dart';
import 'package:shuttr/features/onboarding/onboarding_screen.dart';
import 'package:shuttr/features/paywall/paywall_screen.dart';
import 'package:shuttr/features/settings/settings_repository.dart';
import 'package:shuttr/features/settings/settings_screen.dart';

/// Top-level route paths.
///
/// Real screens land feature-by-feature per docs/BUILD_PLAN.md:
/// - `/camera`  → S13, done (camera screen)
/// - `/gallery` → S18, done (in-app gallery)
/// - `/settings` → S17, done (settings screen)
/// - `/debug/tuning` → S5, kDebugMode only
abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const camera = '/camera';
  static const gallery = '/gallery';
  static const settings = '/settings';
  static const paywall = '/paywall';
  static const debugTuning = '/debug/tuning';
}

CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: shuttrRouteIn,
    reverseTransitionDuration: shuttrRouteOut,
    transitionsBuilder: shuttrTransition,
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final onboarded =
      ref.read(sharedPreferencesProvider).getBool(onboardedKey) ?? false;
  return GoRouter(
    initialLocation: onboarded ? AppRoutes.camera : AppRoutes.onboarding,
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) => _page(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: AppRoutes.camera,
        pageBuilder: (context, state) => _page(state, const CameraScreen()),
      ),
      GoRoute(
        path: AppRoutes.gallery,
        pageBuilder: (context, state) => _page(state, const GalleryScreen()),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) => _page(state, const SettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.paywall,
        pageBuilder: (context, state) => _page(state, const PaywallScreen()),
      ),
      // Debug builds only: never reachable in a release.
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.debugTuning,
          pageBuilder: (context, state) => _page(state, const TuningScreen()),
        ),
    ],
  );
});

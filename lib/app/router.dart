import 'package:go_router/go_router.dart';
import 'package:shuttr/features/camera/camera_screen.dart';
import 'package:shuttr/features/gallery/gallery_screen.dart';
import 'package:shuttr/features/looks/tuning/tuning_screen.dart';
import 'package:shuttr/features/settings/settings_screen.dart';

/// Top-level route paths.
///
/// Real screens land feature-by-feature per docs/BUILD_PLAN.md:
/// - `/camera`  → S13, done (camera screen)
/// - `/gallery` → S18, done (in-app gallery)
/// - `/settings` → S17, done (settings screen)
/// - `/debug/tuning` → S5, kDebugMode only
abstract final class AppRoutes {
  static const camera = '/camera';
  static const gallery = '/gallery';
  static const settings = '/settings';
  static const debugTuning = '/debug/tuning';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.camera,
  routes: [
    GoRoute(
      path: AppRoutes.camera,
      builder: (context, state) => const CameraScreen(),
    ),
    GoRoute(
      path: AppRoutes.gallery,
      builder: (context, state) => const GalleryScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.debugTuning,
      builder: (context, state) => const TuningScreen(),
    ),
  ],
);

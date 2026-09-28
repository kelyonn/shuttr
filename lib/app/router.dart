import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Top-level route paths.
///
/// Real screens land feature-by-feature per docs/BUILD_PLAN.md:
/// - `/camera`  → S13 (camera screen)
/// - `/gallery` → S18 (in-app gallery)
/// - `/settings` → S17
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
      builder: (context, state) => const _PlaceholderScreen(title: 'Camera'),
    ),
    GoRoute(
      path: AppRoutes.gallery,
      builder: (context, state) => const _PlaceholderScreen(title: 'Gallery'),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const _PlaceholderScreen(title: 'Settings'),
    ),
    GoRoute(
      path: AppRoutes.debugTuning,
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Tuning (debug)'),
    ),
  ],
);

/// Scaffolding-only placeholder. Each route above is replaced by its real
/// screen in the session that builds that feature (docs/BUILD_PLAN.md).
class _PlaceholderScreen extends StatelessWidget {
  const new({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title screen — not built yet')),
    );
  }
}

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Everything the camera screen needs to render a live preview and drive
/// its controls; wraps the plugin's [CameraController] plus the two bits of
/// state it doesn't expose reactively (which lens, which flash mode).
class CameraControllerState {
  const new({
    required this.controller,
    required this.lensDirection,
    required this.flashMode,
  });

  final CameraController controller;
  final CameraLensDirection lensDirection;
  final FlashMode flashMode;

  /// Front cameras have no hardware flash — screen flash (S14) is a
  /// capture-time overlay, not a [CameraController] flash mode.
  bool get supportsFlash => lensDirection == CameraLensDirection.back;
}

/// Owns the [CameraController] lifecycle: picking a camera, switching
/// lenses, cycling flash mode, and disposing/reinitializing across
/// backgrounding (driven by the camera screen's `WidgetsBindingObserver`,
/// which calls [pause]/[resume]).
class CameraControllerNotifier extends AsyncNotifier<CameraControllerState> {
  List<CameraDescription> _cameras = [];

  // Tracked separately from `state` because Riverpod forbids reading `state`
  // (it goes through `Ref`) inside the `onDispose` lifecycle callback below.
  CameraController? _activeController;

  @override
  Future<CameraControllerState> build() async {
    ref.onDispose(() {
      final controller = _activeController;
      if (controller != null) unawaited(controller.dispose());
    });

    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw StateError('No cameras available on this device');
    }
    return await _open(
      lensDirection: CameraLensDirection.back,
      flashMode: FlashMode.off,
    );
  }

  Future<CameraControllerState> _open({
    required CameraLensDirection lensDirection,
    required FlashMode flashMode,
  }) async {
    final description = _cameras.firstWhere(
      (c) => c.lensDirection == lensDirection,
      orElse: () => _cameras.first,
    );
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller.initialize();
    _activeController = controller;

    final resolvedDirection = description.lensDirection;
    if (resolvedDirection == CameraLensDirection.back) {
      await controller.setFlashMode(flashMode);
    }

    return CameraControllerState(
      controller: controller,
      lensDirection: resolvedDirection,
      flashMode: resolvedDirection == CameraLensDirection.back
          ? flashMode
          : FlashMode.off,
    );
  }

  Future<void> switchLens() async {
    final current = state.value;
    if (current == null || _cameras.length < 2) return;

    final nextDirection = current.lensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    state = const AsyncLoading();
    await current.controller.dispose();
    state = await AsyncValue.guard(
      () => _open(lensDirection: nextDirection, flashMode: FlashMode.off),
    );
  }

  Future<void> cycleFlashMode() async {
    final current = state.value;
    if (current == null || !current.supportsFlash) return;

    final FlashMode next;
    if (current.flashMode == FlashMode.off) {
      next = FlashMode.auto;
    } else if (current.flashMode == FlashMode.auto) {
      next = FlashMode.always;
    } else {
      next = FlashMode.off;
    }

    await current.controller.setFlashMode(next);
    state = AsyncData(
      CameraControllerState(
        controller: current.controller,
        lensDirection: current.lensDirection,
        flashMode: next,
      ),
    );
  }

  /// Called when the app is backgrounded — releases the camera so other
  /// apps (or the OS) can use it, per CLAUDE.md's rotate/background pass.
  Future<void> pause() async {
    final current = state.value;
    if (current == null) return;
    await current.controller.dispose();
  }

  /// Called on resume — reopens the camera with the lens/flash mode it had
  /// before pausing.
  Future<void> resume() async {
    final current = state.value;
    final lensDirection = current?.lensDirection ?? CameraLensDirection.back;
    final flashMode = current?.flashMode ?? FlashMode.off;

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _open(lensDirection: lensDirection, flashMode: flashMode),
    );
  }
}

final cameraControllerProvider =
    AsyncNotifierProvider<CameraControllerNotifier, CameraControllerState>(
      CameraControllerNotifier.new,
    );

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

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

  /// Video mode opens the camera with the microphone; photo mode never
  /// touches it.
  bool _audio = false;
  bool _video = false;

  // What to reopen with after a pause, kept here because `state` is loading
  // (no controller) while paused.
  CameraLensDirection _lens = CameraLensDirection.back;
  FlashMode _flash = FlashMode.off;
  bool _paused = false;

  /// Every open/close runs one after another. Without this, a system dialog
  /// (pause → resume) racing a lens or mode switch could open two
  /// controllers, or leave the preview holding a disposed one.
  Future<void> _queue = Future.value();

  Future<void> _serial(Future<void> Function() job) {
    final next = _queue.then((_) => job());
    _queue = next.catchError((Object _) {});
    return next;
  }

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
    return await _open(lensDirection: _lens, flashMode: _flash);
  }

  Future<CameraControllerState> _open({
    required CameraLensDirection lensDirection,
    required FlashMode flashMode,
  }) async {
    final description = _cameras.firstWhere(
      (c) => c.lensDirection == lensDirection,
      orElse: () => _cameras.first,
    );
    // `high` is only 720p on Android: the preview got stretched to fill the
    // screen (soft, "blurry") and stills came out at ~1 MP. Photos ask for
    // the 4K-class stream on the rear lens (~8 MP, enough for every look's
    // 3–5 MP output); video is capped at 1080p (CLAUDE.md rule 5).
    final preset =
        _video || description.lensDirection != CameraLensDirection.back
        ? ResolutionPreset.veryHigh
        : ResolutionPreset.ultraHigh;
    final controller = CameraController(
      description,
      preset,
      enableAudio: _audio,
    );
    await controller.initialize();
    // Continuous autofocus/auto-exposure, set explicitly so a previous
    // session's state can never leave the focus locked.
    try {
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
    } on CameraException {
      // Not every lens supports both; the defaults are fine.
    }
    _activeController = controller;

    final resolvedDirection = description.lensDirection;
    final resolvedFlash = resolvedDirection == CameraLensDirection.back
        ? flashMode
        : FlashMode.off;
    if (resolvedDirection == CameraLensDirection.back) {
      await controller.setFlashMode(resolvedFlash);
    }
    _lens = resolvedDirection;
    _flash = resolvedFlash;

    return CameraControllerState(
      controller: controller,
      lensDirection: resolvedDirection,
      flashMode: resolvedFlash,
    );
  }

  /// Closes the current controller, taking it out of `state` first so the
  /// preview never builds with a disposed controller.
  Future<void> _close() async {
    final controller = _activeController;
    _activeController = null;
    state = const AsyncLoading();
    await controller?.dispose();
  }

  Future<void> _reopen({CameraLensDirection? lens, FlashMode? flash}) async {
    await _close();
    if (_paused) return;
    state = await AsyncValue.guard(
      () => _open(lensDirection: lens ?? _lens, flashMode: flash ?? _flash),
    );
  }

  Future<void> switchLens() => _serial(() async {
    if (_cameras.length < 2 || _paused) return;
    final next = _lens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    await _reopen(lens: next, flash: FlashMode.off);
  });

  Future<void> cycleFlashMode() => _serial(() async {
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
    await _setFlash(current, next);
  });

  Future<void> _setFlash(CameraControllerState current, FlashMode mode) async {
    await current.controller.setFlashMode(mode);
    _flash = mode;
    state = AsyncData(
      CameraControllerState(
        controller: current.controller,
        lensDirection: current.lensDirection,
        flashMode: mode,
      ),
    );
  }

  /// Switches between photo and video. Video reopens the camera with sound
  /// if the microphone is allowed, and silently without it if not (the
  /// camcorder looks still work, just mute).
  Future<void> setVideoMode({required bool video}) async {
    // Asked outside the queue: the permission dialog itself pauses and
    // resumes the app, which has to be able to run meanwhile.
    final wantAudio =
        video && (await Permission.microphone.request()).isGranted;
    await _serial(() async {
      if (wantAudio == _audio && video == _video && state.value != null) return;
      _audio = wantAudio;
      _video = video;
      await _reopen(flash: FlashMode.off);
    });
  }

  /// The camcorder light: torch on/off while filming.
  Future<void> setTorch({required bool on}) => _serial(() async {
    final current = state.value;
    if (current == null || !current.supportsFlash) return;
    await _setFlash(current, on ? FlashMode.torch : FlashMode.off);
  });

  /// Called when the app is backgrounded (or a system dialog covers it) —
  /// releases the camera so other apps (or the OS) can use it.
  Future<void> pause() => _serial(() async {
    if (_paused) return;
    _paused = true;
    // Coming back, the torch should be off like a real light switch.
    if (_flash == FlashMode.torch) _flash = FlashMode.off;
    await _close();
  });

  /// Called on resume — reopens the camera with the lens/flash mode it had
  /// before pausing.
  Future<void> resume() => _serial(() async {
    if (!_paused && state.value != null) return;
    _paused = false;
    await _reopen();
  });
}

final cameraControllerProvider =
    AsyncNotifierProvider<CameraControllerNotifier, CameraControllerState>(
      CameraControllerNotifier.new,
    );

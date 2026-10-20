import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shuttr/app/router.dart';
import 'package:shuttr/app/theme.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/core/storage/roll_count.dart';
import 'package:shuttr/core/ui/shuttr_route.dart';
import 'package:shuttr/core/ui/shuttr_ui.dart';
import 'package:shuttr/features/camera/body/camera_card.dart';
import 'package:shuttr/features/camera/body/camera_dash.dart';
import 'package:shuttr/features/camera/camera_controller_provider.dart';
import 'package:shuttr/features/camera/camera_permission_view.dart';
import 'package:shuttr/features/camera/capture_service.dart';
import 'package:shuttr/features/camera/character/camera_haptics.dart';
import 'package:shuttr/features/camera/coach_marks.dart';
import 'package:shuttr/features/camera/review_screen.dart';
import 'package:shuttr/features/camera/roll_mode.dart';
import 'package:shuttr/features/camera/screen_flash_overlay.dart';
import 'package:shuttr/features/camera/viewfinder_gestures.dart';
import 'package:shuttr/features/looks/date_stamp.dart';
import 'package:shuttr/features/looks/look_registry.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/render/asset_image_cache.dart';
import 'package:shuttr/features/looks/render/shader_uniforms.dart';
import 'package:shuttr/features/settings/settings_repository.dart';
import 'package:shuttr/features/video/video_looks.dart';
import 'package:shuttr/features/video/video_review_screen.dart';

/// S13/S14/S16: the real camera screen. Owns app-lifecycle wiring
/// (pause/resume the camera when backgrounded), the current look for the
/// live preview shader and mode dial, the body colour theme, and the
/// shutter → capture → review flow (screen flash, mirror selfie).
class CameraScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  // Digi '03 is the hero free look and first entry in the registry, so
  // it's the sensible default; the mode dial changes this.
  LookSpec _selectedLook = looks.first;
  bool _pickerOpen = false;
  final _captureService = CaptureService();
  final _screenFlash = ScreenFlashController();

  /// Brief black-out after the shutter in roll mode: the only feedback you
  /// get, like the mirror/shutter blinking the finder on a real camera.
  bool _blink = false;

  bool _frontScreenFlashOn = false;
  int? _countdown;
  bool _busy = false;

  // Video mode (camcorder looks).
  bool _video = false;
  LookSpec _videoLook = videoPreviewLooks.first;
  bool _recording = false;
  DateTime? _recStart;
  Timer? _recTimer;
  Duration _recElapsed = Duration.zero;
  bool _torch = false;
  static const _maxClip = Duration(minutes: 3);

  LookSpec get _activeLook => _video ? _videoLook : _selectedLook;

  /// A clip that was still rolling when the app lost the camera; it's
  /// finished and offered for review when the app comes back.
  String? _rescuedClip;
  DateTime? _rescuedStart;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final prefs = ref.read(sharedPreferencesProvider);
    final photoId = prefs.getString('lastLook');
    final videoId = prefs.getString('lastVideoLook');
    _selectedLook = looks.firstWhere(
      (l) => l.id == photoId,
      orElse: () => looks.first,
    );
    _videoLook = videoPreviewLooks.firstWhere(
      (l) => l.id == videoId,
      orElse: () => videoPreviewLooks.first,
    );
  }

  void _pickLook(LookSpec look) {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      if (look.id.startsWith('video_')) {
        _videoLook = look;
        unawaited(prefs.setString('lastVideoLook', look.id));
      } else {
        _selectedLook = look;
        unawaited(prefs.setString('lastLook', look.id));
      }
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recTimer?.cancel();
    _screenFlash.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(cameraControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        // Releasing the camera ends any recording; finish it properly so
        // the footage isn't lost, and offer it for review on return.
        if (_recording) unawaited(_rescueRecording());
        if (_torch) setState(() => _torch = false);
        unawaited(notifier.pause());
      case AppLifecycleState.resumed:
        unawaited(notifier.resume().then((_) => _reviewRescuedClip()));
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _rescueRecording() async {
    final controller = ref.read(cameraControllerProvider).value?.controller;
    _recTimer?.cancel();
    final start = _recStart;
    setState(() => _recording = false);
    if (controller == null) return;
    try {
      final file = await controller.stopVideoRecording();
      _rescuedClip = file.path;
      _rescuedStart = start;
    } on Object {
      // Nothing usable was written.
    }
  }

  Future<void> _reviewRescuedClip() async {
    final path = _rescuedClip;
    if (path == null || !mounted) return;
    _rescuedClip = null;
    await Navigator.of(context).push<bool>(
      ShuttrRoute(
        builder: (_) => VideoReviewScreen(
          sourcePath: path,
          look: videoLookForPreview(_videoLook),
          startedAt: _rescuedStart ?? DateTime.now(),
        ),
      ),
    );
  }

  bool _cancelCountdown = false;

  /// Returns false if the shutter was tapped again to cancel.
  Future<bool> _runCountdown(int seconds) async {
    _cancelCountdown = false;
    for (var i = seconds; i > 0; i--) {
      if (!mounted || _cancelCountdown) break;
      setState(() => _countdown = i);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    final ok = mounted && !_cancelCountdown;
    if (mounted) setState(() => _countdown = null);
    return ok;
  }

  Future<void> _setVideoMode(bool video) async {
    if (video == _video || _recording) return;
    setState(() {
      _video = video;
      _torch = false;
    });
    if (video) _snack('Clips develop into the look after you stop.');
    await ref
        .read(cameraControllerProvider.notifier)
        .setVideoMode(video: video);
  }

  /// REC / STOP. Recording is plain (the preview shows a cheap version of
  /// the look); the full camcorder look develops afterwards.
  Future<void> _toggleRecording() async {
    final camState = ref.read(cameraControllerProvider).value;
    if (camState == null) return;
    final controller = camState.controller;

    if (!_recording) {
      try {
        await controller.startVideoRecording();
      } on Object {
        _snack("Couldn't start recording. Try again.");
        return;
      }
      unawaited(HapticFeedback.mediumImpact());
      setState(() {
        _recording = true;
        _recStart = DateTime.now();
        _recElapsed = Duration.zero;
      });
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final start = _recStart;
        if (!mounted || start == null) return;
        setState(() => _recElapsed = DateTime.now().difference(start));
        if (_recElapsed >= _maxClip) unawaited(_toggleRecording());
      });
      return;
    }

    _recTimer?.cancel();
    setState(() => _recording = false);
    final XFile file;
    try {
      file = await controller.stopVideoRecording();
    } on Object {
      _snack("That clip couldn't be saved.");
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      ShuttrRoute(
        builder: (_) => VideoReviewScreen(
          sourcePath: file.path,
          look: videoLookForPreview(_videoLook),
          startedAt: _recStart ?? DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _handleShutter() async {
    if (_video) return await _toggleRecording();
    if (_countdown != null) {
      _cancelCountdown = true;
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (ref.read(settingsProvider).mirrorCount) {
        if (!await _runCountdown(3)) return;
      }

      final camState = ref.read(cameraControllerProvider).value;
      if (camState == null) return;

      final isFront = camState.lensDirection == CameraLensDirection.front;
      final useScreenFlash = isFront && _frontScreenFlashOn;
      // A timed shot on the rear lens is a mirror shot: the light is real.
      final softFlash =
          (ref.read(settingsProvider).mirrorCount && !isFront) ||
          useScreenFlash;
      final flashFired = camState.flashMode != FlashMode.off;
      final settings = ref.read(settingsProvider);

      final look = _selectedLook;
      final nextFrame = nextFrameNumber(ref);
      unawaited(useFrameNumber(ref, nextFrame));
      final frameLabel = 'NO.${nextFrame.toString().padLeft(3, '0')}';
      final pending = await _captureService.capture(
        controller: camState.controller,
        spec: look,
        flashFired: flashFired,
        softFlash: softFlash,
        mirror: isFront && settings.mirrorFrontPhotos,
        happyAccidents: settings.happyAccidents,
        dateStampOverride: settings.dateStampOverride,
        beforeCapture: () async {
          if (useScreenFlash) await _screenFlash.engage();
          CameraHaptics.shutter();
        },
        afterCapture: useScreenFlash ? _screenFlash.disengage : null,
      );
      CameraHaptics.advance(look.soundSet);

      if (!mounted) return;
      if (settings.rollMode) {
        setState(() => _blink = true);
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 120)).then((_) {
            if (mounted) setState(() => _blink = false);
          }),
        );
        unawaited(_exposeOnRoll(pending));
        return;
      }

      await Navigator.of(context).push<void>(
        ShuttrRoute(
          builder: (_) => ReviewScreen(
            pending: pending,
            spec: look,
            frameLabel: frameLabel,
          ),
        ),
      );
      ref
        ..invalidate(rollCountProvider)
        ..invalidate(latestPhotoProvider);
    } on Object {
      _snack("Couldn't take that photo. Try again.");
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _countdown = null;
        });
      }
    }
  }

  /// Roll mode: the frame develops in the background, straight onto the
  /// roll. The last frame of the roll develops the whole thing.
  Future<void> _exposeOnRoll(PendingCapture pending) async {
    await RollQueue.add(pending);
    if (!mounted) return;
    ref.invalidate(exposuresOnRollProvider);
    final store = PhotoStore();
    if (await store.exposuresOnRoll() >= rollLength &&
        inFlightFrames.value == 0) {
      final n = await store.developRoll();
      if (!mounted) return;
      ref
        ..invalidate(exposuresOnRollProvider)
        ..invalidate(rollCountProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Roll finished. $n frames developed.')),
      );
    }
  }

  Future<void> _openRoll() async {
    await context.push<void>(AppRoutes.gallery);
    ref
      ..invalidate(rollCountProvider)
      ..invalidate(latestPhotoProvider);
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraControllerProvider);
    final settings = ref.watch(settingsProvider);
    final rollCount = ref.watch(rollCountProvider).value ?? 0;
    final latestPhoto = ref.watch(latestPhotoProvider).value;
    final paper = settings.bodyTheme.paperColor;
    final camState = cameraState.value;
    final isFront = camState?.lensDirection == CameraLensDirection.front;

    final String flashLabel;
    final bool flashOn;
    if (camState == null) {
      flashLabel = 'OFF';
      flashOn = false;
    } else if (_video) {
      flashLabel = _torch ? 'LIGHT' : 'OFF';
      flashOn = _torch;
    } else if (isFront) {
      flashLabel = _frontScreenFlashOn ? 'ON' : 'OFF';
      flashOn = _frontScreenFlashOn;
    } else {
      flashLabel = switch (camState.flashMode) {
        FlashMode.off => 'OFF',
        FlashMode.auto => 'AUTO',
        FlashMode.always || FlashMode.torch => 'ON',
      };
      flashOn = camState.flashMode != FlashMode.off;
    }

    final exposed =
        (ref.watch(exposuresOnRollProvider).value ?? 0) + inFlightFrames.value;
    final recSeconds = (_recElapsed.inSeconds % 60).toString().padLeft(2, '0');
    final recClock = '${_recElapsed.inMinutes}:$recSeconds';
    final frameNo = _video
        ? (_recording ? '● REC $recClock' : 'STBY')
        : settings.rollMode
        ? 'EXP ${(exposed + 1).clamp(1, rollLength).toString().padLeft(2, '0')}'
              '/$rollLength'
        : 'NO.${nextFrameNumber(ref).toString().padLeft(3, '0')}';
    final previewMode =
        _video ||
            !settings.authenticViewfinder ||
            _selectedLook.viewfinder == ViewfinderKind.clean
        ? PreviewMode.look
        : (_selectedLook.viewfinder == ViewfinderKind.lcd
              ? PreviewMode.lcd
              : PreviewMode.optical);
    final lensLabel = isFront ? 'FRONT' : 'REAR';

    final stamp = settings.dateStampOverride;
    final stampText = stamp != null && stamp.enabled
        ? formatDateStamp(DateTime.now(), stamp)
        : null;

    final photo = cameraState.when(
      data: (data) => ValueListenableBuilder<CameraValue>(
        // Rebuild when the phone turns, so the frame follows at once
        // instead of keeping the previous orientation's shape.
        valueListenable: data.controller,
        builder: (context, value, _) {
          final o = value.deviceOrientation;
          final sideways =
              o == DeviceOrientation.landscapeLeft ||
              o == DeviceOrientation.landscapeRight;
          // The frame is the shape the photo will be cropped to: the
          // camera's own format, turned on its side when the phone is.
          final ratio = _activeLook.aspectRatio;
          return ViewfinderGestures(
            key: ObjectKey(data.controller),
            controller: data.controller,
            child: CameraFrame(
              aspect: sideways ? ratio : 1 / ratio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ShaderCameraPreview(
                    camState: data,
                    spec: _activeLook,
                    mode: previewMode,
                  ),
                  if (stampText != null &&
                      !_video &&
                      previewMode != PreviewMode.optical)
                    LiveStamp(stampText),
                  if (_blink) const ColoredBox(color: Colors.black),
                  if (_countdown != null)
                    Center(
                      child: Text(
                        '$_countdown',
                        style: Typo.display.copyWith(
                          fontSize: 140,
                          color: Palette.cream,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Palette.cream)),
      error: (error, _) => isCameraPermissionError(error)
          ? CameraPermissionView(
              onRetry: () => ref.invalidate(cameraControllerProvider),
            )
          : _CameraError(
              error: error,
              onRetry: () => ref.invalidate(cameraControllerProvider),
            ),
    );
    final plate = FilmPlate(
      frameLabel: frameNo,
      rightLabel: flashOn ? '$lensLabel · FLASH' : lensLabel,
      photo: photo,
    );

    final dash = CameraDash(
      spec: _activeLook,
      lookList: _video ? videoPreviewLooks : null,
      video: _video,
      recording: _recording,
      onMode: (v) => unawaited(_setVideoMode(v)),
      pickerOpen: _pickerOpen,
      rollCount: rollCount,
      flashLabel: flashLabel,
      flashOn: flashOn,
      lensLabel: lensLabel,
      busy: (_busy && _countdown == null) || camState == null,
      shutterLabel: _countdown != null ? 'CANCEL' : null,
      footLocked: _recording || _busy,
      onTogglePicker: () => setState(() => _pickerOpen = !_pickerOpen),
      onSelectLook: _pickLook,
      onShutter: _handleShutter,
      latestPhotoPath: latestPhoto,
      timerLabel: settings.mirrorCount ? '3S' : 'OFF',
      onTimer: () {
        if (_recording || _busy || _video) return;
        unawaited(
          ref
              .read(settingsProvider.notifier)
              .setMirrorCount(!settings.mirrorCount),
        );
      },
      onCycle: (dir) {
        if (_recording || _busy) return;
        final list = _video ? videoPreviewLooks : looks;
        final i = list.indexWhere((l) => l.id == _activeLook.id);
        _pickLook(list[(i + dir) % list.length]);
        unawaited(HapticFeedback.selectionClick());
      },
      onRoll: () {
        if (_recording || _busy) return;
        unawaited(_openRoll());
      },
      onFlash: () {
        if (_busy) return;
        if (_video) {
          setState(() => _torch = !_torch);
          unawaited(
            ref.read(cameraControllerProvider.notifier).setTorch(on: _torch),
          );
        } else if (isFront) {
          setState(() => _frontScreenFlashOn = !_frontScreenFlashOn);
        } else {
          unawaited(
            ref.read(cameraControllerProvider.notifier).cycleFlashMode(),
          );
        }
      },
      onLens: () {
        if (_recording || _busy) return;
        unawaited(ref.read(cameraControllerProvider.notifier).switchLens());
      },
      onIndex: () {
        if (_recording || _busy) return;
        unawaited(context.push<void>(AppRoutes.settings));
      },
      onInfo: (look) async {
        final use = await showCameraCard(context, look);
        if (use && mounted) _pickLook(look);
      },
    );

    final phone = camState?.controller.value.deviceOrientation;
    final turn = switch (phone) {
      DeviceOrientation.landscapeLeft => 1,
      DeviceOrientation.landscapeRight => -1,
      DeviceOrientation.portraitDown => 2,
      _ => 0,
    };

    return PhoneTurn(
      quarterTurns: turn,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: paper,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: PopScope(
          // Back closes the camera list first, and never quits mid-recording.
          canPop: !_pickerOpen && !_recording,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_pickerOpen) {
              setState(() => _pickerOpen = false);
            } else {
              _snack('Stop recording first.');
            }
          },
          child: Scaffold(
            backgroundColor: paper,
            body: Stack(
              fit: StackFit.expand,
              children: [
                PlateLayout(plate: plate, panel: dash, paper: paper),
                ScreenFlashOverlay(controller: _screenFlash),
                const CoachMarks(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Centres [child] in the plate at exactly [aspect] (width / height), as
/// large as fits, with the dark plate showing around it. No stretching, no
/// zoom-to-fill: the viewfinder is the frame the photo will have.
class CameraFrame extends StatelessWidget {
  const new({required this.aspect, required this.child, super.key});

  final double aspect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: aspect,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x33F3EBDD)),
          ),
          child: ClipRect(child: child),
        ),
      ),
    );
  }
}

/// Runs the camera preview through `shaders/preview.frag` — cheap
/// LUT+tone+vignette approximation of the selected look, per
/// docs/ARCHITECTURE.md "Preview light, render heavy". The full look.frag
/// pipeline only ever runs on the captured still.
class _ShaderCameraPreview extends StatefulWidget {
  const new({required this.camState, required this.spec, required this.mode});

  final CameraControllerState camState;
  final LookSpec spec;
  final PreviewMode mode;

  @override
  State<_ShaderCameraPreview> createState() => _ShaderCameraPreviewState();
}

class _ShaderCameraPreviewState extends State<_ShaderCameraPreview> {
  ui.FragmentProgram? _program;
  ui.Image? _lut;
  String? _lutSpecId;
  ui.FragmentShader? _shader;
  Size? _boundPhysicalSize;
  String? _boundSpecId;
  PreviewMode? _boundMode;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAssets());
  }

  @override
  void didUpdateWidget(covariant _ShaderCameraPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The mode dial (S16) can change the look between builds — reload its
    // LUT so the preview doesn't keep grading with the previous look's.
    if (oldWidget.spec.id != widget.spec.id) {
      unawaited(_loadAssets());
    }
  }

  Future<void> _loadAssets() async {
    final specId = widget.spec.id;
    final program =
        _program ?? await ui.FragmentProgram.fromAsset('shaders/preview.frag');
    final lut = await AssetImageCache.load(
      widget.spec.lutAsset ?? 'assets/luts/identity.png',
    );
    if (!mounted) return;
    setState(() {
      _program = program;
      _lut = lut;
      _lutSpecId = specId;
    });
  }

  /// (Re)binds the shader when the rendered preview's physical pixel size
  /// changes (rotation, first layout) or the selected look changes.
  /// `uSize` in preview.frag divides `FlutterFragCoord()`, which is in
  /// physical pixels, so this must be the preview's on-screen size times
  /// the device pixel ratio — needs confirming on-device that the vignette
  /// centres correctly (no way to visually verify a fragment shader from
  /// this session).
  void _bindShaderFor(Size physicalSize) {
    final program = _program;
    final lut = _lut;
    if (program == null || lut == null || _lutSpecId != widget.spec.id) {
      return;
    }
    if (_shader != null &&
        _boundPhysicalSize == physicalSize &&
        _boundSpecId == widget.spec.id &&
        _boundMode == widget.mode) {
      return;
    }

    _shader?.dispose();
    final shader = program.fragmentShader();
    bindPreviewUniforms(
      shader,
      spec: widget.spec,
      width: physicalSize.width,
      height: physicalSize.height,
      mode: widget.mode,
    );
    // Sampler 0 (uImage) is deliberately left unbound: ImageFilter.shader
    // auto-fills it with the filtered child's live rendered content — the
    // confirmed S4 spike finding
    // (integration_test/preview_shader_fps_spike_test.dart).
    shader.setImageSampler(1, lut);
    _shader = shader;
    _boundPhysicalSize = physicalSize;
    _boundSpecId = widget.spec.id;
    _boundMode = widget.mode;
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.camState.controller;
    final previewAspect = controller.value.aspectRatio;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return ValueListenableBuilder<CameraValue>(
      valueListenable: controller,
      builder: (context, value, _) => LayoutBuilder(
        builder: (context, constraints) {
          final mediaSize = constraints.biggest;

          // CameraPreview shows the sensor's landscape frame upright for the
          // phone's current orientation: landscape aspect when the phone is
          // sideways, the inverse when upright.
          final orientation = value.deviceOrientation;
          final sideways =
              orientation == DeviceOrientation.landscapeLeft ||
              orientation == DeviceOrientation.landscapeRight;
          final displayAspect = sideways ? previewAspect : 1 / previewAspect;

          // The size CameraPreview settles on inside mediaSize (contain),
          // then scaled up to cover the plate with no letterbox.
          final fittedSize = mediaSize.aspectRatio > displayAspect
              ? Size(mediaSize.height * displayAspect, mediaSize.height)
              : Size(mediaSize.width, mediaSize.width / displayAspect);
          _bindShaderFor(fittedSize * dpr);

          final scale = math.max(
            mediaSize.width / fittedSize.width,
            mediaSize.height / fittedSize.height,
          );

          final cameraPreview = CameraPreview(controller);
          final shader = _shader;
          final filtered = shader == null
              ? cameraPreview
              : ImageFiltered(
                  imageFilter: ui.ImageFilter.shader(shader),
                  child: cameraPreview,
                );

          return ClipRect(
            child: Transform.scale(
              scale: scale,
              child: Center(child: filtered),
            ),
          );
        },
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const new({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Palette.cream, size: 48),
            const SizedBox(height: 16),
            const Text(
              "Couldn't start the camera. Another app may be using it.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Palette.cream),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'TRY AGAIN',
                style: TextStyle(color: Palette.cream),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

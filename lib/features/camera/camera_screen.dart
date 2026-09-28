import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shuttr/app/theme.dart';
import 'package:shuttr/features/camera/body/lcd_frame.dart';
import 'package:shuttr/features/camera/body/look_mode_dial.dart';
import 'package:shuttr/features/camera/camera_controller_provider.dart';
import 'package:shuttr/features/camera/capture_service.dart';
import 'package:shuttr/features/camera/review_screen.dart';
import 'package:shuttr/features/camera/screen_flash_overlay.dart';
import 'package:shuttr/features/looks/look_registry.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/render/asset_image_cache.dart';
import 'package:shuttr/features/looks/render/shader_uniforms.dart';

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
  CameraBodyTheme _bodyTheme = CameraBodyTheme.chrome;
  final _captureService = CaptureService();
  final _screenFlash = ScreenFlashController();

  bool _frontScreenFlashOn = false;
  bool _mirrorSelfieMode = false;
  int? _countdown;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _screenFlash.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(cameraControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        unawaited(notifier.pause());
      case AppLifecycleState.resumed:
        unawaited(notifier.resume());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _runCountdown(int seconds) async {
    for (var i = seconds; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (mounted) setState(() => _countdown = null);
  }

  Future<void> _handleShutter() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final notifier = ref.read(cameraControllerProvider.notifier);
      if (_mirrorSelfieMode) {
        if (ref.read(cameraControllerProvider).value?.lensDirection !=
            CameraLensDirection.back) {
          await notifier.switchLens();
        }
        await _runCountdown(3);
      }

      final camState = ref.read(cameraControllerProvider).value;
      if (camState == null) return;

      final useScreenFlash =
          camState.lensDirection == CameraLensDirection.front &&
          _frontScreenFlashOn;
      final flashFired =
          _mirrorSelfieMode ||
          camState.flashMode != FlashMode.off ||
          useScreenFlash;

      final pending = await _captureService.capture(
        controller: camState.controller,
        spec: _selectedLook,
        flashFired: flashFired,
        beforeCapture: useScreenFlash ? _screenFlash.engage : null,
        afterCapture: useScreenFlash ? _screenFlash.disengage : null,
      );

      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ReviewScreen(pending: pending)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            cameraState.when(
              data: (data) => _CameraReady(
                camState: data,
                spec: _selectedLook,
                bodyTheme: _bodyTheme,
                busy: _busy,
                countdown: _countdown,
                frontScreenFlashOn: _frontScreenFlashOn,
                mirrorSelfieMode: _mirrorSelfieMode,
                onSelectLook: (look) => setState(() => _selectedLook = look),
                onToggleBodyTheme: () => setState(
                  () => _bodyTheme = _bodyTheme == CameraBodyTheme.chrome
                      ? CameraBodyTheme.pastel
                      : CameraBodyTheme.chrome,
                ),
                onSwitchLens: () =>
                    ref.read(cameraControllerProvider.notifier).switchLens(),
                onCycleFlash: () => ref
                    .read(cameraControllerProvider.notifier)
                    .cycleFlashMode(),
                onToggleFrontScreenFlash: () => setState(
                  () => _frontScreenFlashOn = !_frontScreenFlashOn,
                ),
                onToggleMirrorSelfie: () =>
                    setState(() => _mirrorSelfieMode = !_mirrorSelfieMode),
                onShutter: _handleShutter,
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (error, _) => _CameraError(error: error),
            ),
            ScreenFlashOverlay(controller: _screenFlash),
          ],
        ),
      ),
    );
  }
}

class _CameraReady extends StatelessWidget {
  const new({
    required this.camState,
    required this.spec,
    required this.bodyTheme,
    required this.busy,
    required this.countdown,
    required this.frontScreenFlashOn,
    required this.mirrorSelfieMode,
    required this.onSelectLook,
    required this.onToggleBodyTheme,
    required this.onSwitchLens,
    required this.onCycleFlash,
    required this.onToggleFrontScreenFlash,
    required this.onToggleMirrorSelfie,
    required this.onShutter,
  });

  final CameraControllerState camState;
  final LookSpec spec;
  final CameraBodyTheme bodyTheme;
  final bool busy;
  final int? countdown;
  final bool frontScreenFlashOn;
  final bool mirrorSelfieMode;
  final ValueChanged<LookSpec> onSelectLook;
  final VoidCallback onToggleBodyTheme;
  final VoidCallback onSwitchLens;
  final VoidCallback onCycleFlash;
  final VoidCallback onToggleFrontScreenFlash;
  final VoidCallback onToggleMirrorSelfie;
  final VoidCallback onShutter;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _ShaderCameraPreview(camState: camState, spec: spec),
        LcdFrame(bodyColor: bodyTheme.bodyColor),
        Positioned(
          top: 16,
          left: 16,
          child: _RoundIconButton(
            icon: Icons.palette_outlined,
            onPressed: onToggleBodyTheme,
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: _TopControls(
            camState: camState,
            frontScreenFlashOn: frontScreenFlashOn,
            mirrorSelfieMode: mirrorSelfieMode,
            onCycleFlash: onCycleFlash,
            onSwitchLens: onSwitchLens,
            onToggleFrontScreenFlash: onToggleFrontScreenFlash,
            onToggleMirrorSelfie: onToggleMirrorSelfie,
          ),
        ),
        if (countdown != null)
          Center(
            child: Text(
              '$countdown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 96,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LookModeDial(
                selected: spec,
                accentColor: bodyTheme.accentColor,
                onSelect: onSelectLook,
              ),
              const SizedBox(height: 16),
              _ShutterButton(onPressed: busy ? null : onShutter),
            ],
          ),
        ),
      ],
    );
  }
}

/// Runs the camera preview through `shaders/preview.frag` — cheap
/// LUT+tone+vignette approximation of the selected look, per
/// docs/ARCHITECTURE.md "Preview light, render heavy". The full look.frag
/// pipeline only ever runs on the captured still.
class _ShaderCameraPreview extends StatefulWidget {
  const new({required this.camState, required this.spec});

  final CameraControllerState camState;
  final LookSpec spec;

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
        _boundSpecId == widget.spec.id) {
      return;
    }

    _shader?.dispose();
    final shader = program.fragmentShader();
    bindPreviewUniforms(
      shader,
      spec: widget.spec,
      width: physicalSize.width,
      height: physicalSize.height,
    );
    // Sampler 0 (uImage) is deliberately left unbound: ImageFilter.shader
    // auto-fills it with the filtered child's live rendered content — the
    // confirmed S4 spike finding
    // (integration_test/preview_shader_fps_spike_test.dart).
    shader.setImageSampler(1, lut);
    _shader = shader;
    _boundPhysicalSize = physicalSize;
    _boundSpecId = widget.spec.id;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = constraints.biggest;

        // The size CameraPreview's own internal AspectRatio settles on
        // when fit inside mediaSize (contain, not cover).
        final fittedSize = mediaSize.aspectRatio > previewAspect
            ? Size(mediaSize.height * previewAspect, mediaSize.height)
            : Size(mediaSize.width, mediaSize.width / previewAspect);
        _bindShaderFor(fittedSize * dpr);

        var scale = mediaSize.aspectRatio * previewAspect;
        if (scale < 1) scale = 1 / scale;

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
    );
  }
}

class _TopControls extends StatelessWidget {
  const new({
    required this.camState,
    required this.frontScreenFlashOn,
    required this.mirrorSelfieMode,
    required this.onCycleFlash,
    required this.onSwitchLens,
    required this.onToggleFrontScreenFlash,
    required this.onToggleMirrorSelfie,
  });

  final CameraControllerState camState;
  final bool frontScreenFlashOn;
  final bool mirrorSelfieMode;
  final VoidCallback onCycleFlash;
  final VoidCallback onSwitchLens;
  final VoidCallback onToggleFrontScreenFlash;
  final VoidCallback onToggleMirrorSelfie;

  IconData get _backFlashIcon => switch (camState.flashMode) {
    FlashMode.off => Icons.flash_off,
    FlashMode.auto => Icons.flash_auto,
    FlashMode.always || FlashMode.torch => Icons.flash_on,
  };

  @override
  Widget build(BuildContext context) {
    final isFront = camState.lensDirection == CameraLensDirection.front;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (camState.supportsFlash)
          _RoundIconButton(icon: _backFlashIcon, onPressed: onCycleFlash),
        if (isFront)
          _RoundIconButton(
            icon: frontScreenFlashOn ? Icons.flash_on : Icons.flash_off,
            onPressed: onToggleFrontScreenFlash,
          ),
        const SizedBox(width: 12),
        _RoundIconButton(
          icon: mirrorSelfieMode
              ? Icons.flip_camera_android
              : Icons.flip_camera_android_outlined,
          onPressed: onToggleMirrorSelfie,
        ),
        const SizedBox(width: 12),
        _RoundIconButton(
          icon: Icons.cameraswitch_outlined,
          onPressed: onSwitchLens,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const new({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const new({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onPressed == null ? Colors.white38 : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const new({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    // Friendlier permission-denied / no-camera copy and a way to open
    // Settings lands in S21; for now this at least surfaces the failure
    // instead of a blank/frozen screen.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              "Couldn't start the camera.\n$error",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

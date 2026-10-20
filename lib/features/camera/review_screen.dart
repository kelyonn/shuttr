import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shuttr/app/router.dart';
import 'package:shuttr/app/theme.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/core/ui/shuttr_ui.dart';
import 'package:shuttr/features/camera/body/camera_dash.dart';
import 'package:shuttr/features/camera/capture_service.dart';
import 'package:shuttr/features/camera/character/developing_print.dart';
import 'package:shuttr/features/looks/date_stamp.dart';
import 'package:shuttr/features/looks/look_registry.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/render/look_renderer.dart';
import 'package:shuttr/features/paywall/entitlement_repository.dart';
import 'package:shuttr/features/settings/settings_repository.dart';

/// The "developing" review screen (S14): shows a short animation while the
/// look render — kicked off before this screen even opened — finishes in
/// the background, then the result with retake/save.
class ReviewScreen extends ConsumerStatefulWidget {
  const new({
    required this.pending,
    required this.spec,
    required this.frameLabel,
    super.key,
  });

  final PendingCapture pending;

  /// The look the photo is being developed with — known at shutter time, so
  /// the name and lock state show while the render is still running.
  final LookSpec spec;

  /// e.g. `NO.018`.
  final String frameLabel;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _photoStore = PhotoStore();
  late LookSpec _spec = widget.spec;

  CaptureResult? _result;
  Object? _renderError;
  bool _saving = false;
  bool _gate = false;

  @override
  void initState() {
    super.initState();
    unawaited(_awaitRender());
  }

  Future<void> _awaitRender() async {
    try {
      final result = await widget.pending.renderFuture;
      if (mounted) setState(() => _result = result);
    } on Object catch (error) {
      if (mounted) setState(() => _renderError = error);
    }
  }

  /// Re-renders this same shot in another camera, before keeping it.
  Future<void> _tryCamera(LookSpec next) async {
    final old = _result;
    if (old == null || next.id == _spec.id || _saving) return;
    setState(() {
      _spec = next;
      _result = null;
      _renderError = null;
      _gate = false;
    });
    try {
      final stamp =
          ref.read(settingsProvider).dateStampOverride ??
          (next.dateStampDefaultOn
              ? const DateStampSettings(enabled: true)
              : null);
      final outPath =
          '${File(old.renderedPath).parent.path}/shuttr_rendered_'
          '${DateTime.now().microsecondsSinceEpoch}.jpg';
      final rendered = await LookRenderer.device().render(
        sourcePath: old.originalPath,
        spec: next,
        outPath: outPath,
        flashFired: old.flashFired,
        seed: old.seed,
        dateStamp: stamp,
        captureDate: old.capturedAt,
        mirror: old.mirror,
        happyAccidents: old.accidents,
      );
      final file = File(old.renderedPath);
      if (file.existsSync()) await file.delete();
      if (!mounted) return;
      setState(
        () => _result = CaptureResult(
          originalPath: old.originalPath,
          renderedPath: outPath,
          renderMs: rendered.renderMs,
          spec: next,
          seed: old.seed,
          dateStamp: stamp,
          flashFired: old.flashFired,
          accidents: old.accidents,
          capturedAt: old.capturedAt,
          mirror: old.mirror,
        ),
      );
    } on Object catch (error) {
      if (mounted) setState(() => _renderError = error);
    }
  }

  Future<void> _deleteTempFiles() async {
    final paths = {widget.pending.originalPath, _result?.renderedPath};
    for (final path in paths.nonNulls) {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    }
  }

  Future<void> _keep() async {
    if (_spec.isLocked && !ref.read(hasUnlockProvider)) {
      // Gating is at keep, never at preview (CLAUDE.md rule 3).
      setState(() => _gate = true);
      return;
    }
    await _save();
  }

  Future<void> _unlock() async {
    final owned = await context.push<bool>(AppRoutes.paywall);
    if ((owned ?? false) && mounted) {
      setState(() => _gate = false);
      await _save();
    }
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null || _saving) return;
    setState(() => _saving = true);
    try {
      final hasAccess = await Gal.hasAccess() || await Gal.requestAccess();
      if (!hasAccess) {
        _showSnack('Allow photo access in Settings to save.');
        return;
      }
      await _photoStore.save(
        originalCapturePath: result.originalPath,
        renderedPath: result.renderedPath,
        spec: result.spec,
        seed: result.seed,
        dateStamp: result.dateStamp,
        flashFired: result.flashFired,
        accidents: result.accidents,
        capturedAt: result.capturedAt,
      );
      await _deleteTempFiles();
      unawaited(_maybeAskForReview());
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Saved to your gallery.')),
          );
      }
    } on GalException catch (error) {
      _showSnack('Could not save: ${error.type.message}');
    } on Object {
      _showSnack("Couldn't save that photo. Try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Asks for a store review once, after the fifth kept photo.
  Future<void> _maybeAskForReview() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool('reviewAsked') ?? false) return;
    if ((await _photoStore.listAll()).length < 5) return;
    await prefs.setBool('reviewAsked', true);
    final review = InAppReview.instance;
    if (await review.isAvailable()) await review.requestReview();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    void retake() => Navigator.of(context).pop();
    final spec = _spec;
    final mark = cameraMark(spec);
    final paper = ref.watch(settingsProvider).bodyTheme.paperColor;
    final developing = _result == null && _renderError == null;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Covers both the Retake button and the system back gesture — the
        // temp original/rendered files are only useful while this screen
        // is open (Save copies the render into the gallery separately).
        if (didPop) unawaited(_deleteTempFiles());
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: paper,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: paper,
          body: PlateLayout(
            paper: paper,
            plate: FilmPlate(
              frameLabel: widget.frameLabel,
              rightLabel: developing ? 'DEVELOPING' : 'REVIEW',
              photo: switch ((_renderError, _result)) {
                (final error?, _) => _ReviewError(error: error),
                (_, null) => const _DevelopingPlate(),
                (_, final result?) => ColoredBox(
                  color: Palette.stage,
                  child: PrintImage(
                    path: result.renderedPath,
                    spec: result.spec,
                    shotAt: result.capturedAt ?? DateTime.now(),
                  ),
                ),
              },
            ),
            panel: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cameraKicker(spec), style: Typo.label),
                        if (spec.isLocked)
                          const StatusTag('PREVIEW ONLY', solid: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(mark.name, style: Typo.name),
                      if (mark.sub.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(mark.sub, style: Typo.subSmall),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  _CameraStrip(
                    selectedId: spec.id,
                    enabled: _result != null && !_saving,
                    onPick: (look) => unawaited(_tryCamera(look)),
                  ),
                  if (_gate) ...[
                    const SizedBox(height: 12),
                    _GateBox(name: spec.displayName),
                  ],
                ],
              ),
            ),
            footer: _ActionRow(
              enabled: !developing && _renderError == null && !_saving,
              gate: _gate,
              onRetake: retake,
              onKeep: _keep,
              onUnlock: _unlock,
              saving: _saving,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Try another camera": the same shot, developed again in each camera.
class _CameraStrip extends StatelessWidget {
  const new({
    required this.selectedId,
    required this.enabled,
    required this.onPick,
  });

  final String selectedId;
  final bool enabled;
  final ValueChanged<LookSpec> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Opacity(
          opacity: 0.8,
          child: Text('TRY ANOTHER CAMERA', style: Typo.micro),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: Palette.ink)),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final look in looks)
                  TapCell(
                    onTap: enabled ? () => onPick(look) : null,
                    on: look.id == selectedId,
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    border: const Border(right: BorderSide(color: Palette.ink)),
                    semanticLabel: look.displayName,
                    child: Text(
                      cameraMark(look).name,
                      style: Typo.labelBold.copyWith(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const new({
    required this.enabled,
    required this.gate,
    required this.saving,
    required this.onRetake,
    required this.onKeep,
    required this.onUnlock,
  });

  final bool enabled;
  final bool gate;
  final bool saving;
  final VoidCallback onRetake;
  final VoidCallback onKeep;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final rightLabel = gate ? 'UNLOCK' : (saving ? 'KEEPING…' : 'KEEP');
    return Opacity(
      opacity: enabled || saving ? 1 : 0.35,
      child: Container(
        decoration: topRule,
        child: Row(
          children: [
            Expanded(
              child: TapCell(
                onTap: enabled ? onRetake : null,
                height: 56,
                alignment: Alignment.center,
                child: const Text('RETAKE', style: Typo.labelBold),
              ),
            ),
            Expanded(
              child: TapCell(
                onTap: enabled ? (gate ? onUnlock : onKeep) : null,
                height: 56,
                alignment: Alignment.center,
                background: Palette.ink,
                child: Text(
                  rightLabel,
                  style: Typo.labelBold.copyWith(
                    fontSize: 12,
                    color: Palette.paper,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GateBox extends StatelessWidget {
  const new({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(border: Border.all(color: Palette.ink)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEEPING NEEDS THE UNLOCK',
            style: Typo.label.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '$name can be previewed. Keeping it needs the unlock.',
            style: Typo.body,
          ),
          const SizedBox(height: 6),
          const Opacity(
            opacity: 0.72,
            child: Text(
              'ONE-TIME · NO ADS · NO SUBSCRIPTION',
              style: Typo.micro,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark plate with the frame "exposing": a stepped strip fills while the
/// render finishes.
class _DevelopingPlate extends StatefulWidget {
  const new();

  @override
  State<_DevelopingPlate> createState() => _DevelopingPlateState();
}

class _DevelopingPlateState extends State<_DevelopingPlate>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.stage,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              decoration: BoxDecoration(
                border: Border.all(color: Palette.cream, width: 2),
              ),
              child: const Text(
                'DEVELOPING',
                style: TextStyle(
                  fontFamily: 'Anton',
                  fontSize: 48,
                  height: 1,
                  letterSpacing: 1,
                  color: Palette.cream,
                ),
              ),
            ),
            const SizedBox(height: 18),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final filled = (_controller.value * 13).floor();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 12; i++)
                      Container(
                        width: 12,
                        height: 14,
                        margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
                        decoration: BoxDecoration(
                          color: i < filled ? Palette.cream : null,
                          border: Border.all(color: Palette.cream),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewError extends StatelessWidget {
  const new({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.stage,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            "Couldn't develop this photo. Retake it and try again.",
            textAlign: TextAlign.center,
            style: Typo.body.copyWith(color: Palette.cream),
          ),
        ),
      ),
    );
  }
}

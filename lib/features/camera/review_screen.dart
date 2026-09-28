import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:shuttr/features/camera/capture_service.dart';

/// The "developing" review screen (S14): shows a short animation while the
/// look render — kicked off before this screen even opened — finishes in
/// the background, then the result with retake/save.
class ReviewScreen extends StatefulWidget {
  const new({required this.pending, super.key});

  final PendingCapture pending;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  CaptureResult? _result;
  Object? _renderError;
  bool _saving = false;

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

  Future<void> _deleteTempFiles() async {
    final paths = {widget.pending.originalPath, _result?.renderedPath};
    for (final path in paths.nonNulls) {
      final file = File(path);
      if (file.existsSync()) await file.delete();
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
      await Gal.putImage(result.renderedPath, album: 'Shuttr');
      // The original stays in the temp dir for now — S15 adds the
      // permanent originals/meta layout re-develop and the in-app gallery
      // need; today's save is gallery-only.
      await _deleteTempFiles();
      if (mounted) Navigator.of(context).pop();
    } on GalException catch (error) {
      _showSnack('Could not save: ${error.type.message}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    void retake() => Navigator.of(context).pop();

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Covers both the Retake button and the system back gesture — the
        // temp original/rendered files are only useful while this screen
        // is open (Save copies the render into the gallery separately).
        if (didPop) unawaited(_deleteTempFiles());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: switch ((_renderError, _result)) {
            (final error?, _) => _ReviewError(error: error, onRetake: retake),
            (_, null) => const _DevelopingIndicator(),
            (_, final result?) => _ReviewReady(
              result: result,
              saving: _saving,
              onRetake: retake,
              onSave: _save,
            ),
          },
        ),
      ),
    );
  }
}

class _DevelopingIndicator extends StatefulWidget {
  const new();

  @override
  State<_DevelopingIndicator> createState() => _DevelopingIndicatorState();
}

class _DevelopingIndicatorState extends State<_DevelopingIndicator>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.35, end: 1).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
            ),
            child: const Icon(
              Icons.photo_camera_back_outlined,
              color: Colors.deepOrange,
              size: 56,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Developing…', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _ReviewReady extends StatelessWidget {
  const new({
    required this.result,
    required this.saving,
    required this.onRetake,
    required this.onSave,
  });

  final CaptureResult result;
  final bool saving;
  final VoidCallback onRetake;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Image.file(File(result.renderedPath)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: saving ? null : onRetake,
                icon: const Icon(Icons.refresh),
                label: const Text('Retake'),
              ),
              FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewError extends StatelessWidget {
  const new({required this.error, required this.onRetake});

  final Object error;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              "Couldn't develop this photo.\n$error",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetake, child: const Text('Retake')),
          ],
        ),
      ),
    );
  }
}

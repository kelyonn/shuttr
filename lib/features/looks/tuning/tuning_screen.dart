import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shuttr/core/platform/codec_channel.dart';
import 'package:shuttr/features/looks/look_registry.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/render/look_renderer.dart';
import 'package:shuttr/features/looks/tuning/param_descriptor.dart';

/// Debug-only screen (docs/BUILD_PLAN.md S5): pick a reference photo, tune
/// a look's params against it with live sliders, export the resulting
/// values to paste into a `lib/features/looks/specs/<look>.dart` file.
///
/// Not reachable in release builds — only wired from the /debug/tuning
/// route, which should itself be gated behind kDebugMode when the app
/// shell adds real navigation (S16).
class TuningScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<TuningScreen> createState() => _TuningScreenState();
}

class _TuningScreenState extends State<TuningScreen> {
  final _renderer = LookRenderer(codec: MethodChannelCodec());
  final _picker = ImagePicker();

  LookSpec _spec = looks.first;
  String? _sourcePath;
  Uint8List? _previewBytes;
  int? _lastRenderMs;
  bool _rendering = false;

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _sourcePath = picked.path);
    await _rerender();
  }

  Future<void> _rerender() async {
    final sourcePath = _sourcePath;
    if (sourcePath == null || _rendering) return;

    setState(() => _rendering = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/tuning_preview.jpg';
      // Smaller than the real output for interactive re-render speed —
      // the tuning screen cares about feel, not final resolution.
      final previewSpec = _CopySpecAtSize.at(_spec, 1024);

      final result = await _renderer.render(
        sourcePath: sourcePath,
        spec: previewSpec,
        outPath: outPath,
        flashFired: true,
        seed: 7,
      );

      final bytes = await File(outPath).readAsBytes();
      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
        _lastRenderMs = result.renderMs;
      });
    } finally {
      if (mounted) setState(() => _rendering = false);
    }
  }

  void _selectLook(LookSpec spec) {
    setState(() => _spec = spec);
    unawaited(_rerender());
  }

  void _updateParam(ParamDescriptor param, double value) {
    setState(() => _spec = param.apply(_spec, value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tuning (debug)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: _pickPhoto,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                _sourcePath == null ? null : () => unawaited(_rerender()),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 280,
            child: Center(
              child: _previewBytes != null
                  ? Image.memory(_previewBytes!, gaplessPlayback: true)
                  : const Text('Pick a photo to start tuning'),
            ),
          ),
          if (_lastRenderMs != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('Render: ${_lastRenderMs}ms'),
            ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final look in looks)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(look.displayName),
                      selected: _spec.id == look.id,
                      onSelected: (_) => _selectLook(look),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final param in tuningParams)
                  ListTile(
                    title: Text(param.label),
                    subtitle: Slider(
                      value: param.get(_spec).clamp(param.min, param.max),
                      min: param.min,
                      max: param.max,
                      label: param.get(_spec).toStringAsFixed(2),
                      onChanged: (v) => _updateParam(param, v),
                      onChangeEnd: (_) => unawaited(_rerender()),
                    ),
                    trailing: SizedBox(
                      width: 48,
                      child: Text(param.get(_spec).toStringAsFixed(2)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns `spec` with `outputLongEdge` swapped to `longEdge`, for a faster
/// interactive preview render than the final output size.
extension _CopySpecAtSize on LookSpec {
  static LookSpec at(LookSpec spec, int longEdge) {
    return LookSpec(
      id: spec.id,
      version: spec.version,
      displayName: spec.displayName,
      isFree: spec.isFree,
      aspectWidth: spec.aspectWidth,
      aspectHeight: spec.aspectHeight,
      outputLongEdge: longEdge,
      jpegQuality: spec.jpegQuality,
      lutAsset: spec.lutAsset,
      frameAsset: spec.frameAsset,
      dateStampDefaultOn: spec.dateStampDefaultOn,
      flashStrength: spec.flashStrength,
      flashRadius: spec.flashRadius,
      flashFalloff: spec.flashFalloff,
      exposure: spec.exposure,
      contrast: spec.contrast,
      blackLift: spec.blackLift,
      highlightClip: spec.highlightClip,
      lutStrength: spec.lutStrength,
      saturation: spec.saturation,
      bloomThreshold: spec.bloomThreshold,
      bloomStrength: spec.bloomStrength,
      halationStrength: spec.halationStrength,
      vignette: spec.vignette,
      chromaticAberration: spec.chromaticAberration,
      softness: spec.softness,
      grainAmount: spec.grainAmount,
      grainSize: spec.grainSize,
      chromaNoise: spec.chromaNoise,
      sharpenAmount: spec.sharpenAmount,
      lightLeakStrength: spec.lightLeakStrength,
    );
  }
}

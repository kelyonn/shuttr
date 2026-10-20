import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shuttr/app/theme.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/core/ui/shuttr_ui.dart';
import 'package:shuttr/features/camera/body/camera_catalog.dart';
import 'package:shuttr/features/camera/body/camera_dash.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/render/look_renderer.dart';
import 'package:shuttr/features/video/video_looks.dart';

/// Opens a camera's card: its era, story, what it's best for, its traits,
/// and your own most recent shot developed through it. Returns true if the
/// user chose to shoot with it.
Future<bool> showCameraCard(BuildContext context, LookSpec look) async {
  final use = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Palette.paper,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(),
    builder: (_) => CameraCard(look: look),
  );
  return use ?? false;
}

class CameraCard extends StatefulWidget {
  const new({required this.look, super.key});

  final LookSpec look;

  @override
  State<CameraCard> createState() => _CameraCardState();
}

class _CameraCardState extends State<CameraCard> {
  late final Future<String?> _sample = _renderSample();

  /// Develops your latest original through this camera at a small size.
  /// Null when there's nothing on the roll to show.
  Future<String?> _renderSample() async {
    // Video formats move; a still from the photo pipeline would misrepresent
    // them, so their card is words only.
    if (widget.look.id.startsWith('video_')) return null;
    final photos = await PhotoStore().listAll();
    final withOriginal = photos.where((p) => p.hasOriginal);
    if (withOriginal.isEmpty) return null;
    final latest = withOriginal.first;
    final dir = await getTemporaryDirectory();
    final out = '${dir.path}/shuttr_card_${widget.look.id}.jpg';
    await LookRenderer.device().render(
      sourcePath: latest.originalPath,
      spec: widget.look.copyWith(outputLongEdge: 900),
      outPath: out,
      seed: latest.meta.seed,
      flashFired: latest.meta.flashFired,
    );
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    final info = cameraInfo(look.id);
    final mark = cameraMark(look);
    final media = MediaQuery.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: media.padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const HeavyRule(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cameraKicker(
                      look,
                      list: look.id.startsWith('video_')
                          ? videoPreviewLooks
                          : null,
                    ),
                    style: Typo.label,
                  ),
                  if (info.era.isNotEmpty) StatusTag('EST. ${info.era}'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Text(info.story, style: Typo.body),
            ),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ColoredBox(
                color: Palette.stage,
                child: FutureBuilder<String?>(
                  future: _sample,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(
                        child: Text(
                          'DEVELOPING YOUR LAST SHOT…',
                          style: TextStyle(
                            color: Palette.cream,
                            fontSize: 11,
                            letterSpacing: 1.4,
                          ),
                        ),
                      );
                    }
                    final path = snap.data;
                    if (path == null && look.id.startsWith('video_')) {
                      return Center(
                        child: Text(
                          mark.name,
                          style: Typo.display.copyWith(color: Palette.cream),
                        ),
                      );
                    }
                    if (path == null) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Shoot a frame and it shows up here, '
                            'developed in every camera.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Palette.cream),
                          ),
                        ),
                      );
                    }
                    return Image.file(File(path), fit: BoxFit.contain);
                  },
                ),
              ),
            ),
            _TagRow(label: 'BEST FOR', tags: info.bestFor),
            _TagRow(label: 'CHARACTER', tags: info.traits),
            const SizedBox(height: 8),
            TapCell(
              onTap: () => Navigator.of(context).pop(true),
              height: 56,
              alignment: Alignment.center,
              background: Palette.ink,
              child: Text(
                '${look.id.startsWith('video_') ? 'FILM' : 'SHOOT'} WITH '
                '${look.displayName.toUpperCase()}',
                style: Typo.labelBold.copyWith(
                  fontSize: 12,
                  color: Palette.paper,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const new({required this.label, required this.tags});

  final String label;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: const BoxDecoration(border: bottomRule),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(opacity: 0.7, child: Text(label, style: Typo.micro)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final t in tags) StatusTag(t.toUpperCase())],
          ),
        ],
      ),
    );
  }
}

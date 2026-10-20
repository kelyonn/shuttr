import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shuttr/app/theme.dart';
import 'package:shuttr/core/platform/video_channel.dart';
import 'package:shuttr/core/storage/photo_meta.dart';
import 'package:shuttr/core/storage/video_store.dart';
import 'package:shuttr/core/ui/shuttr_ui.dart';
import 'package:shuttr/features/camera/body/camera_dash.dart';
import 'package:shuttr/features/settings/settings_repository.dart';
import 'package:shuttr/features/video/video_look.dart';
import 'package:video_player/video_player.dart';

/// Develops a recorded or imported clip through a [VideoLook] (native,
/// Media3), shows progress like a tape being dubbed, then plays the result
/// on a loop with RETAKE / KEEP.
class VideoReviewScreen extends ConsumerStatefulWidget {
  const new({
    required this.sourcePath,
    required this.look,
    required this.startedAt,
    this.source = PhotoSource.capture,
    this.deleteSourceAfter = true,
    super.key,
  });

  final String sourcePath;
  final VideoLook look;
  final DateTime startedAt;
  final PhotoSource source;

  /// Recordings live in temp and go once reviewed; imports are the user's
  /// own file and are never touched.
  final bool deleteSourceAfter;

  @override
  ConsumerState<VideoReviewScreen> createState() => _VideoReviewScreenState();
}

class _VideoReviewScreenState extends ConsumerState<VideoReviewScreen> {
  final _channel = VideoChannel();
  final _store = VideoStore();
  Timer? _poll;
  int _progress = 0;
  String? _outPath;
  Object? _error;
  VideoPlayerController? _player;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_develop());
  }

  Future<void> _develop() async {
    final dir = await getTemporaryDirectory();
    final out =
        '${dir.path}/shuttr_video_${DateTime.now().microsecondsSinceEpoch}.mp4';
    _poll = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      final p = await _channel.progress();
      if (mounted && p >= 0) setState(() => _progress = p);
    });
    try {
      await _channel.process(
        input: widget.sourcePath,
        output: out,
        look: widget.look,
        startedAt: widget.startedAt,
        seed: math.Random().nextDouble() * 1000,
        yearOverride: ref
            .read(settingsProvider)
            .dateStampOverride
            ?.yearOverride,
      );
      final player = VideoPlayerController.file(File(out));
      await player.initialize();
      await player.setLooping(true);
      await player.play();
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _outPath = out;
        _player = player;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      _poll?.cancel();
    }
  }

  Future<void> _cleanup({required bool keepOutput}) async {
    final paths = [
      if (widget.deleteSourceAfter) widget.sourcePath,
      if (!keepOutput) _outPath,
    ];
    for (final p in paths.nonNulls) {
      final f = File(p);
      if (f.existsSync()) await f.delete();
    }
  }

  Future<void> _keep() async {
    final out = _outPath;
    if (out == null || _saving) return;
    setState(() => _saving = true);
    try {
      final hasAccess = await Gal.hasAccess() || await Gal.requestAccess();
      if (!hasAccess) {
        _snack('Allow photo access in Settings to save.');
        return;
      }
      await _player?.pause();
      await _store.save(
        developedPath: out,
        look: widget.look,
        capturedAt: widget.startedAt,
        source: widget.source,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on GalException catch (error) {
      _snack('Could not save: ${error.type.message}');
    } on Object {
      _snack("Couldn't save that clip. Try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _poll?.cancel();
    if (_outPath == null && _error == null) unawaited(_channel.cancel());
    unawaited(_player?.dispose());
    // Temp files go whichever way the screen closes; a kept clip was
    // already copied into permanent storage.
    unawaited(_cleanup(keepOutput: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paper = ref.watch(settingsProvider).bodyTheme.paperColor;
    final look = widget.look;
    final mark = cameraMark(look.previewLook);
    final player = _player;
    final developing = player == null && _error == null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
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
            frameLabel: look.displayName.toUpperCase(),
            rightLabel: developing ? 'DUBBING $_progress%' : 'PLAYBACK',
            photo: ColoredBox(
              color: Palette.stage,
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          "Couldn't develop this clip.\n"
                          'Retake it and try again.',
                          textAlign: TextAlign.center,
                          style: Typo.body.copyWith(color: Palette.cream),
                        ),
                      ),
                    )
                  : player == null
                  ? _Dubbing(progress: _progress)
                  : Center(
                      child: AspectRatio(
                        aspectRatio: player.value.aspectRatio,
                        child: VideoPlayer(player),
                      ),
                    ),
            ),
          ),
          panel: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(mark.name, style: Typo.name),
                const SizedBox(width: 8),
                Text(mark.sub, style: Typo.subSmall),
              ],
            ),
          ),
          footer: Container(
            decoration: topRule,
            child: Row(
              children: [
                Expanded(
                  child: TapCell(
                    onTap: _saving ? null : () => Navigator.of(context).pop(),
                    height: 56,
                    alignment: Alignment.center,
                    child: Text(
                      developing
                          ? 'CANCEL'
                          : widget.source == PhotoSource.import
                          ? 'DISCARD'
                          : 'RETAKE',
                      style: Typo.labelBold,
                    ),
                  ),
                ),
                Expanded(
                  child: Opacity(
                    opacity: developing ? 0.35 : 1,
                    child: TapCell(
                      onTap: developing || _saving ? null : _keep,
                      height: 56,
                      alignment: Alignment.center,
                      background: Palette.ink,
                      child: Text(
                        _saving ? 'KEEPING…' : 'KEEP',
                        style: Typo.labelBold.copyWith(
                          fontSize: 12,
                          color: Palette.paper,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tape being dubbed: the counter runs while the clip develops.
class _Dubbing extends StatelessWidget {
  const new({required this.progress});

  final int progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            decoration: BoxDecoration(
              border: Border.all(color: Palette.cream, width: 2),
            ),
            child: const Text(
              'DUBBING',
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 12; i++)
                Container(
                  width: 12,
                  height: 14,
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
                  decoration: BoxDecoration(
                    color: i < progress * 12 ~/ 100 ? Palette.cream : null,
                    border: Border.all(color: Palette.cream),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$progress%  ·  CANCEL ANYTIME',
            style: Typo.micro.copyWith(color: Palette.cream),
          ),
        ],
      ),
    );
  }
}

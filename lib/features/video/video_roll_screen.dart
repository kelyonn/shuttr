import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shuttr/app/theme.dart';
import 'package:shuttr/core/platform/codec_channel.dart';
import 'package:shuttr/core/storage/photo_meta.dart';
import 'package:shuttr/core/storage/video_store.dart';
import 'package:shuttr/core/ui/shuttr_route.dart';
import 'package:shuttr/core/ui/shuttr_ui.dart';
import 'package:shuttr/features/video/video_look.dart';
import 'package:shuttr/features/video/video_looks.dart';
import 'package:shuttr/features/video/video_review_screen.dart';
import 'package:video_player/video_player.dart';

/// Kept clips, newest first, plus IMPORT: run any video from the phone
/// through a camcorder look.
class VideoRollScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<VideoRollScreen> createState() => _VideoRollScreenState();
}

class _VideoRollScreenState extends State<VideoRollScreen> {
  final _store = VideoStore();
  late Future<List<StoredVideo>> _videos = _store.listAll();

  Future<void> _refresh() async {
    final f = _store.listAll();
    setState(() => _videos = f);
    await f;
  }

  Future<void> _import() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    final look = await showModalBottomSheet<VideoLook>(
      context: context,
      backgroundColor: Palette.paper,
      shape: const RoundedRectangleBorder(),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('DEVELOP IN…', style: Typo.labelBold),
            ),
            for (final l in videoLooks)
              TapCell(
                onTap: () => Navigator.of(context).pop(l),
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                border: const Border(top: BorderSide(color: Palette.ink)),
                child: Text(l.displayName, style: Typo.body),
              ),
          ],
        ),
      ),
    );
    if (look == null || !mounted) return;
    // The date the clip was shot, for the burnt-in OSD.
    final shot =
        await MethodChannelCodec().readCaptureDate(picked.path) ??
        File(picked.path).lastModifiedSync();
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      ShuttrRoute(
        builder: (_) => VideoReviewScreen(
          sourcePath: picked.path,
          look: look,
          startedAt: shot,
          source: PhotoSource.import,
          deleteSourceAfter: false,
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<StoredVideo>>(
          future: _videos,
          builder: (context, snap) {
            final videos = snap.data;
            final n = videos?.length ?? 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: 'TAPES',
                  meta:
                      '${n.toString().padLeft(2, '0')} '
                      '${n == 1 ? 'CLIP' : 'CLIPS'}',
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: videos == null
                      ? const SizedBox.shrink()
                      : videos.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'No tapes yet. Switch the camera to VIDEO and '
                            'hit REC, or import a clip.',
                            style: Typo.sub,
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 4 / 3.6,
                              ),
                          itemCount: videos.length,
                          itemBuilder: (context, i) => _Tile(
                            video: videos[i],
                            onTap: () async {
                              await Navigator.of(context).push<void>(
                                ShuttrRoute(
                                  builder: (_) =>
                                      _VideoPlayerScreen(video: videos[i]),
                                ),
                              );
                              await _refresh();
                            },
                          ),
                        ),
                ),
                Container(
                  decoration: topRule,
                  child: TapCell(
                    onTap: () => unawaited(_import()),
                    height: 56,
                    alignment: Alignment.center,
                    child: const Text('IMPORT VIDEO', style: Typo.labelBold),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _duration(int ms) {
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class _Tile extends StatelessWidget {
  const new({required this.video, required this.onTap});

  final StoredVideo video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final poster = File(video.posterPath);
    return TapCell(
      onTap: onTap,
      border: const Border(
        bottom: BorderSide(color: Palette.ink),
        right: BorderSide(color: Palette.ink),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (poster.existsSync())
                  Image.file(poster, fit: BoxFit.cover)
                else
                  const ColoredBox(color: Palette.stage),
                const Center(
                  child: Icon(Icons.play_arrow, color: Palette.cream, size: 36),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 28,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_duration(video.durationMs), style: Typo.micro),
                  Text(
                    videoLookById(video.lookId).displayName.toUpperCase(),
                    style: Typo.micro,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPlayerScreen extends StatefulWidget {
  const new({required this.video});

  final StoredVideo video;

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late final VideoPlayerController _player = VideoPlayerController.file(
    File(widget.video.videoPath),
  );

  @override
  void initState() {
    super.initState();
    unawaited(
      _player.initialize().then((_) async {
        await _player.setLooping(true);
        await _player.play();
        if (mounted) setState(() {});
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this clip?'),
        content: const Text(
          "Removes it from Shuttr. The copy in your phone's gallery stays.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    await VideoStore().delete(widget.video.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final look = videoLookById(widget.video.lookId);
    return Scaffold(
      backgroundColor: Palette.stage,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _player.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _player.value.aspectRatio,
                        child: GestureDetector(
                          onTap: () => setState(
                            () => _player.value.isPlaying
                                ? unawaited(_player.pause())
                                : unawaited(_player.play()),
                          ),
                          child: VideoPlayer(_player),
                        ),
                      )
                    : const CircularProgressIndicator(color: Palette.cream),
              ),
            ),
            ColoredBox(
              color: Palette.paper,
              child: Row(
                children: [
                  Expanded(
                    child: TapCell(
                      onTap: () => Navigator.of(context).pop(),
                      height: 56,
                      alignment: Alignment.center,
                      child: const Text('BACK', style: Typo.labelBold),
                    ),
                  ),
                  Expanded(
                    child: TapCell(
                      onTap: () => unawaited(
                        SharePlus.instance.share(
                          ShareParams(
                            files: [XFile(widget.video.videoPath)],
                            text: 'shot on shuttr · ${look.displayName}',
                          ),
                        ),
                      ),
                      height: 56,
                      alignment: Alignment.center,
                      border: const Border(
                        left: BorderSide(color: Palette.ink),
                      ),
                      child: const Text('SHARE', style: Typo.labelBold),
                    ),
                  ),
                  Expanded(
                    child: TapCell(
                      onTap: () => unawaited(_delete()),
                      height: 56,
                      alignment: Alignment.center,
                      border: const Border(
                        left: BorderSide(color: Palette.ink),
                      ),
                      child: const Text('DELETE', style: Typo.labelBold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

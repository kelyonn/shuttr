import 'dart:convert';
import 'dart:io';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shuttr/core/platform/video_channel.dart';
import 'package:shuttr/core/storage/photo_meta.dart';
import 'package:shuttr/features/video/video_look.dart';

/// One kept clip: `videos/<id>.mp4`, its poster `videos/<id>.jpg`, and a
/// `videos/<id>.json` sidecar.
class StoredVideo {
  const new({
    required this.id,
    required this.lookId,
    required this.capturedAt,
    required this.durationMs,
    required this.source,
    required this.videoPath,
    required this.posterPath,
  });

  final String id;
  final String lookId;
  final DateTime capturedAt;
  final int durationMs;
  final PhotoSource source;
  final String videoPath;
  final String posterPath;
}

/// Permanent storage for developed clips (same idea as `PhotoStore`); also
/// saves each kept clip to the phone gallery's "Shuttr" album.
class VideoStore {
  new({VideoChannel? channel, Future<Directory> Function()? documentsDirectory})
    : _channel = channel ?? VideoChannel(),
      _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  final VideoChannel _channel;
  final Future<Directory> Function() _documentsDirectory;

  Future<Directory> _dir() async {
    final docs = await _documentsDirectory();
    final dir = Directory('${docs.path}/videos');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<StoredVideo> save({
    required String developedPath,
    required VideoLook look,
    required DateTime capturedAt,
    PhotoSource source = PhotoSource.capture,
  }) async {
    final dir = await _dir();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final videoPath = '${dir.path}/$id.mp4';
    final posterPath = '${dir.path}/$id.jpg';
    await File(developedPath).copy(videoPath);
    final durationMs = await _channel.thumbnail(videoPath, posterPath);
    await File('${dir.path}/$id.json').writeAsString(
      jsonEncode({
        'id': id,
        'lookId': look.id,
        'capturedAt': capturedAt.toIso8601String(),
        'durationMs': durationMs,
        'source': source.name,
      }),
    );
    await Gal.putVideo(videoPath, album: 'Shuttr');
    return StoredVideo(
      id: id,
      lookId: look.id,
      capturedAt: capturedAt,
      durationMs: durationMs,
      source: source,
      videoPath: videoPath,
      posterPath: posterPath,
    );
  }

  /// Every kept clip, newest first.
  Future<List<StoredVideo>> listAll() async {
    final dir = await _dir();
    final videos = <StoredVideo>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final j = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
      final id = j['id'] as String;
      videos.add(
        StoredVideo(
          id: id,
          lookId: j['lookId'] as String,
          capturedAt: DateTime.parse(j['capturedAt'] as String),
          durationMs: j['durationMs'] as int? ?? 0,
          source:
              PhotoSource.values.asNameMap()[j['source']] ??
              PhotoSource.capture,
          videoPath: '${dir.path}/$id.mp4',
          posterPath: '${dir.path}/$id.jpg',
        ),
      );
    }
    videos.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return videos;
  }

  /// Removes Shuttr's own copy; the phone gallery copy is left alone.
  Future<void> delete(String id) async {
    final dir = await _dir();
    for (final ext in ['mp4', 'jpg', 'json']) {
      final f = File('${dir.path}/$id.$ext');
      if (f.existsSync()) await f.delete();
    }
  }
}

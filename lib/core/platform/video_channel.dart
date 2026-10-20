import 'package:flutter/services.dart';
import 'package:shuttr/features/video/video_look.dart';

/// The `shuttr/video` platform channel (VideoPlugin.kt): develops a clip
/// into a video look with Media3 Transformer, reports progress, and makes
/// gallery poster frames.
class VideoChannel {
  new({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('shuttr/video');

  final MethodChannel _channel;

  /// Develops [input] into [output]. Completes when the file is written.
  /// [startedAt] is when the clip was shot (drives the burnt-in date/time);
  /// [yearOverride] swaps the year like the photo date stamp does.
  Future<int> process({
    required String input,
    required String output,
    required VideoLook look,
    required DateTime startedAt,
    required double seed,
    int? yearOverride,
  }) async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'process',
      {
        'input': input,
        'output': output,
        'look': look.toJson(),
        'startMillis': startedAt.millisecondsSinceEpoch,
        'seed': seed,
        'yearOverride': yearOverride,
      },
    );
    return (result?['durationMs'] as int?) ?? 0;
  }

  /// 0-100 while developing, -1 when unknown.
  Future<int> progress() async =>
      await _channel.invokeMethod<int>('progress') ?? -1;

  Future<void> cancel() => _channel.invokeMethod<void>('cancel');

  /// Writes a JPEG poster frame of [path] to [out]; returns duration in ms.
  Future<int> thumbnail(String path, String out) async =>
      await _channel.invokeMethod<int>('thumbnail', {
        'path': path,
        'out': out,
      }) ??
      0;
}

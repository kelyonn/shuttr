import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/features/settings/settings_repository.dart';

/// SharedPreferences key: the highest frame number ever used.
const frameCounterKey = 'frameCounter';

/// How many frames are on the roll (the gallery's count). Invalidate after
/// saving or deleting a photo.
final FutureProvider<int> rollCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final photos = await PhotoStore().listAll();
  // Frame numbers only ever go up, so deleting a photo never makes the next
  // one reuse a number. An existing roll seeds the counter.
  final prefs = ref.read(sharedPreferencesProvider);
  final stored = prefs.getInt(frameCounterKey) ?? 0;
  if (photos.length > stored) {
    await prefs.setInt(frameCounterKey, photos.length);
  }
  return photos.length;
});

/// The frame number the next shot will get.
int nextFrameNumber(WidgetRef ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final count = ref.read(rollCountProvider).value ?? 0;
  final stored = prefs.getInt(frameCounterKey) ?? 0;
  return (stored > count ? stored : count) + 1;
}

/// Records that frame [number] was used.
Future<void> useFrameNumber(WidgetRef ref, int number) =>
    ref.read(sharedPreferencesProvider).setInt(frameCounterKey, number);

/// The newest kept photo's path, for the gallery thumbnail on the camera.
final FutureProvider<String?> latestPhotoProvider =
    FutureProvider.autoDispose<String?>((ref) async {
      final photos = await PhotoStore().listAll();
      return photos.isEmpty ? null : photos.first.photoPath;
    });

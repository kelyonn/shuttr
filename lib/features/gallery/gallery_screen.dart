import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/features/gallery/photo_viewer_screen.dart';

/// The in-app gallery (S18): a grid of everything `PhotoStore` (S15) has
/// saved, newest first.
class GalleryScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _photoStore = PhotoStore();
  late Future<List<StoredPhoto>> _photosFuture;

  @override
  void initState() {
    super.initState();
    _photosFuture = _photoStore.listAll();
  }

  Future<void> _refresh() async {
    final future = _photoStore.listAll();
    setState(() => _photosFuture = future);
    await future;
  }

  Future<void> _openViewer(List<StoredPhoto> photos, int index) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(photos: photos, initialIndex: index),
      ),
    );
    // The viewer can delete or re-develop, either of which changes the
    // list — always refresh on the way back rather than tracking which.
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gallery')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<StoredPhoto>>(
          future: _photosFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final photos = snapshot.data!;
            if (photos.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: const Center(
                      child: Text('No photos yet — go shoot something.'),
                    ),
                  ),
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return GestureDetector(
                  onTap: () => _openViewer(photos, index),
                  child: Image.file(File(photo.photoPath), fit: BoxFit.cover),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

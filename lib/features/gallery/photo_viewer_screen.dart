import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/features/gallery/redevelop_service.dart';
import 'package:shuttr/features/looks/look_registry.dart';
import 'package:shuttr/features/looks/look_spec.dart';

/// A swipeable full-screen viewer (S18) over the photos the gallery grid
/// was showing, starting at whichever one was tapped. Share, re-develop
/// and delete all act on whichever photo is currently on screen.
class PhotoViewerScreen extends StatefulWidget {
  const new({
    required this.photos,
    required this.initialIndex,
    super.key,
  });

  final List<StoredPhoto> photos;
  final int initialIndex;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  final _photoStore = PhotoStore();
  final _redevelopService = RedevelopService();
  late final List<StoredPhoto> _photos = List.of(widget.photos);
  late int _currentIndex = widget.initialIndex;
  var _busy = false;

  StoredPhoto get _current => _photos[_currentIndex];

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(_current.photoPath)],
        text: 'shot on shuttr 📸',
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this photo?'),
        content: const Text(
          "Removes it from Shuttr. If you saved it to your device's Photos "
          "app, it stays there — this doesn't touch that copy.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _photoStore.deletePhoto(_current.meta.id);
    if (!mounted) return;

    if (_photos.length == 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _photos.removeAt(_currentIndex);
      if (_currentIndex >= _photos.length) {
        _currentIndex = _photos.length - 1;
      }
    });
  }

  Future<void> _redevelop() async {
    final newSpec = await showModalBottomSheet<LookSpec>(
      context: context,
      builder: (context) =>
          _LookPickerSheet(currentLookId: _current.meta.lookId),
    );
    if (newSpec == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _redevelopService.redevelop(photo: _current, newSpec: newSpec);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Re-developed — check the gallery')),
        );
      }
    } on RedevelopException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookName = lookById(_current.meta.lookId).displayName;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(lookName),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: _currentIndex),
        itemCount: _photos.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) => InteractiveViewer(
          child: Center(child: Image.file(File(_photos[index].photoPath))),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              onPressed: () => unawaited(_share()),
            ),
            IconButton(
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_fix_high, color: Colors.white),
              onPressed: _busy ? null : () => unawaited(_redevelop()),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () => unawaited(_delete()),
            ),
          ],
        ),
      ),
    );
  }
}

class _LookPickerSheet extends StatelessWidget {
  const new({required this.currentLookId});

  final String currentLookId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Re-develop as…',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final look in looks)
            ListTile(
              leading: look.isFree
                  ? const Icon(Icons.check_circle_outline)
                  : const Icon(Icons.lock_outline),
              title: Text(look.displayName),
              trailing: look.id == currentLookId
                  ? const Icon(Icons.radio_button_checked)
                  : null,
              onTap: () => Navigator.of(context).pop(look),
            ),
        ],
      ),
    );
  }
}

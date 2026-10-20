import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shuttr/app/router.dart';
import 'package:shuttr/app/theme.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/core/ui/shuttr_ui.dart';
import 'package:shuttr/features/camera/body/camera_dash.dart';
import 'package:shuttr/features/camera/character/developing_print.dart';
import 'package:shuttr/features/gallery/redevelop_service.dart';
import 'package:shuttr/features/looks/look_registry.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/paywall/entitlement_repository.dart';
import 'package:shuttr/features/settings/settings_repository.dart';

/// A swipeable full-screen viewer (S18) over the photos the gallery grid
/// was showing, starting at whichever one was tapped. Share, re-develop
/// and delete all act on whichever photo is currently on screen.
class PhotoViewerScreen extends ConsumerStatefulWidget {
  const new({required this.photos, required this.initialIndex, super.key});

  final List<StoredPhoto> photos;
  final int initialIndex;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  final _photoStore = PhotoStore();
  final _redevelopService = RedevelopService();
  late final List<StoredPhoto> _photos = List.of(widget.photos);
  late int _currentIndex = widget.initialIndex;
  late final _controller = PageController(initialPage: widget.initialIndex);
  var _busy = false;
  var _zoomed = false;

  StoredPhoto get _current => _photos[_currentIndex];

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_current.photoPath)],
          text: 'shot on shuttr 📸',
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open the share sheet.")),
        );
      }
    }
  }

  /// Deleting is instant and undoable: the photo goes to the trash for as
  /// long as the snackbar's UNDO is on screen.
  Future<void> _delete() async {
    final removed = _current;
    final index = _currentIndex;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _photoStore.trashPhoto(removed.meta.id);
    } on Object {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't delete that photo.")),
        );
      }
      return;
    }
    if (!mounted) return;

    final last = _photos.length == 1;
    if (last) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _photos.removeAt(index);
        if (_currentIndex >= _photos.length) {
          _currentIndex = _photos.length - 1;
        }
      });
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Photo deleted.'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              unawaited(_photoStore.restorePhoto(removed.meta.id));
              if (mounted && !last) {
                setState(() => _photos.insert(index, removed));
              }
            },
          ),
        ),
      );
  }

  Future<void> _redevelop() async {
    final newSpec = await showModalBottomSheet<LookSpec>(
      context: context,
      builder: (context) =>
          _LookPickerSheet(currentLookId: _current.meta.lookId),
    );
    if (newSpec == null || !mounted) return;

    // Saving a paid look needs the unlock (gating is at save, never at
    // preview).
    if (newSpec.isLocked && !ref.read(hasUnlockProvider)) {
      await context.push<bool>(AppRoutes.paywall);
      if (!mounted || !ref.read(hasUnlockProvider)) return;
    }

    setState(() => _busy = true);
    try {
      await _redevelopService.redevelop(photo: _current, newSpec: newSpec);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Saved as a new photo.'),
            action: SnackBarAction(
              label: 'VIEW',
              onPressed: () {
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ),
        );
      }
    } on RedevelopException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't re-develop that photo.")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final look = _specFor(_current) ?? looks.first;
    final mark = cameraMark(look);
    final paper = ref.watch(settingsProvider).bodyTheme.paperColor;
    final frame =
        (widget.photos.length -
                widget.photos.indexWhere((p) => p.meta.id == _current.meta.id))
            .toString()
            .padLeft(3, '0');

    return Scaffold(
      backgroundColor: paper,
      body: PlateLayout(
        paper: paper,
        plate: FilmPlate(
          frameLabel: 'NO.$frame',
          rightLabel: '${_currentIndex + 1}/${_photos.length}',
          photo: PageView.builder(
            controller: _controller,
            itemCount: _photos.length,
            // Zoomed in, a drag pans the photo; it only pages at 1x.
            physics: _zoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            onPageChanged: (index) => setState(() {
              _currentIndex = index;
              _zoomed = false;
            }),
            itemBuilder: (context, index) => _ZoomablePhoto(
              key: ValueKey(_photos[index].meta.id),
              onZoomChanged: (zoomed) {
                if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
              },
              child: PrintImage(
                path: _photos[index].photoPath,
                spec: _specFor(_photos[index]),
                shotAt: _photos[index].meta.capturedAt,
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
              if (mark.sub.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(mark.sub, style: Typo.subSmall),
              ],
            ],
          ),
        ),
        footer: Container(
          decoration: topRule,
          child: Row(
            children: [
              _ViewerAction(label: 'SHARE', onTap: () => unawaited(_share())),
              _ViewerAction(
                flex: 2,
                label: _busy ? 'DEVELOPING…' : 'TRY ANOTHER CAMERA',
                onTap: _busy ? null : () => unawaited(_redevelop()),
              ),
              _ViewerAction(label: 'DELETE', onTap: () => unawaited(_delete())),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerAction extends StatelessWidget {
  const new({required this.label, required this.onTap, this.flex = 1});

  final String label;
  final VoidCallback? onTap;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: TapCell(
        onTap: onTap,
        height: 56,
        alignment: Alignment.center,
        border: const Border(left: BorderSide(color: Palette.ink)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: Typo.labelBold.copyWith(fontSize: 12)),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GroupBand('SAVE A COPY IN…'),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final look in looks)
                  TapCell(
                    onTap: () => Navigator.of(context).pop(look),
                    on: look.id == currentLookId,
                    height: 52,
                    border: bottomRule,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(look.displayName, style: Typo.body),
                        ),
                        if (look.isLocked)
                          const Text('LOCK', style: Typo.micro),
                      ],
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

LookSpec? _specFor(StoredPhoto photo) => lookByIdOrNull(photo.meta.lookId);

/// Pinch to zoom up to 5x, double-tap to jump in on the tapped spot (and
/// back out), and it springs back to fit when you let go below 1x.
class _ZoomablePhoto extends StatefulWidget {
  const new({required this.child, required this.onZoomChanged, super.key});

  final Widget child;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Animation<Matrix4>? _tween;
  Offset _tapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final t = _tween;
      if (t != null) _transform.value = t.value;
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _transform.dispose();
    super.dispose();
  }

  double get _scale => _transform.value.getMaxScaleOnAxis();

  void _animateTo(Matrix4 target) {
    _tween = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward(from: 0);
    widget.onZoomChanged(target.getMaxScaleOnAxis() > 1.01);
  }

  void _doubleTap() {
    if (_scale > 1.05) {
      _animateTo(Matrix4.identity());
    } else {
      const z = 2.6;
      final p = _tapAt;
      _animateTo(
        Matrix4.identity()
          ..translateByDouble(-p.dx * (z - 1), -p.dy * (z - 1), 0, 1)
          ..scaleByDouble(z, z, 1, 1),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _tapAt = d.localPosition,
      onDoubleTap: _doubleTap,
      child: InteractiveViewer(
        transformationController: _transform,
        maxScale: 5,
        onInteractionUpdate: (_) => widget.onZoomChanged(_scale > 1.01),
        onInteractionEnd: (_) {
          if (_scale < 1.01) {
            _animateTo(Matrix4.identity());
          } else {
            widget.onZoomChanged(true);
          }
        },
        child: Center(child: widget.child),
      ),
    );
  }
}

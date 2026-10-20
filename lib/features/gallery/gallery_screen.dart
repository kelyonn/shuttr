import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shuttr/app/theme.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/core/ui/shuttr_route.dart';
import 'package:shuttr/core/ui/shuttr_ui.dart';
import 'package:shuttr/features/camera/body/camera_dash.dart';
import 'package:shuttr/features/camera/character/developing_print.dart';
import 'package:shuttr/features/camera/roll_mode.dart';
import 'package:shuttr/features/dump/dump_screen.dart';
import 'package:shuttr/features/dump/dump_service.dart';
import 'package:shuttr/features/gallery/photo_viewer_screen.dart';
import 'package:shuttr/features/import/import_screen.dart';
import 'package:shuttr/features/looks/look_registry.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/video/video_roll_screen.dart';

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
  late Future<int> _exposuresFuture;

  /// Photo-dump selection mode: photo indices in the order tapped.
  bool _selecting = false;
  final List<int> _selected = [];

  /// Show only this camera's photos (null = all).
  String? _filter;

  void _endSelecting() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  Future<void> _shareSelected(List<StoredPhoto> photos) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [for (final i in _selected) XFile(photos[i].photoPath)],
          text: 'shot on shuttr',
        ),
      );
    } on Object {
      _snack("Couldn't open the share sheet.");
    }
  }

  Future<void> _deleteSelected(List<StoredPhoto> photos) async {
    final n = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $n ${n == 1 ? 'photo' : 'photos'}?'),
        content: const Text(
          "Removes them from Shuttr. Copies already saved to your phone's "
          'gallery stay there.',
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
    if (ok != true) return;
    try {
      for (final i in _selected) {
        await _photoStore.deletePhoto(photos[i].meta.id);
      }
    } on Object {
      _snack("Couldn't delete some photos.");
    }
    if (mounted) {
      _endSelecting();
      await _refresh();
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _photosFuture = _photoStore.listAll();
    _exposuresFuture = _photoStore.exposuresOnRoll();
    photoStoreRevision.addListener(_onStoreChanged);
  }

  void _onStoreChanged() {
    if (mounted) unawaited(_refresh());
  }

  @override
  void dispose() {
    photoStoreRevision.removeListener(_onStoreChanged);
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = _photoStore.listAll();
    setState(() {
      _photosFuture = future;
      _exposuresFuture = _photoStore.exposuresOnRoll();
    });
    await future;
  }

  Future<void> _developNow() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Develop the roll now?'),
        content: const Text(
          'Every frame on the roll develops and goes to your gallery. '
          'Your next shot starts a fresh roll.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep shooting'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Develop'),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    try {
      await RollQueue.drain();
      await _photoStore.developRoll();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't develop the roll. Try again."),
          ),
        );
      }
    }
    if (mounted) await _refresh();
  }

  Future<void> _openViewer(List<StoredPhoto> photos, int index) async {
    await Navigator.of(context).push<void>(
      ShuttrRoute(
        builder: (_) => PhotoViewerScreen(photos: photos, initialIndex: index),
      ),
    );
    // The viewer can delete or re-develop, either of which changes the
    // list — always refresh on the way back rather than tracking which.
    await _refresh();
  }

  Future<void> _import() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty || !mounted) return;
    await Navigator.of(context).push<bool>(
      ShuttrRoute(
        builder: (_) => ImportScreen(paths: [for (final x in picked) x.path]),
      ),
    );
    await _refresh();
  }

  void _openTapes() {
    Navigator.of(context)
        .push<void>(ShuttrRoute(builder: (_) => const VideoRollScreen()));
  }

  void _toggle(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        _selected.add(index);
      }
    });
  }

  Future<void> _openDump(List<StoredPhoto> photos) async {
    final done = await Navigator.of(context).push<bool>(
      ShuttrRoute(
        builder: (_) => DumpScreen(
          photoPaths: [for (final i in _selected) photos[i].photoPath],
        ),
      ),
    );
    if (done ?? false) {
      setState(() {
        _selecting = false;
        _selected.clear();
      });
    }
  }

  String _lookName(StoredPhoto photo) {
    return _lookLabel(photo.meta.lookId);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back leaves photo-dump selection before it leaves the roll.
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() {
            _selecting = false;
            _selected.clear();
          });
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: FutureBuilder<List<StoredPhoto>>(
            future: _photosFuture,
            builder: (context, snapshot) {
              final all = snapshot.data;
              final photos = all == null || _filter == null
                  ? all
                  : [
                      for (final p in all)
                        if (p.meta.lookId == _filter) p,
                    ];
              final count = photos?.length ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    title: 'GALLERY',
                    meta: snapshot.hasError
                        ? "COULDN'T LOAD"
                        : photos == null
                        ? 'DEVELOPING…'
                        : _selecting
                        ? '${_selected.length} SELECTED'
                        : '$count ${count == 1 ? 'PHOTO' : 'PHOTOS'}'
                              '${count > 0 ? ' · NEWEST FIRST' : ''}',
                    onBack: () => context.pop(),
                  ),
                  const SizedBox(height: 12),
                  if (all != null && !_selecting)
                    _FilterRow(
                      lookIds: {for (final p in all) p.meta.lookId}.toList(),
                      lookName: _lookLabel,
                      selected: _filter,
                      onPick: (id) => setState(() => _filter = id),
                    ),
                  FutureBuilder<int>(
                    future: _exposuresFuture,
                    builder: (context, exposures) =>
                        ValueListenableBuilder<int>(
                          valueListenable: inFlightFrames,
                          builder: (context, inFlight, _) {
                            final n = (exposures.data ?? 0) + inFlight;
                            if (n == 0) return const SizedBox.shrink();
                            return _RollInCamera(
                              exposed: n,
                              onDevelop: inFlight > 0
                                  ? null
                                  : () => unawaited(_developNow()),
                            );
                          },
                        ),
                  ),
                  Expanded(
                    child: snapshot.hasError
                        ? _LoadError(onRetry: _refresh)
                        : photos == null
                        ? const SizedBox.shrink()
                        : photos.isEmpty
                        ? _EmptyRoll(
                            onBack: () => context.pop(),
                            filtered: _filter != null,
                          )
                        : _RollGrid(
                            photos: photos,
                            lookName: _lookName,
                            selecting: _selecting,
                            selected: _selected,
                            onOpen: (index) => _selecting
                                ? _toggle(index)
                                : _openViewer(photos, index),
                            onLongPress: (index) {
                              if (_selecting) return;
                              unawaited(HapticFeedback.selectionClick());
                              setState(() {
                                _selecting = true;
                                _selected
                                  ..clear()
                                  ..add(index);
                              });
                            },
                            onRefresh: _refresh,
                          ),
                  ),
                  if (photos == null || photos.isNotEmpty)
                    _RollBar(
                      selecting: _selecting,
                      selectedCount: _selected.length,
                      onImport: _import,
                      onSelect: () => setState(() {
                        _selecting = true;
                        _selected.clear();
                      }),
                      onCancel: _endSelecting,
                      onShare: photos == null || _selected.isEmpty
                          ? null
                          : () => unawaited(_shareSelected(photos)),
                      onDelete: photos == null || _selected.isEmpty
                          ? null
                          : () => unawaited(_deleteSelected(photos)),
                      onCollage:
                          photos == null ||
                              _selected.isEmpty ||
                              _selected.length > DumpService.maxPhotos
                          ? null
                          : () => unawaited(_openDump(photos)),
                      onVideos: _openTapes,
                    ),
                  if (photos != null && photos.isEmpty)
                    _RollBar(
                      selecting: false,
                      selectedCount: 0,
                      onImport: _import,
                      onSelect: null,
                      onCancel: () {},
                      onShare: null,
                      onDelete: null,
                      onCollage: null,
                      onVideos: _openTapes,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The undeveloped roll still in the camera (Roll mode).
class _RollInCamera extends StatelessWidget {
  const new({required this.exposed, required this.onDevelop});

  final int exposed;
  final VoidCallback? onDevelop;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: topRule,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ROLL IN CAMERA', style: Typo.labelBold),
                  const SizedBox(height: 4),
                  Text(
                    '${exposed.toString().padLeft(2, '0')}/$rollLength '
                    'EXPOSED · NO PEEKING',
                    style: Typo.micro,
                  ),
                ],
              ),
            ),
          ),
          TapCell(
            onTap: onDevelop,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            background: Palette.ink,
            child: Text(
              onDevelop == null ? 'DEVELOPING…' : 'DEVELOP NOW',
              style: Typo.labelBold.copyWith(
                fontSize: 12,
                color: Palette.paper,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RollBar extends StatelessWidget {
  const new({
    required this.selecting,
    required this.selectedCount,
    required this.onImport,
    required this.onSelect,
    required this.onCancel,
    required this.onShare,
    required this.onDelete,
    required this.onCollage,
    required this.onVideos,
  });

  final VoidCallback onVideos;
  final bool selecting;
  final int selectedCount;
  final VoidCallback onImport;
  final VoidCallback? onSelect;
  final VoidCallback onCancel;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onCollage;

  @override
  Widget build(BuildContext context) {
    Widget cell(
      String label,
      VoidCallback? onTap, {
      bool solid = false,
      bool first = false,
    }) {
      return Expanded(
        child: TapCell(
          onTap: onTap,
          height: 56,
          alignment: Alignment.center,
          background: solid ? Palette.ink : null,
          border: first
              ? null
              : const Border(left: BorderSide(color: Palette.ink)),
          child: Opacity(
            opacity: onTap == null ? 0.35 : 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: Typo.labelBold.copyWith(
                  fontSize: 12,
                  color: solid ? Palette.paper : null,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: topRule,
      child: Row(
        children: selecting
            ? [
                cell('CANCEL', onCancel, first: true),
                cell('SHARE', onShare),
                cell('DELETE', onDelete),
                cell('COLLAGE', onCollage, solid: true),
              ]
            : [
                cell('IMPORT', onImport, first: true),
                cell('SELECT', onSelect),
                cell('VIDEOS', onVideos),
              ],
      ),
    );
  }
}

/// ALL + one chip per camera that has photos here.
class _FilterRow extends StatelessWidget {
  const new({
    required this.lookIds,
    required this.lookName,
    required this.selected,
    required this.onPick,
  });

  final List<String> lookIds;
  final String Function(String) lookName;
  final String? selected;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    if (lookIds.length < 2) return const SizedBox.shrink();
    Widget chip(String label, String? id) {
      return TapCell(
        onTap: () => onPick(id),
        on: selected == id,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        border: const Border(right: BorderSide(color: Palette.ink)),
        semanticLabel: 'Show $label',
        child: Text(label, style: Typo.label),
      );
    }

    return Container(
      height: 45,
      decoration: topRule,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('ALL', null),
          for (final id in lookIds) chip(lookName(id), id),
        ],
      ),
    );
  }
}

class _RollGrid extends StatelessWidget {
  const new({
    required this.photos,
    required this.lookName,
    required this.onOpen,
    required this.onLongPress,
    required this.onRefresh,
    required this.selecting,
    required this.selected,
  });

  final List<StoredPhoto> photos;
  final String Function(StoredPhoto) lookName;
  final ValueChanged<int> onOpen;
  final ValueChanged<int> onLongPress;
  final Future<void> Function() onRefresh;
  final bool selecting;
  final List<int> selected;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: Palette.ink,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const imageHeight = 112.0;
          const captionHeight = 28.0;
          final cellWidth = constraints.maxWidth / 3;
          return DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Palette.ink)),
            ),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                for (final group in _groupByMonth(photos)) ...[
                  SliverToBoxAdapter(
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      decoration: const BoxDecoration(color: Palette.ink),
                      child: Text(
                        group.title,
                        style: Typo.micro.copyWith(
                          color: Palette.paper,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio:
                          // +1 for the cell's bottom border.
                          cellWidth / (imageHeight + captionHeight + 1),
                    ),
                    itemCount: group.count,
                    itemBuilder: (context, i) {
                      final index = group.start + i;
                      final photo = photos[index];
                      final shot = photo.meta.capturedAt;
                      final frameNo = '${shot.day} ${_months[shot.month - 1]}';
                      return TapCell(
                        onTap: () => onOpen(index),
                        onLongPress: () => onLongPress(index),
                        border: Border(
                          bottom: const BorderSide(color: Palette.ink),
                          right: i % 3 != 2
                              ? const BorderSide(color: Palette.ink)
                              : BorderSide.none,
                        ),
                        semanticLabel: '${lookName(photo)}, $frameNo',
                        child: Column(
                          children: [
                            SizedBox(
                              height: imageHeight,
                              width: double.infinity,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Matted, never cropped: every frame keeps the
                                  // shape its camera shot it in.
                                  ColoredBox(
                                    color: Palette.stage,
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: PrintImage(
                                        path: photo.photoPath,
                                        spec: _specFor(photo),
                                        shotAt: photo.meta.capturedAt,
                                      ),
                                    ),
                                  ),
                                  if (selecting)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: selected.contains(index)
                                              ? Palette.ink
                                              : Palette.paper.withValues(
                                                  alpha: 0.6,
                                                ),
                                          border: Border.all(
                                            color: Palette.ink,
                                          ),
                                        ),
                                        child: Text(
                                          selected.contains(index)
                                              ? '${selected.indexOf(index) + 1}'
                                              : '',
                                          style: Typo.label.copyWith(
                                            color: Palette.paper,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              height: captionHeight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    frameNo,
                                    style: Typo.micro.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      cameraMark(_specFor(photo) ?? looks.first)
                                          .name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Typo.micro,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A run of photos from one month, as a slice of the (newest-first) list.
class _MonthGroup {
  const _MonthGroup(this.title, this.start, this.count);

  final String title;
  final int start;
  final int count;
}

List<_MonthGroup> _groupByMonth(List<StoredPhoto> photos) {
  final groups = <_MonthGroup>[];
  var start = 0;
  for (var i = 1; i <= photos.length; i++) {
    final changed =
        i == photos.length ||
        photos[i].meta.capturedAt.year != photos[start].meta.capturedAt.year ||
        photos[i].meta.capturedAt.month != photos[start].meta.capturedAt.month;
    if (changed) {
      final d = photos[start].meta.capturedAt;
      groups.add(
        _MonthGroup('${_months[d.month - 1]} ${d.year}', start, i - start),
      );
      start = i;
    }
  }
  return groups;
}

class _LoadError extends StatelessWidget {
  const new({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("The roll wouldn't load.", style: Typo.sub),
          const SizedBox(height: 20),
          TapCell(
            onTap: () => unawaited(onRetry()),
            height: 56,
            alignment: Alignment.center,
            background: Palette.ink,
            child: Text(
              'TRY AGAIN',
              style: Typo.labelBold.copyWith(
                fontSize: 12,
                color: Palette.paper,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRoll extends StatelessWidget {
  const new({required this.onBack, this.filtered = false});

  final VoidCallback onBack;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            filtered
                ? 'Nothing from this camera yet.'
                : 'No photos yet. Go shoot one.',
            style: Typo.sub,
          ),
          const SizedBox(height: 20),
          TapCell(
            onTap: onBack,
            height: 56,
            alignment: Alignment.center,
            background: Palette.ink,
            child: Text(
              'BACK TO CAMERA',
              style: Typo.labelBold.copyWith(
                fontSize: 12,
                letterSpacing: 1.9,
                color: Palette.paper,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

LookSpec? _specFor(StoredPhoto photo) => lookByIdOrNull(photo.meta.lookId);

const _months = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

/// A camera's display name, or a tidied id for a camera that has since been
/// removed from the app (so old photos never show `NIGHT_FLASH`).
String _lookLabel(String id) =>
    (lookByIdOrNull(id)?.displayName ?? id.replaceAll('_', ' ')).toUpperCase();

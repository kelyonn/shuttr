import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shuttr/app/theme.dart';
import 'package:shuttr/core/ui/shuttr_ui.dart';
import 'package:shuttr/features/dump/dump_service.dart';
import 'package:shuttr/features/settings/settings_repository.dart';

/// Photo dump export: pick 4:5 or 1:1, fill or border, then save every
/// slide to the gallery in order and open the share sheet with all of them.
class DumpScreen extends ConsumerStatefulWidget {
  const new({required this.photoPaths, super.key});

  /// Selected photos, in the order they were tapped.
  final List<String> photoPaths;

  @override
  ConsumerState<DumpScreen> createState() => _DumpScreenState();
}

class _DumpScreenState extends ConsumerState<DumpScreen> {
  final _service = DumpService();
  DumpRatio _ratio = DumpRatio.portrait;
  bool _fill = true;
  bool _busy = false;
  int _done = 0;
  String? _error;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _done = 0;
      _error = null;
    });
    var files = <String>[];
    try {
      final hasAccess = await Gal.hasAccess() || await Gal.requestAccess();
      if (!hasAccess) {
        setState(() => _error = 'Allow photo access in Settings to export.');
        return;
      }
      files = await _service.export(
        photoPaths: widget.photoPaths,
        ratio: _ratio,
        fill: _fill,
        onProgress: (done) {
          if (mounted) setState(() => _done = done);
        },
      );
      await SharePlus.instance.share(
        ShareParams(files: [for (final f in files) XFile(f)]),
      );
      if (mounted) context.pop(true);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = "Couldn't export: $error");
    } finally {
      for (final f in files) {
        final file = File(f);
        if (file.existsSync()) await file.delete();
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paper = ref.watch(settingsProvider).bodyTheme.paperColor;
    final total = widget.photoPaths.length;

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'DUMP',
              meta: '${total.toString().padLeft(2, '0')} SLIDES · IN ORDER',
              onBack: () {
                if (!_busy) context.pop(false);
              },
            ),
            const GroupBand('01 / SHAPE'),
            Row(
              children: [
                for (final ratio in DumpRatio.values)
                  Expanded(
                    child: TapCell(
                      onTap: () => setState(() => _ratio = ratio),
                      on: _ratio == ratio,
                      height: 52,
                      alignment: Alignment.center,
                      border: bottomRule,
                      child: Text(ratio.label, style: Typo.labelBold),
                    ),
                  ),
              ],
            ),
            const GroupBand('02 / CROP'),
            Row(
              children: [
                Expanded(
                  child: TapCell(
                    onTap: () => setState(() => _fill = true),
                    on: _fill,
                    height: 52,
                    alignment: Alignment.center,
                    border: bottomRule,
                    child: const Text('FILL', style: Typo.labelBold),
                  ),
                ),
                Expanded(
                  child: TapCell(
                    onTap: () => setState(() => _fill = false),
                    on: !_fill,
                    height: 52,
                    alignment: Alignment.center,
                    border: bottomRule,
                    child: const Text('BORDER', style: Typo.labelBold),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _ratio.aspect,
                    child: Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(_fill ? 0 : 12),
                      child: Image.file(
                        File(widget.photoPaths.first),
                        fit: _fill ? BoxFit.cover : BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(_error!, style: Typo.small),
              ),
            Container(
              decoration: topRule,
              child: TapCell(
                onTap: _busy ? null : () => unawaited(_export()),
                height: 56,
                alignment: Alignment.center,
                background: Palette.ink,
                child: Text(
                  _busy ? 'EXPORTING $_done / $total' : 'EXPORT & SHARE',
                  style: Typo.labelBold.copyWith(
                    fontSize: 12,
                    color: Palette.paper,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

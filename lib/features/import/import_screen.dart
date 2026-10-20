import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shuttr/app/router.dart';
import 'package:shuttr/app/theme.dart';
import 'package:shuttr/core/ui/shuttr_ui.dart';
import 'package:shuttr/features/import/import_service.dart';
import 'package:shuttr/features/looks/look_registry.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/paywall/entitlement_repository.dart';
import 'package:shuttr/features/settings/settings_repository.dart';

/// Pick a camera for the photos just chosen, then develop them one by one.
/// Every camera can be chosen; keeping (which is what importing does)
/// needs the unlock for paid ones — gating at save, not at preview.
class ImportScreen extends ConsumerStatefulWidget {
  const new({required this.paths, super.key});

  final List<String> paths;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _service = ImportService();
  LookSpec _look = looks.first;
  int _done = 0;
  int _failed = 0;
  bool _running = false;
  bool _finished = false;

  Future<void> _develop() async {
    setState(() {
      _running = true;
      _done = 0;
      _failed = 0;
    });
    final override = ref.read(settingsProvider).dateStampOverride;
    for (final path in widget.paths) {
      if (!mounted) return;
      try {
        await _service.importOne(
          sourcePath: path,
          spec: _look,
          dateStampOverride: override,
        );
        if (mounted) setState(() => _done++);
      } on Exception {
        if (mounted) setState(() => _failed++);
      }
    }
    if (mounted) {
      setState(() {
        _running = false;
        _finished = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final paper = ref.watch(settingsProvider).bodyTheme.paperColor;
    final owned = ref.watch(hasUnlockProvider);
    final total = widget.paths.length;
    final locked = _look.isLocked && !owned;

    return PopScope(
      canPop: !_running,
      child: Scaffold(
        backgroundColor: paper,
        body: SafeArea(
          child: Column(
            children: [
              PageHeader(
                title: 'IMPORT',
                meta:
                    '${total.toString().padLeft(2, '0')} '
                    '${total == 1 ? 'PHOTO' : 'PHOTOS'}',
                onBack: () {
                  if (!_running) context.pop(_finished);
                },
              ),
              Expanded(
                child: _running || _finished
                    ? _Progress(
                        done: _done,
                        failed: _failed,
                        total: total,
                        finished: _finished,
                      )
                    : ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          const GroupBand('01 / PICK A CAMERA'),
                          for (var i = 0; i < looks.length; i++)
                            TapCell(
                              onTap: () => setState(() => _look = looks[i]),
                              on: looks[i].id == _look.id,
                              height: 52,
                              border: bottomRule,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    (i + 1).toString().padLeft(2, '0'),
                                    style: Typo.micro,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      looks[i].displayName,
                                      style: Typo.body,
                                    ),
                                  ),
                                  if (looks[i].isLocked)
                                    const Text('LOCK', style: Typo.micro),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              if (!_running && !_finished)
                Container(
                  decoration: topRule,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (locked)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Text(
                            '${_look.displayName} can be previewed. Keeping '
                            'it needs the unlock.',
                            style: Typo.small,
                          ),
                        ),
                      TapCell(
                        onTap: locked
                            ? () => unawaited(_unlock())
                            : () => unawaited(_develop()),
                        height: 56,
                        alignment: Alignment.center,
                        background: Palette.ink,
                        child: Text(
                          locked ? 'UNLOCK' : 'DEVELOP $total',
                          style: Typo.labelBold.copyWith(
                            fontSize: 12,
                            color: Palette.paper,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    await context.push<bool>(AppRoutes.paywall);
  }
}

class _Progress extends StatelessWidget {
  const new({
    required this.done,
    required this.failed,
    required this.total,
    required this.finished,
  });

  final int done;
  final int failed;
  final int total;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(finished ? 'DONE' : 'DEVELOPING', style: Typo.name),
          const SizedBox(height: 12),
          Text(
            '${done + failed} / $total'
            '${failed > 0 ? ' · $failed FAILED' : ''}',
            style: Typo.label,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: total == 0 ? 0 : (done + failed) / total,
            minHeight: 8,
            color: Palette.ink,
            backgroundColor: Palette.ink.withValues(alpha: 0.15),
            borderRadius: BorderRadius.zero,
          ),
          if (finished) ...[
            const SizedBox(height: 24),
            TapCell(
              onTap: () => context.pop(true),
              height: 56,
              alignment: Alignment.center,
              background: Palette.ink,
              child: Text(
                'VIEW ROLL',
                style: Typo.labelBold.copyWith(
                  fontSize: 12,
                  color: Palette.paper,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shuttr/app/theme.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/core/ui/shuttr_ui.dart';
import 'package:shuttr/features/looks/date_stamp.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/paywall/entitlement_repository.dart';
import 'package:shuttr/features/settings/settings_repository.dart';
import 'package:url_launcher/url_launcher.dart';

/// D-034: support@shuttr.app, refunds are generous, replies happen fast —
/// none of that is this screen's job, but the address is.
const _supportEmail = 'support@shuttr.app';

/// The eventual page on the domain from docs/STRATEGY.md — doesn't exist
/// until M7 ships the landing site, but this is the settled URL.
const _privacyPolicyUrl = 'https://shuttr.app/privacy';

class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final dateStamp =
        settings.dateStampOverride ?? const DateStampSettings(enabled: false);

    return Scaffold(
      backgroundColor: settings.bodyTheme.paperColor,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            PageHeader(
              title: 'SETTINGS',
              meta: 'SHUTTR 1.0 · ALL LOCAL',
              onBack: () => context.pop(),
            ),
            const GroupBand('01 / EVERYDAY'),
            _ToggleRow(
              title: 'DATE STAMP',
              sub: 'Burn the date into the corner.',
              on: dateStamp.enabled,
              onTap: () => unawaited(
                notifier.setDateStamp(
                  dateStamp.copyWith(enabled: !dateStamp.enabled),
                ),
              ),
            ),
            if (dateStamp.enabled) ...[
              _ValueRow(
                title: 'FORMAT',
                value: switch (dateStamp.format) {
                  DateStampFormat.yyMmDd => "'YY MM DD",
                  DateStampFormat.isoDotted => 'YYYY.MM.DD',
                  DateStampFormat.mmDdYy => "MM DD 'YY",
                },
                onTap: () => unawaited(
                  notifier.setDateStamp(
                    dateStamp.copyWith(
                      format: _next(DateStampFormat.values, dateStamp.format),
                    ),
                  ),
                ),
              ),
              _ValueRow(
                title: 'POSITION',
                value: switch (dateStamp.position) {
                  DateStampPosition.bottomRight => 'BOTTOM RIGHT',
                  DateStampPosition.bottomLeft => 'BOTTOM LEFT',
                  DateStampPosition.topRight => 'TOP RIGHT',
                },
                onTap: () => unawaited(
                  notifier.setDateStamp(
                    dateStamp.copyWith(
                      position: _next(
                        DateStampPosition.values,
                        dateStamp.position,
                      ),
                    ),
                  ),
                ),
              ),
              _ValueRow(
                title: 'STYLE',
                value: dateStamp.colorStyle.name.toUpperCase(),
                onTap: () => unawaited(
                  notifier.setDateStamp(
                    dateStamp.copyWith(
                      colorStyle: _next(
                        DateStampColorStyle.values,
                        dateStamp.colorStyle,
                      ),
                    ),
                  ),
                ),
              ),
              _ValueRow(
                title: 'YEAR',
                value: dateStamp.yearOverride == null
                    ? 'ACTUAL'
                    : '${dateStamp.yearOverride}',
                onTap: () => unawaited(_pickYear(context, notifier, dateStamp)),
              ),
              _StampSample(settings: dateStamp),
            ],
            _ToggleRow(
              title: 'MIRROR SELFIES',
              sub: 'Save selfies flipped, as you saw them on screen.',
              on: settings.mirrorFrontPhotos,
              onTap: () => unawaited(
                notifier.setMirrorFrontPhotos(!settings.mirrorFrontPhotos),
              ),
            ),
            const GroupBand('02 / CHARACTER'),
            _ToggleRow(
              title: 'ROLL MODE',
              sub: '27 exposures. No peeking until the roll is developed.',
              on: settings.rollMode,
              onTap: () => unawaited(_toggleRoll(context, notifier, settings)),
            ),
            _ToggleRow(
              title: 'HAPPY ACCIDENTS',
              sub:
                  'Exposure drifts, the flash sometimes misfires, focus '
                  'sometimes misses. Like the real thing.',
              on: settings.happyAccidents,
              onTap: () => unawaited(
                notifier.setHappyAccidents(!settings.happyAccidents),
              ),
            ),
            _ToggleRow(
              title: 'REAL VIEWFINDER',
              sub:
                  "Look through the camera's own finder: a tiny LCD on "
                  'digicams, a window on film cameras. The look shows up '
                  'after the shot.',
              on: settings.authenticViewfinder,
              onTap: () => unawaited(
                notifier.setAuthenticViewfinder(!settings.authenticViewfinder),
              ),
            ),
            const GroupBand('03 / BODY'),
            Container(
              constraints: const BoxConstraints(minHeight: 68),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(border: bottomRule),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('COLOUR', style: Typo.labelBold),
                      const SizedBox(height: 6),
                      Text(settings.bodyTheme.label, style: Typo.small),
                    ],
                  ),
                  Row(
                    children: [
                      for (final theme in CameraBodyTheme.values)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _BodyChip(
                            theme: theme,
                            selected: theme == settings.bodyTheme,
                            onTap: () =>
                                unawaited(notifier.setBodyTheme(theme)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const GroupBand('04 / STORAGE'),
            const _StorageTile(),
            const GroupBand('05 / ABOUT'),
            if (!kAllLooksFree)
              _LinkRow(
                title: 'RESTORE UNLOCK',
                onTap: () => unawaited(_restore(context, ref)),
              ),
            _LinkRow(
              title: 'SUPPORT',
              sub: _supportEmail,
              onTap: () => unawaited(_contactSupport(context)),
            ),
            _LinkRow(
              title: 'PRIVACY',
              onTap: () => unawaited(_openPrivacy(context)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 20),
              child: Text(
                'No ads. No accounts. Everything stays on this phone.',
                style: Typo.statement,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(entitlementRepositoryProvider);
    if (!repo.isConfigured) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Store not connected in this build.')),
      );
      return;
    }
    try {
      final owned = await repo.restore();
      ref.read(hasUnlockProvider.notifier).set(owned: owned);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            owned ? 'Unlock restored.' : 'Nothing to restore on this account.',
          ),
        ),
      );
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't reach the store.")),
      );
    }
  }

  /// Roll mode changes the whole flow (no review, frames develop later), so
  /// say so the moment it is switched on.
  Future<void> _toggleRoll(
    BuildContext context,
    SettingsNotifier notifier,
    SettingsState settings,
  ) async {
    if (settings.rollMode) {
      await notifier.setRollMode(false);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turn on Roll mode?'),
        content: const Text(
          'Each shot goes straight onto a 27-frame roll. No review after '
          'the shutter, and no peeking: the whole roll develops when it is '
          'full, or when you tap Develop Now in the gallery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Turn on'),
          ),
        ],
      ),
    );
    if (ok ?? false) await notifier.setRollMode(true);
  }

  T _next<T extends Enum>(List<T> values, T current) =>
      values[(current.index + 1) % values.length];

  Future<void> _pickYear(
    BuildContext context,
    SettingsNotifier notifier,
    DateStampSettings dateStamp,
  ) async {
    final controller = TextEditingController(
      text: '${dateStamp.yearOverride ?? DateTime.now().year}',
    );
    final year = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Date-stamp year'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          autofocus: true,
          decoration: const InputDecoration(helperText: '1970 to 2099'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(0),
            child: const Text('Use actual year'),
          ),
          FilledButton(
            onPressed: () {
              final y = int.tryParse(controller.text);
              if (y != null && y >= 1970 && y <= 2099) {
                Navigator.of(context).pop(y);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (year == 0) {
      await notifier.setDateStamp(dateStamp.copyWith(clearYearOverride: true));
    } else if (year != null) {
      await notifier.setDateStamp(dateStamp.copyWith(yearOverride: year));
    }
  }

  Future<void> _openPrivacy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(_privacyPolicyUrl));
    } on Object {
      ok = false;
    }
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open the privacy page.")),
      );
    }
  }

  Future<void> _contactSupport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final info = await PackageInfo.fromPlatform();
    final body = Uri.encodeComponent(
      '\n\n---\n'
      'App: ${info.version}+${info.buildNumber}\n'
      'Platform: ${Platform.operatingSystem} '
      '${Platform.operatingSystemVersion}',
    );
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse('mailto:$_supportEmail?subject=Shuttr%20support&body=$body'),
      );
    } on Object {
      ok = false;
    }
    if (!ok) {
      await Clipboard.setData(const ClipboardData(text: _supportEmail));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No mail app found. Address copied: $_supportEmail'),
        ),
      );
    }
  }
}

class _ToggleRow extends StatelessWidget {
  const new({
    required this.title,
    required this.sub,
    required this.on,
    required this.onTap,
  });

  final String title;
  final String sub;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapCell(
      onTap: onTap,
      border: bottomRule,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      semanticLabel: '$title ${on ? 'on' : 'off'}',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Typo.labelBold),
                const SizedBox(height: 6),
                Opacity(opacity: 0.72, child: Text(sub, style: Typo.small)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 56,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? Palette.ink : null,
              border: Border.all(color: Palette.ink),
            ),
            child: Text(
              on ? 'ON' : 'OFF',
              style: Typo.label.copyWith(
                letterSpacing: 1.1,
                color: on ? Palette.paper : Palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row that cycles through values (or opens a picker) when tapped.
class _ValueRow extends StatelessWidget {
  const new({required this.title, required this.value, required this.onTap});

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapCell(
      onTap: onTap,
      height: 52,
      border: bottomRule,
      padding: const EdgeInsets.only(left: 32, right: 16),
      semanticLabel: '$title $value',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Typo.label),
          Text(value, style: Typo.label.copyWith(letterSpacing: 1)),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const new({required this.title, required this.onTap, this.sub});

  final String title;
  final String? sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapCell(
      onTap: onTap,
      height: 56,
      border: bottomRule,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(title, style: Typo.labelBold),
          if (sub != null) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: 0.72,
                child: Text(
                  sub!,
                  style: Typo.small,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ] else
            const Spacer(),
          const Text('→', style: Typo.body),
        ],
      ),
    );
  }
}

/// What the date stamp will look like, updating as the rows above change.
class _StampSample extends StatelessWidget {
  const new({required this.settings});

  final DateStampSettings settings;

  @override
  Widget build(BuildContext context) {
    final align = switch (settings.position) {
      DateStampPosition.bottomRight => Alignment.bottomRight,
      DateStampPosition.bottomLeft => Alignment.bottomLeft,
      DateStampPosition.topRight => Alignment.topRight,
    };
    return Container(
      height: 72,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(10),
      alignment: align,
      color: Palette.stage,
      child: Text(
        formatDateStamp(DateTime.now(), settings),
        style: const TextStyle(
          fontFamily: 'IBMPlexMono',
          fontSize: 10,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.6,
          color: Color(0xB8E25A1C),
        ),
      ),
    );
  }
}

class _BodyChip extends StatelessWidget {
  const new({required this.theme, required this.selected, required this.onTap});

  final CameraBodyTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: theme.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.paperColor,
            border: Border.all(color: Palette.ink),
            boxShadow: selected
                ? [
                    const BoxShadow(color: Palette.paper, spreadRadius: 2),
                    const BoxShadow(color: Palette.ink, spreadRadius: 3),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class _StorageTile extends StatefulWidget {
  const new();

  @override
  State<_StorageTile> createState() => _StorageTileState();
}

class _StorageTileState extends State<_StorageTile> {
  final _photoStore = PhotoStore();
  Future<int>? _sizeFuture;

  @override
  void initState() {
    super.initState();
    _sizeFuture = _photoStore.originalsSizeBytes();
  }

  Future<void> _clearOriginals() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear originals?'),
        content: const Text(
          "This frees up space but re-develop won't be able to reprocess "
          'past photos in a different look. Saved photos in your gallery '
          "are untouched — they're already saved separately.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _photoStore.clearOriginals();
    if (mounted) {
      setState(() => _sizeFuture = _photoStore.originalsSizeBytes());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _sizeFuture,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        final label = bytes == null
            ? 'Calculating…'
            : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB of originals';
        final canClear = bytes != null && bytes > 0;
        return TapCell(
          onTap: canClear ? () => unawaited(_clearOriginals()) : null,
          border: bottomRule,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CLEAR ORIGINALS', style: Typo.labelBold),
                    const SizedBox(height: 6),
                    Opacity(
                      opacity: 0.72,
                      child: Text(label, style: Typo.small),
                    ),
                  ],
                ),
              ),
              Opacity(
                opacity: canClear ? 1 : 0.35,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Palette.ink),
                  ),
                  child: const Text('CLEAR', style: Typo.label),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

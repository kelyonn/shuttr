import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/features/looks/date_stamp.dart';
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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Date stamp'),
          SwitchListTile(
            title: const Text('Show date stamp'),
            subtitle: const Text(
              'Applies to every camera, overriding its default',
            ),
            value: dateStamp.enabled,
            onChanged: (value) => unawaited(
              notifier.setDateStamp(dateStamp.copyWith(enabled: value)),
            ),
          ),
          if (dateStamp.enabled) ...[
            ListTile(
              title: const Text('Format'),
              trailing: DropdownButton<DateStampFormat>(
                value: dateStamp.format,
                onChanged: (value) {
                  if (value != null) {
                    unawaited(
                      notifier.setDateStamp(dateStamp.copyWith(format: value)),
                    );
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: DateStampFormat.yyMmDd,
                    child: Text("'YY MM DD"),
                  ),
                  DropdownMenuItem(
                    value: DateStampFormat.isoDotted,
                    child: Text('YYYY.MM.DD'),
                  ),
                  DropdownMenuItem(
                    value: DateStampFormat.mmDdYy,
                    child: Text("MM DD 'YY"),
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Position'),
              trailing: DropdownButton<DateStampPosition>(
                value: dateStamp.position,
                onChanged: (value) {
                  if (value != null) {
                    unawaited(
                      notifier.setDateStamp(
                        dateStamp.copyWith(position: value),
                      ),
                    );
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: DateStampPosition.bottomRight,
                    child: Text('Bottom right'),
                  ),
                  DropdownMenuItem(
                    value: DateStampPosition.bottomLeft,
                    child: Text('Bottom left'),
                  ),
                  DropdownMenuItem(
                    value: DateStampPosition.topRight,
                    child: Text('Top right'),
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Style'),
              trailing: DropdownButton<DateStampColorStyle>(
                value: dateStamp.colorStyle,
                onChanged: (value) {
                  if (value != null) {
                    unawaited(
                      notifier.setDateStamp(
                        dateStamp.copyWith(colorStyle: value),
                      ),
                    );
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: DateStampColorStyle.orange,
                    child: Text('Orange'),
                  ),
                  DropdownMenuItem(
                    value: DateStampColorStyle.yellow,
                    child: Text('Yellow'),
                  ),
                  DropdownMenuItem(
                    value: DateStampColorStyle.white,
                    child: Text('White'),
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Year'),
              subtitle: Text(
                dateStamp.yearOverride == null
                    ? 'Actual capture year'
                    : '${dateStamp.yearOverride}',
              ),
              trailing: dateStamp.yearOverride == null
                  ? TextButton(
                      onPressed: () => _pickYear(context, notifier, dateStamp),
                      child: const Text('Set'),
                    )
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => unawaited(
                        notifier.setDateStamp(
                          dateStamp.copyWith(clearYearOverride: true),
                        ),
                      ),
                    ),
              onTap: () => _pickYear(context, notifier, dateStamp),
            ),
          ],
          const Divider(),
          const _SectionHeader('Camera'),
          SwitchListTile(
            title: const Text('Mirror front photos'),
            subtitle: const Text(
              'Save selfies matching the viewfinder, not how others see you',
            ),
            value: settings.mirrorFrontPhotos,
            onChanged: (value) =>
                unawaited(notifier.setMirrorFrontPhotos(value)),
          ),
          const Divider(),
          const _SectionHeader('Purchases'),
          ListTile(
            title: const Text('Restore purchases'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Purchases aren't live yet — coming soon."),
              ),
            ),
          ),
          const Divider(),
          const _SectionHeader('Storage'),
          const _StorageTile(),
          const Divider(),
          const _SectionHeader('Support'),
          ListTile(
            title: const Text('Contact support'),
            subtitle: const Text(_supportEmail),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unawaited(_contactSupport()),
          ),
          ListTile(
            title: const Text('Privacy policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unawaited(launchUrl(Uri.parse(_privacyPolicyUrl))),
          ),
        ],
      ),
    );
  }

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
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (year != null) {
      await notifier.setDateStamp(dateStamp.copyWith(yearOverride: year));
    }
  }

  Future<void> _contactSupport() async {
    final info = await PackageInfo.fromPlatform();
    final body = Uri.encodeComponent(
      '\n\n---\n'
      'App: ${info.version}+${info.buildNumber}\n'
      'Platform: ${Platform.operatingSystem} '
      '${Platform.operatingSystemVersion}',
    );
    await launchUrl(
      Uri.parse('mailto:$_supportEmail?subject=Shuttr%20support&body=$body'),
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
        return ListTile(
          title: const Text('Clear originals'),
          subtitle: Text(label),
          trailing: FilledButton.tonal(
            onPressed: bytes == null || bytes == 0
                ? null
                : () => unawaited(_clearOriginals()),
            child: const Text('Clear'),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const new(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

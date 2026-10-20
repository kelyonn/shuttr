import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shuttr/app/theme.dart';
import 'package:shuttr/core/ui/shuttr_ui.dart';
import 'package:shuttr/features/looks/look_registry.dart';
import 'package:shuttr/features/paywall/entitlement_repository.dart';
import 'package:shuttr/features/settings/settings_repository.dart';

/// The one-time unlock. One honest price, previews stay free, close is
/// always visible, no timers (CLAUDE.md rule 1). Pops `true` if the user
/// owns the unlock when it closes.
class PaywallScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  UnlockOffer? _offer;
  bool _loading = true;
  bool _busy = false;
  String? _message;

  EntitlementRepository get _repo => ref.read(entitlementRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_loadOffer());
  }

  Future<void> _loadOffer() async {
    try {
      final offer = await _repo.loadOffer();
      if (mounted) setState(() => _offer = offer);
    } on Exception {
      if (mounted) setState(() => _message = "Couldn't reach the store.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buy() async {
    final offer = _offer;
    if (offer == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final owned = await _repo.purchase(offer);
      ref.read(hasUnlockProvider.notifier).set(owned: owned);
      if (owned && mounted) context.pop(true);
    } on Exception {
      if (mounted) setState(() => _message = "The purchase didn't go through.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final owned = await _repo.restore();
      ref.read(hasUnlockProvider.notifier).set(owned: owned);
      if (owned && mounted) {
        context.pop(true);
      } else if (mounted) {
        setState(() => _message = 'Nothing to restore on this account.');
      }
    } on Exception {
      if (mounted) setState(() => _message = "Couldn't reach the store.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paper = ref.watch(settingsProvider).bodyTheme.paperColor;
    final owned = ref.watch(hasUnlockProvider);
    final locked = looks.where((l) => !l.isFree).toList();
    final offer = _offer;

    final String buyLabel;
    if (owned) {
      buyLabel = 'UNLOCKED';
    } else if (_busy) {
      buyLabel = 'ONE MOMENT…';
    } else if (offer != null) {
      buyLabel = 'UNLOCK · ${offer.priceString}';
    } else {
      buyLabel = _loading ? 'LOADING…' : 'UNAVAILABLE';
    }

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  PageHeader(
                    title: 'OWN IT',
                    meta: 'ONE-TIME · ALL CAMERAS · NO ADS',
                    onBack: () => context.pop(owned),
                  ),
                  const GroupBand('01 / WHAT YOU GET'),
                  for (final look in locked)
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: const BoxDecoration(border: bottomRule),
                      alignment: Alignment.centerLeft,
                      child: Text(look.displayName, style: Typo.body),
                    ),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(border: bottomRule),
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'Every camera we add later',
                      style: Typo.body,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(offer?.priceString ?? '—', style: Typo.display),
                        const SizedBox(height: 6),
                        const Text(
                          'once. forever. no subscription.',
                          style: Typo.sub,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Every camera is free to preview. Buying lets you '
                          'keep the shots.',
                          style: Typo.small,
                        ),
                        if (!_repo.isConfigured) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Store not connected in this build.',
                            style: Typo.small.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (_message != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _message!,
                            style: Typo.small.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: topRule,
              child: Row(
                children: [
                  Expanded(
                    child: TapCell(
                      onTap: _busy ? null : _restore,
                      height: 56,
                      alignment: Alignment.center,
                      child: const Text('RESTORE', style: Typo.labelBold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TapCell(
                      onTap: (offer == null || _busy || owned) ? null : _buy,
                      height: 56,
                      alignment: Alignment.center,
                      background: Palette.ink,
                      child: Text(
                        buyLabel,
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
          ],
        ),
      ),
    );
  }
}

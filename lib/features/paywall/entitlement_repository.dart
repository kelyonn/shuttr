import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuttr/features/settings/settings_repository.dart';

/// RevenueCat entitlement id for the one-time Lifetime unlock (D-011).
const _entitlementId = 'photo';

/// What the paywall shows for the unlock product.
class UnlockOffer {
  const new({required this.priceString, required this.package});

  /// Localised price from the store, e.g. `₹399`.
  final String priceString;

  /// The RevenueCat package to buy; null in fakes.
  final Package? package;
}

/// Thin wrapper over the store so the rest of the app (and tests) never
/// touch `purchases_flutter` directly.
abstract interface class EntitlementRepository {
  /// False when no store key is configured (debug builds without
  /// `--dart-define=RC_API_KEY=...`): the paywall then explains, instead of
  /// pretending to sell.
  bool get isConfigured;

  /// Emits whenever the store reports a change (purchase, refund, restore).
  Stream<bool> get unlockedChanges;

  Future<bool> fetchUnlocked();
  Future<UnlockOffer?> loadOffer();

  /// Buys the unlock. Returns whether the user now owns it (false if they
  /// cancelled).
  Future<bool> purchase(UnlockOffer offer);

  Future<bool> restore();
}

/// Used when there's no RevenueCat key: nothing is for sale.
class DisabledEntitlementRepository implements EntitlementRepository {
  const new();

  @override
  bool get isConfigured => false;

  @override
  Stream<bool> get unlockedChanges => const Stream.empty();

  @override
  Future<bool> fetchUnlocked() async => false;

  @override
  Future<UnlockOffer?> loadOffer() async => null;

  @override
  Future<bool> purchase(UnlockOffer offer) async => false;

  @override
  Future<bool> restore() async => false;
}

/// RevenueCat-backed repository. Call [RevenueCatEntitlementRepository.create]
/// once from `main()` with the API key from `--dart-define=RC_API_KEY`.
class RevenueCatEntitlementRepository implements EntitlementRepository {
  new _();

  static Future<RevenueCatEntitlementRepository> create(String apiKey) async {
    await Purchases.configure(PurchasesConfiguration(apiKey));
    final repo = RevenueCatEntitlementRepository._();
    Purchases.addCustomerInfoUpdateListener(
      (info) => repo._controller.add(_owns(info)),
    );
    return repo;
  }

  final _controller = StreamController<bool>.broadcast();

  static bool _owns(CustomerInfo info) =>
      info.entitlements.active.containsKey(_entitlementId);

  @override
  bool get isConfigured => true;

  @override
  Stream<bool> get unlockedChanges => _controller.stream;

  @override
  Future<bool> fetchUnlocked() async =>
      _owns(await Purchases.getCustomerInfo());

  @override
  Future<UnlockOffer?> loadOffer() async {
    final offerings = await Purchases.getOfferings();
    final package =
        offerings.current?.lifetime ??
        offerings.current?.availablePackages.firstOrNull;
    if (package == null) return null;
    return UnlockOffer(
      priceString: package.storeProduct.priceString,
      package: package,
    );
  }

  @override
  Future<bool> purchase(UnlockOffer offer) async {
    final package = offer.package;
    if (package == null) return false;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return _owns(result.customerInfo);
    } on PlatformException catch (error) {
      final code = PurchasesErrorHelper.getErrorCode(error);
      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  @override
  Future<bool> restore() async => _owns(await Purchases.restorePurchases());
}

final entitlementRepositoryProvider = Provider<EntitlementRepository>(
  (ref) => const DisabledEntitlementRepository(),
);

/// Whether the one-time unlock is owned. Starts from the last value we saw
/// (so a paid user is never locked out while offline or at cold start),
/// then follows the store. Locked looks stay previewable regardless; this
/// only gates Keep (CLAUDE.md rule 3).
class UnlockNotifier extends Notifier<bool> {
  static const _key = 'hasUnlock';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final repo = ref.watch(entitlementRepositoryProvider);
    final sub = repo.unlockedChanges.listen((owned) => _set(prefs, owned));
    ref.onDispose(sub.cancel);
    unawaited(
      repo.fetchUnlocked().then((owned) => _set(prefs, owned)).catchError((
        Object _,
      ) {
        // Offline: keep the cached value.
      }),
    );
    return prefs.getBool(_key) ?? false;
  }

  void _set(SharedPreferences prefs, bool owned) {
    unawaited(prefs.setBool(_key, owned));
    if (ref.mounted) state = owned;
  }

  /// Sets ownership after a purchase/restore result.
  void set({required bool owned}) =>
      _set(ref.read(sharedPreferencesProvider), owned);
}

final hasUnlockProvider = NotifierProvider<UnlockNotifier, bool>(
  UnlockNotifier.new,
);

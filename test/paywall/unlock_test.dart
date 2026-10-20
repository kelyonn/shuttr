import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuttr/features/paywall/entitlement_repository.dart';
import 'package:shuttr/features/settings/settings_repository.dart';

import '../support/fake_entitlements.dart';

void main() {
  Future<ProviderContainer> build(
    FakeEntitlementRepository repo, {
    Map<String, Object> prefsValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        entitlementRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts locked and stays locked with no purchase', () async {
    final container = await build(FakeEntitlementRepository());

    expect(container.read(hasUnlockProvider), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(hasUnlockProvider), isFalse);
  });

  test('a purchase unlocks and persists', () async {
    final repo = FakeEntitlementRepository();
    final container = await build(repo);
    container.read(hasUnlockProvider);

    final owned = await repo.purchase(
      const UnlockOffer(priceString: '₹399', package: null),
    );
    await Future<void>.delayed(Duration.zero);

    expect(owned, isTrue);
    expect(container.read(hasUnlockProvider), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hasUnlock'), isTrue);
  });

  test('offline keeps the cached unlock', () async {
    final container = await build(
      FakeEntitlementRepository(offline: true),
      prefsValues: {'hasUnlock': true},
    );

    expect(container.read(hasUnlockProvider), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(hasUnlockProvider), isTrue);
  });

  test('a refund from the store relocks', () async {
    final repo = FakeEntitlementRepository(owned: true);
    final container = await build(repo);
    container.read(hasUnlockProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(hasUnlockProvider), isTrue);

    repo.push(value: false);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(hasUnlockProvider), isFalse);
  });
}

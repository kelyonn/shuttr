import 'dart:async';

import 'package:shuttr/features/paywall/entitlement_repository.dart';

/// In-memory [EntitlementRepository] for tests.
class FakeEntitlementRepository implements EntitlementRepository {
  new({this.owned = false, this.offline = false});

  bool owned;
  bool offline;
  final _controller = StreamController<bool>.broadcast();

  @override
  bool get isConfigured => true;

  @override
  Stream<bool> get unlockedChanges => _controller.stream;

  @override
  Future<bool> fetchUnlocked() async {
    if (offline) throw Exception('offline');
    return owned;
  }

  @override
  Future<UnlockOffer?> loadOffer() async =>
      const UnlockOffer(priceString: '₹399', package: null);

  @override
  Future<bool> purchase(UnlockOffer offer) async {
    owned = true;
    _controller.add(true);
    return true;
  }

  @override
  Future<bool> restore() async => owned;

  /// Simulates the store pushing a change (e.g. a refund).
  void push({required bool value}) {
    owned = value;
    _controller.add(value);
  }
}

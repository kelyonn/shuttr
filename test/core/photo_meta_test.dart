import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/core/storage/photo_meta.dart';
import 'package:shuttr/features/looks/date_stamp.dart';

void main() {
  group('PhotoMeta', () {
    test('round-trips through JSON, including a date stamp', () {
      final meta = PhotoMeta(
        id: '123',
        lookId: 'digi03',
        lookVersion: 1,
        capturedAt: DateTime.utc(2003, 10, 28, 12),
        source: PhotoSource.capture,
        seed: 42.5,
        dateStamp: const DateStampSettings(
          enabled: true,
          format: DateStampFormat.isoDotted,
          yearOverride: 2003,
        ),
      );

      final decoded = PhotoMeta.fromJson(meta.toJson());

      expect(decoded.id, meta.id);
      expect(decoded.lookId, meta.lookId);
      expect(decoded.lookVersion, meta.lookVersion);
      expect(decoded.capturedAt, meta.capturedAt);
      expect(decoded.source, meta.source);
      expect(decoded.seed, meta.seed);
      expect(decoded.dateStamp?.format, DateStampFormat.isoDotted);
      expect(decoded.dateStamp?.yearOverride, 2003);
    });

    test('round-trips without a seed or date stamp', () {
      final meta = PhotoMeta(
        id: '456',
        lookId: 'disposable',
        lookVersion: 1,
        capturedAt: DateTime.utc(2026),
        source: PhotoSource.import,
      );

      final decoded = PhotoMeta.fromJson(meta.toJson());

      expect(decoded.seed, isNull);
      expect(decoded.dateStamp, isNull);
      expect(decoded.source, PhotoSource.import);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/features/looks/date_stamp.dart';

void main() {
  group('formatDateStamp', () {
    final date = DateTime(2026, 3, 7);

    test('yyMmDd', () {
      final s = formatDateStamp(
        date,
        const DateStampSettings(enabled: true),
      );
      expect(s, "'26 03 07");
    });

    test('isoDotted', () {
      final s = formatDateStamp(
        date,
        const DateStampSettings(
          enabled: true,
          format: DateStampFormat.isoDotted,
        ),
      );
      expect(s, '2026.03.07');
    });

    test('mmDdYy', () {
      final s = formatDateStamp(
        date,
        const DateStampSettings(
          enabled: true,
          format: DateStampFormat.mmDdYy,
        ),
      );
      expect(s, "03 07 '26");
    });

    test('yearOverride replaces the capture year', () {
      final s = formatDateStamp(
        date,
        const DateStampSettings(enabled: true, yearOverride: 2003),
      );
      expect(s, "'03 03 07");
    });

    test('single-digit month/day are zero-padded', () {
      final s = formatDateStamp(
        DateTime(2026, 1, 5),
        const DateStampSettings(enabled: true),
      );
      expect(s, "'26 01 05");
    });
  });
}

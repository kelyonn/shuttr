
import 'package:flutter/material.dart';

/// docs/LOOKS.md "Date stamp styles".
enum DateStampFormat {
  yyMmDd, // '03 10 28
  isoDotted, // 2003.10.28
  mmDdYy, // 10 28 '03
}

enum DateStampPosition { bottomRight, bottomLeft, topRight }

enum DateStampColorStyle { orange, yellow, white }

extension DateStampColorStyleColor on DateStampColorStyle {
  Color get color => switch (this) {
        DateStampColorStyle.orange => const Color(0xFFFF8A00),
        DateStampColorStyle.yellow => const Color(0xFFF5D90A),
        DateStampColorStyle.white => const Color(0xFFF5F5F5),
      };
}

@immutable
class DateStampSettings {
  const new({
    required this.enabled,
    this.format = DateStampFormat.yyMmDd,
    this.position = DateStampPosition.bottomRight,
    this.colorStyle = DateStampColorStyle.orange,
    this.yearOverride,
  });

  final bool enabled;
  final DateStampFormat format;
  final DateStampPosition position;
  final DateStampColorStyle colorStyle;

  /// When set, replaces the actual capture year in the rendered stamp
  /// (docs/LOOKS.md "custom date year" — an authenticity control users can
  /// set in Settings, not a way to falsify EXIF/metadata).
  final int? yearOverride;
}

/// Formats `date` per `settings.format`, substituting
/// `settings.yearOverride` for the year when set. Pure logic, no
/// rendering — unit-tested in test/looks/date_stamp_test.dart.
String formatDateStamp(DateTime date, DateStampSettings settings) {
  final year = settings.yearOverride ?? date.year;
  final yy = (year % 100).toString().padLeft(2, '0');
  final yyyy = year.toString().padLeft(4, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');

  return switch (settings.format) {
    DateStampFormat.yyMmDd => "'$yy $mm $dd",
    DateStampFormat.isoDotted => '$yyyy.$mm.$dd',
    DateStampFormat.mmDdYy => "$mm $dd '$yy",
  };
}

/// Paints the date stamp onto `canvas` within `imageSize`, burned-in style
/// (a soft glow via MaskFilter, composited after the look shader so it
/// isn't colour-graded). Positioning matches `settings.position` with a
/// margin proportional to the image size.
///
/// Uses the default font for now — the real DSEG7 7-segment font asset is
/// added in S8 (docs/BUILD_PLAN.md; see assets/fonts/.gitkeep and
/// docs/DECISIONS.md D-025). Swap the TextStyle's fontFamily once
/// assets/fonts/DSEG7Classic-Regular.ttf exists and is declared in
/// pubspec.yaml.
void paintDateStamp(
  Canvas canvas,
  Size imageSize,
  DateTime date,
  DateStampSettings settings,
) {
  if (!settings.enabled) return;

  final text = formatDateStamp(date, settings);
  final fontSize = imageSize.shortestSide * 0.035;
  final glowColor = settings.colorStyle.color;

  final textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: glowColor,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        shadows: [
          Shadow(
            color: glowColor.withValues(alpha: 0.8),
            blurRadius: fontSize * 0.3,
          ),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final margin = imageSize.shortestSide * 0.04;
  final offset = switch (settings.position) {
    DateStampPosition.bottomRight => Offset(
        imageSize.width - textPainter.width - margin,
        imageSize.height - textPainter.height - margin,
      ),
    DateStampPosition.bottomLeft => Offset(
        margin,
        imageSize.height - textPainter.height - margin,
      ),
    DateStampPosition.topRight => Offset(
        imageSize.width - textPainter.width - margin,
        margin,
      ),
  };

  textPainter.paint(canvas, offset);
}

import 'package:shuttr/features/looks/date_stamp.dart';

/// Where a stored photo came from — the in-app gallery (S18) and photo
/// dump (S20) both read this, and import (S19) is what sets `import`.
enum PhotoSource { capture, import }

/// The `meta/<id>.json` sidecar for one stored photo (docs/ARCHITECTURE.md
/// "Storage"): everything needed to show it in the gallery and re-develop
/// it against a different look later, without re-decoding the rendered
/// JPEG to recover parameters that only ever lived in the LookSpec used at
/// capture time.
class PhotoMeta {
  const new({
    required this.id,
    required this.lookId,
    required this.lookVersion,
    required this.capturedAt,
    required this.source,
    this.seed,
    this.dateStamp,
  });

  factory fromJson(Map<String, dynamic> json) => PhotoMeta(
    id: json['id'] as String,
    lookId: json['lookId'] as String,
    lookVersion: json['lookVersion'] as int,
    capturedAt: DateTime.parse(json['capturedAt'] as String),
    source: PhotoSource.values.byName(json['source'] as String),
    seed: (json['seed'] as num?)?.toDouble(),
    dateStamp: json['dateStamp'] == null
        ? null
        : DateStampSettings.fromJson(
            json['dateStamp'] as Map<String, dynamic>,
          ),
  );

  final String id;
  final String lookId;
  final int lookVersion;
  final DateTime capturedAt;
  final PhotoSource source;

  /// The seed `LookRenderer` used for grain/light-leak randomisation, so
  /// re-rendering (re-develop, or a golden test) can reproduce it exactly.
  final double? seed;
  final DateStampSettings? dateStamp;

  Map<String, dynamic> toJson() => {
    'id': id,
    'lookId': lookId,
    'lookVersion': lookVersion,
    'capturedAt': capturedAt.toIso8601String(),
    'source': source.name,
    if (seed != null) 'seed': seed,
    if (dateStamp != null) 'dateStamp': dateStamp!.toJson(),
  };
}

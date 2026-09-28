/// A camera "look" as data, not code — one shared render pipeline consumes
/// any [LookSpec]. See docs/LOOKS.md for the param spec and
/// docs/ARCHITECTURE.md D-030 (JSON-serializable so looks can later be
/// downloaded, not just bundled).
class LookSpec {
  const new({
    required this.id,
    required this.version,
    required this.displayName,
    required this.isFree,
    required this.aspectWidth,
    required this.aspectHeight,
    required this.outputLongEdge,
    required this.jpegQuality,
    this.lutAsset,
    this.frameAsset,
    this.dateStampDefaultOn = false,
    // Flash
    this.flashStrength = 0,
    this.flashRadius = 0.6,
    this.flashFalloff = 2.0,
    // Tone
    this.exposure = 0,
    this.contrast = 1,
    this.blackLift = 0,
    this.highlightClip = 1,
    // Colour
    this.lutStrength = 1,
    this.saturation = 1,
    // Highlights
    this.bloomThreshold = 0.8,
    this.bloomStrength = 0,
    this.halationStrength = 0,
    // Lens
    this.vignette = 0,
    this.chromaticAberration = 0,
    this.softness = 0,
    // Sensor / film
    this.grainAmount = 0,
    this.grainSize = 1,
    this.chromaNoise = 0,
    // Processing
    this.sharpenAmount = 0,
    // Overlays
    this.lightLeakStrength = 0,
  });

  factory fromJson(Map<String, dynamic> json) {
    return LookSpec(
      id: json['id'] as String,
      version: json['version'] as int,
      displayName: json['displayName'] as String,
      isFree: json['isFree'] as bool,
      aspectWidth: (json['aspectWidth'] as num).toDouble(),
      aspectHeight: (json['aspectHeight'] as num).toDouble(),
      outputLongEdge: json['outputLongEdge'] as int,
      jpegQuality: json['jpegQuality'] as int,
      lutAsset: json['lutAsset'] as String?,
      frameAsset: json['frameAsset'] as String?,
      dateStampDefaultOn: json['dateStampDefaultOn'] as bool? ?? false,
      flashStrength: (json['flashStrength'] as num?)?.toDouble() ?? 0,
      flashRadius: (json['flashRadius'] as num?)?.toDouble() ?? 0.6,
      flashFalloff: (json['flashFalloff'] as num?)?.toDouble() ?? 2.0,
      exposure: (json['exposure'] as num?)?.toDouble() ?? 0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 1,
      blackLift: (json['blackLift'] as num?)?.toDouble() ?? 0,
      highlightClip: (json['highlightClip'] as num?)?.toDouble() ?? 1,
      lutStrength: (json['lutStrength'] as num?)?.toDouble() ?? 1,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 1,
      bloomThreshold: (json['bloomThreshold'] as num?)?.toDouble() ?? 0.8,
      bloomStrength: (json['bloomStrength'] as num?)?.toDouble() ?? 0,
      halationStrength: (json['halationStrength'] as num?)?.toDouble() ?? 0,
      vignette: (json['vignette'] as num?)?.toDouble() ?? 0,
      chromaticAberration:
          (json['chromaticAberration'] as num?)?.toDouble() ?? 0,
      softness: (json['softness'] as num?)?.toDouble() ?? 0,
      grainAmount: (json['grainAmount'] as num?)?.toDouble() ?? 0,
      grainSize: (json['grainSize'] as num?)?.toDouble() ?? 1,
      chromaNoise: (json['chromaNoise'] as num?)?.toDouble() ?? 0,
      sharpenAmount: (json['sharpenAmount'] as num?)?.toDouble() ?? 0,
      lightLeakStrength: (json['lightLeakStrength'] as num?)?.toDouble() ?? 0,
    );
  }

  // Identity
  final String id;
  final int version;
  final String displayName;
  final bool isFree;

  // Geometry / output
  final double aspectWidth;
  final double aspectHeight;
  final int outputLongEdge;
  final int jpegQuality;
  final String? lutAsset;
  final String? frameAsset;
  final bool dateStampDefaultOn;

  // Flash
  final double flashStrength;
  final double flashRadius;
  final double flashFalloff;

  // Tone
  final double exposure;
  final double contrast;
  final double blackLift;
  final double highlightClip;

  // Colour
  final double lutStrength;
  final double saturation;

  // Highlights
  final double bloomThreshold;
  final double bloomStrength;
  final double halationStrength;

  // Lens
  final double vignette;
  final double chromaticAberration;
  final double softness;

  // Sensor / film
  final double grainAmount;
  final double grainSize;
  final double chromaNoise;

  // Processing
  final double sharpenAmount;

  // Overlays
  final double lightLeakStrength;

  double get aspectRatio => aspectWidth / aspectHeight;

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'displayName': displayName,
        'isFree': isFree,
        'aspectWidth': aspectWidth,
        'aspectHeight': aspectHeight,
        'outputLongEdge': outputLongEdge,
        'jpegQuality': jpegQuality,
        if (lutAsset != null) 'lutAsset': lutAsset,
        if (frameAsset != null) 'frameAsset': frameAsset,
        'dateStampDefaultOn': dateStampDefaultOn,
        'flashStrength': flashStrength,
        'flashRadius': flashRadius,
        'flashFalloff': flashFalloff,
        'exposure': exposure,
        'contrast': contrast,
        'blackLift': blackLift,
        'highlightClip': highlightClip,
        'lutStrength': lutStrength,
        'saturation': saturation,
        'bloomThreshold': bloomThreshold,
        'bloomStrength': bloomStrength,
        'halationStrength': halationStrength,
        'vignette': vignette,
        'chromaticAberration': chromaticAberration,
        'softness': softness,
        'grainAmount': grainAmount,
        'grainSize': grainSize,
        'chromaNoise': chromaNoise,
        'sharpenAmount': sharpenAmount,
        'lightLeakStrength': lightLeakStrength,
      };

  LookSpec copyWith({
    double? flashStrength,
    double? flashRadius,
    double? flashFalloff,
    double? exposure,
    double? contrast,
    double? blackLift,
    double? highlightClip,
    double? lutStrength,
    double? saturation,
    double? bloomThreshold,
    double? bloomStrength,
    double? halationStrength,
    double? vignette,
    double? chromaticAberration,
    double? softness,
    double? grainAmount,
    double? grainSize,
    double? chromaNoise,
    double? sharpenAmount,
    double? lightLeakStrength,
  }) {
    return LookSpec(
      id: id,
      version: version,
      displayName: displayName,
      isFree: isFree,
      aspectWidth: aspectWidth,
      aspectHeight: aspectHeight,
      outputLongEdge: outputLongEdge,
      jpegQuality: jpegQuality,
      lutAsset: lutAsset,
      frameAsset: frameAsset,
      dateStampDefaultOn: dateStampDefaultOn,
      flashStrength: flashStrength ?? this.flashStrength,
      flashRadius: flashRadius ?? this.flashRadius,
      flashFalloff: flashFalloff ?? this.flashFalloff,
      exposure: exposure ?? this.exposure,
      contrast: contrast ?? this.contrast,
      blackLift: blackLift ?? this.blackLift,
      highlightClip: highlightClip ?? this.highlightClip,
      lutStrength: lutStrength ?? this.lutStrength,
      saturation: saturation ?? this.saturation,
      bloomThreshold: bloomThreshold ?? this.bloomThreshold,
      bloomStrength: bloomStrength ?? this.bloomStrength,
      halationStrength: halationStrength ?? this.halationStrength,
      vignette: vignette ?? this.vignette,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      softness: softness ?? this.softness,
      grainAmount: grainAmount ?? this.grainAmount,
      grainSize: grainSize ?? this.grainSize,
      chromaNoise: chromaNoise ?? this.chromaNoise,
      sharpenAmount: sharpenAmount ?? this.sharpenAmount,
      lightLeakStrength: lightLeakStrength ?? this.lightLeakStrength,
    );
  }
}

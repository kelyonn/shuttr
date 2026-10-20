/// Pre-launch switch: every camera is free and nothing is gated. `isFree`
/// on each spec is kept as the intended launch tier, so re-enabling the
/// paywall later is flipping this to false (D-040).
const kAllLooksFree = true;

/// What the live viewfinder looks like in "authentic" viewfinder mode.
/// `lcd`: a small low-res colour LCD (digicams, phones). `optical`: a
/// through-the-window finder with frame lines (film cameras). `clean`: the
/// plain graded preview, never pixelated or dimmed (Digi '03, D-046).
enum ViewfinderKind { lcd, optical, clean }

/// The kind of shutter/advance a camera has; drives its haptics (and its
/// sounds, if they come back: tool/sounds/gen_sounds.py).
enum SoundSet { digicam, disposable, instant, film, phone }

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
    this.flashWarmth = 0,
    // Tone
    this.exposure = 0,
    this.previewExposure = 0,
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
    // Phone-to-camera character (de-HDR, white balance, sensor/JPEG damage)
    this.hdrUndo = 0,
    this.shadowCrush = 0,
    this.highlightBlow = 0,
    this.noiseSize = 1,
    this.developDenoise = 0.9,
    this.awbBias = 0,
    this.flashAmbientDrop = 0.45,
    this.glow = 0,
    this.jpegPreQuality = 0,
    this.sensorLongEdge = 0,
    // Overlays
    this.lightLeakStrength = 0,
    this.lightLeakChance = 0.35,
    this.dustAmount = 0,
    // Camera character (beyond the image pipeline)
    this.ccdSmear = 0,
    this.flashShadow = 0,
    this.redEyeChance = 0,
    this.developSeconds = 0,
    this.viewfinder = ViewfinderKind.optical,
    this.soundSet = SoundSet.film,
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
      flashWarmth: (json['flashWarmth'] as num?)?.toDouble() ?? 0,
      exposure: (json['exposure'] as num?)?.toDouble() ?? 0,
      previewExposure: (json['previewExposure'] as num?)?.toDouble() ?? 0,
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
      hdrUndo: (json['hdrUndo'] as num?)?.toDouble() ?? 0,
      shadowCrush: (json['shadowCrush'] as num?)?.toDouble() ?? 0,
      highlightBlow: (json['highlightBlow'] as num?)?.toDouble() ?? 0,
      noiseSize: (json['noiseSize'] as num?)?.toDouble() ?? 1,
      developDenoise: (json['developDenoise'] as num?)?.toDouble() ?? 0.9,
      awbBias: (json['awbBias'] as num?)?.toDouble() ?? 0,
      flashAmbientDrop: (json['flashAmbientDrop'] as num?)?.toDouble() ?? 0.45,
      glow: (json['glow'] as num?)?.toDouble() ?? 0,
      jpegPreQuality: json['jpegPreQuality'] as int? ?? 0,
      sensorLongEdge: json['sensorLongEdge'] as int? ?? 0,
      lightLeakStrength: (json['lightLeakStrength'] as num?)?.toDouble() ?? 0,
      lightLeakChance: (json['lightLeakChance'] as num?)?.toDouble() ?? 0.35,
      dustAmount: (json['dustAmount'] as num?)?.toDouble() ?? 0,
      ccdSmear: (json['ccdSmear'] as num?)?.toDouble() ?? 0,
      flashShadow: (json['flashShadow'] as num?)?.toDouble() ?? 0,
      redEyeChance: (json['redEyeChance'] as num?)?.toDouble() ?? 0,
      developSeconds: json['developSeconds'] as int? ?? 0,
      viewfinder:
          ViewfinderKind.values.asNameMap()[json['viewfinder']] ??
          ViewfinderKind.optical,
      soundSet: SoundSet.values.asNameMap()[json['soundSet']] ?? SoundSet.film,
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

  /// -1 (cool xenon) … +1 (warm). Tints the flash light itself.
  final double flashWarmth;

  // Tone
  final double exposure;

  /// Extra stops added to the live viewfinder only, so a camera's screen can
  /// read brighter than the print it will save.
  final double previewExposure;
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

  // Phone-to-camera character
  /// 0-1. Re-expands large-scale brightness so a phone's tone-mapped HDR
  /// frame gets a small sensor's blown skies and sunk shadows back.
  final double hdrUndo;

  /// 0-0.3. Black point: everything below it goes to pure black.
  final double shadowCrush;

  /// 0-0.3. White point pulled down: skies and skin clip to pure white.
  final double highlightBlow;

  /// Clump size (px at 2400 wide) of the sensor chroma noise.
  final double noiseSize;

  /// 0-1. How much of the phone's own noise the develop stage removes.
  final double developDenoise;

  /// 0-1. Amplifies the scene's colour cast (a cheap camera's auto white
  /// balance never fully corrected tungsten or shade).
  final double awbBias;

  /// 0-1. How much the room goes dark behind a lit subject at full flash.
  final double flashAmbientDrop;

  /// 0-1. Whole-frame veiling glare: a wide blur screen-blended over the
  /// picture, so everything glows softly and the blacks lift (cheap lens
  /// with no coating, shot into the light).
  final double glow;

  /// 0 = off. Otherwise the shot is round-tripped through a JPEG at this
  /// quality at [sensorLongEdge] first, for real blocking and chroma smear.
  final int jpegPreQuality;

  /// Long edge of the simulated sensor for the JPEG round trip.
  final int sensorLongEdge;

  // Overlays
  final double lightLeakStrength;

  /// Probability (0-1) that a given shot gets a leak at all; which leak and
  /// its orientation come from the stored seed, so re-develop is stable.
  final double lightLeakChance;

  /// Dust specks on the scan, 0-1.
  final double dustAmount;

  // Camera character

  /// CCD vertical smear: a bright light bleeds a vertical streak through the
  /// whole column (a real interline-CCD readout artefact). 0-1.
  final double ccdSmear;

  /// Hard shadow cast behind the subject by an off-axis on-camera flash.
  final double flashShadow;

  /// Chance (0-1) that a flash shot with a detected face gets red-eye.
  final double redEyeChance;

  /// Instant prints fade up from blank over this many seconds after the
  /// shot. 0 = shown immediately.
  final int developSeconds;
  final ViewfinderKind viewfinder;
  final SoundSet soundSet;

  double get aspectRatio => aspectWidth / aspectHeight;

  /// Whether keeping a shot from this look needs the unlock right now.
  /// Use this for gating/UI, not [isFree] (which is the launch tier).
  bool get isLocked => !kAllLooksFree && !isFree;

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
    'flashWarmth': flashWarmth,
    'exposure': exposure,
    'previewExposure': previewExposure,
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
    'hdrUndo': hdrUndo,
    'shadowCrush': shadowCrush,
    'highlightBlow': highlightBlow,
    'noiseSize': noiseSize,
    'developDenoise': developDenoise,
    'awbBias': awbBias,
    'flashAmbientDrop': flashAmbientDrop,
    'glow': glow,
    'jpegPreQuality': jpegPreQuality,
    'sensorLongEdge': sensorLongEdge,
    'lightLeakStrength': lightLeakStrength,
    'lightLeakChance': lightLeakChance,
    'dustAmount': dustAmount,
  };

  LookSpec copyWith({
    int? outputLongEdge,
    double? flashStrength,
    double? flashRadius,
    double? flashFalloff,
    double? flashWarmth,
    double? exposure,
    double? previewExposure,
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
    double? lightLeakChance,
    double? dustAmount,
    double? ccdSmear,
    double? flashShadow,
    double? hdrUndo,
    double? shadowCrush,
    double? highlightBlow,
    double? noiseSize,
    double? developDenoise,
    double? awbBias,
    double? flashAmbientDrop,
    double? glow,
    int? jpegPreQuality,
    int? sensorLongEdge,
  }) {
    return LookSpec(
      id: id,
      version: version,
      displayName: displayName,
      isFree: isFree,
      aspectWidth: aspectWidth,
      aspectHeight: aspectHeight,
      outputLongEdge: outputLongEdge ?? this.outputLongEdge,
      jpegQuality: jpegQuality,
      lutAsset: lutAsset,
      frameAsset: frameAsset,
      dateStampDefaultOn: dateStampDefaultOn,
      flashStrength: flashStrength ?? this.flashStrength,
      flashRadius: flashRadius ?? this.flashRadius,
      flashFalloff: flashFalloff ?? this.flashFalloff,
      flashWarmth: flashWarmth ?? this.flashWarmth,
      exposure: exposure ?? this.exposure,
      previewExposure: previewExposure ?? this.previewExposure,
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
      lightLeakChance: lightLeakChance ?? this.lightLeakChance,
      dustAmount: dustAmount ?? this.dustAmount,
      ccdSmear: ccdSmear ?? this.ccdSmear,
      flashShadow: flashShadow ?? this.flashShadow,
      hdrUndo: hdrUndo ?? this.hdrUndo,
      shadowCrush: shadowCrush ?? this.shadowCrush,
      highlightBlow: highlightBlow ?? this.highlightBlow,
      noiseSize: noiseSize ?? this.noiseSize,
      developDenoise: developDenoise ?? this.developDenoise,
      awbBias: awbBias ?? this.awbBias,
      flashAmbientDrop: flashAmbientDrop ?? this.flashAmbientDrop,
      glow: glow ?? this.glow,
      jpegPreQuality: jpegPreQuality ?? this.jpegPreQuality,
      sensorLongEdge: sensorLongEdge ?? this.sensorLongEdge,
      redEyeChance: redEyeChance,
      developSeconds: developSeconds,
      viewfinder: viewfinder,
      soundSet: soundSet,
    );
  }
}

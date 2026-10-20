import 'package:shuttr/features/looks/look_spec.dart';

/// On-screen display burnt into the tape, like the camcorder drew it.
enum VideoOsd { none, vhs, camcorder, minidv, nightVision }

/// A camcorder/film "look" for video, as data (D-030: JSON-serialisable,
/// same idea as [LookSpec]). The native pipeline (VideoPlugin.kt) reads
/// [toJson] and runs `video_look.glsl` over every frame after recording;
/// nothing heavy happens while you record (CLAUDE.md rule 2).
class VideoLook {
  const new({
    required this.id,
    required this.displayName,
    required this.outputWidth,
    required this.outputHeight,
    required this.bitrateKbps,
    this.fps,
    this.lutAsset,
    this.osd = VideoOsd.none,
    this.exposure = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.blackLift = 0,
    this.vignette = 0,
    this.lumaBlur = 0,
    this.chromaBlur = 0,
    this.chromaShift = 0,
    this.sharpen = 0,
    this.noise = 0,
    this.chromaNoise = 0,
    this.grain = 0,
    this.lineJitter = 0,
    this.tracking = 0,
    this.headSwitch = 0,
    this.interlace = 0,
    this.gateWeave = 0,
    this.flicker = 0,
    this.dust = 0,
    this.gateMask = 0,
    this.wobble = 0,
    this.nightVision = 0,
    this.hiss = 0,
    this.lowpassHz = 20000,
    this.highpassHz = 20,
    this.drive = 0,
    this.crush = 0,
    this.wow = 0,
    this.projector = 0,
    this.mono = false,
  });

  factory fromJson(Map<String, dynamic> j) {
    double d(String k, double fallback) =>
        (j[k] as num?)?.toDouble() ?? fallback;
    return VideoLook(
      id: j['id'] as String,
      displayName: j['displayName'] as String,
      outputWidth: j['outputWidth'] as int,
      outputHeight: j['outputHeight'] as int,
      bitrateKbps: j['bitrateKbps'] as int,
      fps: (j['fps'] as num?)?.toDouble(),
      lutAsset: j['lutAsset'] as String?,
      osd: VideoOsd.values.asNameMap()[j['osd']] ?? VideoOsd.none,
      exposure: d('exposure', 0),
      contrast: d('contrast', 1),
      saturation: d('saturation', 1),
      blackLift: d('blackLift', 0),
      vignette: d('vignette', 0),
      lumaBlur: d('lumaBlur', 0),
      chromaBlur: d('chromaBlur', 0),
      chromaShift: d('chromaShift', 0),
      sharpen: d('sharpen', 0),
      noise: d('noise', 0),
      chromaNoise: d('chromaNoise', 0),
      grain: d('grain', 0),
      lineJitter: d('lineJitter', 0),
      tracking: d('tracking', 0),
      headSwitch: d('headSwitch', 0),
      interlace: d('interlace', 0),
      gateWeave: d('gateWeave', 0),
      flicker: d('flicker', 0),
      dust: d('dust', 0),
      gateMask: d('gateMask', 0),
      wobble: d('wobble', 0),
      nightVision: d('nightVision', 0),
      hiss: d('hiss', 0),
      lowpassHz: d('lowpassHz', 20000),
      highpassHz: d('highpassHz', 20),
      drive: d('drive', 0),
      crush: d('crush', 0),
      wow: d('wow', 0),
      projector: d('projector', 0),
      mono: j['mono'] as bool? ?? false,
    );
  }

  final String id;
  final String displayName;

  // Output
  final int outputWidth;
  final int outputHeight;

  /// Encoder bitrate. Low values give real compression blocking for free.
  final int bitrateKbps;

  /// Frame rate to drop to (Super 8 ran at 18); null keeps the recording's.
  final double? fps;
  final String? lutAsset;
  final VideoOsd osd;

  // Picture (all 0-1 unless noted; see video_look.glsl)
  final double exposure;
  final double contrast;
  final double saturation;
  final double blackLift;
  final double vignette;

  /// Horizontal luma smear in output px (tape bandwidth).
  final double lumaBlur;

  /// Horizontal chroma smear in output px (VHS colour is ~40 lines wide).
  final double chromaBlur;

  /// Colour sits this many px right of the picture (chroma delay).
  final double chromaShift;

  /// Camcorder edge enhancement: bright halos along edges.
  final double sharpen;
  final double noise;
  final double chromaNoise;
  final double grain;
  final double lineJitter;
  final double tracking;
  final double headSwitch;
  final double interlace;
  final double gateWeave;
  final double flicker;
  final double dust;

  /// Rounded, dark projector-gate corners.
  final double gateMask;

  /// Rolling-shutter jello of a cheap CMOS sensor.
  final double wobble;

  /// 1 = green infrared night-vision picture.
  final double nightVision;

  // Sound
  final double hiss;
  final double lowpassHz;
  final double highpassHz;
  final double drive;

  /// Bit-crush 0-1 (0 = full 16-bit).
  final double crush;

  /// Tape wow & flutter: slow pitch wobble.
  final double wow;

  /// Projector clatter under the soundtrack.
  final double projector;
  final bool mono;

  double get aspectRatio => outputWidth / outputHeight;

  /// A [LookSpec] stand-in so the live viewfinder can reuse the cheap photo
  /// preview shader (colour, tone, vignette) while recording.
  LookSpec get previewLook => LookSpec(
    id: 'video_$id',
    version: 1,
    displayName: displayName,
    isFree: true,
    aspectWidth: outputWidth.toDouble(),
    aspectHeight: outputHeight.toDouble(),
    outputLongEdge: outputWidth,
    jpegQuality: 90,
    lutAsset: lutAsset,
    exposure: exposure,
    contrast: contrast,
    saturation: nightVision > 0 ? 0 : saturation,
    vignette: vignette,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'outputWidth': outputWidth,
    'outputHeight': outputHeight,
    'bitrateKbps': bitrateKbps,
    if (fps != null) 'fps': fps,
    if (lutAsset != null) 'lutAsset': lutAsset,
    'osd': osd.name,
    'exposure': exposure,
    'contrast': contrast,
    'saturation': saturation,
    'blackLift': blackLift,
    'vignette': vignette,
    'lumaBlur': lumaBlur,
    'chromaBlur': chromaBlur,
    'chromaShift': chromaShift,
    'sharpen': sharpen,
    'noise': noise,
    'chromaNoise': chromaNoise,
    'grain': grain,
    'lineJitter': lineJitter,
    'tracking': tracking,
    'headSwitch': headSwitch,
    'interlace': interlace,
    'gateWeave': gateWeave,
    'flicker': flicker,
    'dust': dust,
    'gateMask': gateMask,
    'wobble': wobble,
    'nightVision': nightVision,
    'hiss': hiss,
    'lowpassHz': lowpassHz,
    'highpassHz': highpassHz,
    'drive': drive,
    'crush': crush,
    'wow': wow,
    'projector': projector,
    'mono': mono,
  };
}

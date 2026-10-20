import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/video/video_look.dart';

// STARTING VALUES ONLY, built from how each format is documented to look
// and sound (docs/LOOKS.md "v2 video looks"). Tune against real tape/film
// transfers before calling any of them final.

/// Home-video VHS camcorder, played back off the tape: soft 240-line luma,
/// colour smeared and late, tracking noise, head-switching tear at the
/// bottom, hiss and wow on the sound.
const vhsLook = VideoLook(
  id: 'vhs',
  displayName: 'VHS',
  outputWidth: 640,
  outputHeight: 480,
  bitrateKbps: 5000,
  lutAsset: 'assets/luts/vhs.png',
  osd: VideoOsd.vhs,
  contrast: 1.05,
  saturation: 1.05,
  blackLift: 0.03,
  vignette: 0.1,
  lumaBlur: 0.9,
  chromaBlur: 4,
  chromaShift: 1.5,
  sharpen: 0.3,
  noise: 0.02,
  chromaNoise: 0.02,
  lineJitter: 0.1,
  tracking: 0.12,
  headSwitch: 0.3,
  interlace: 0.15,
  hiss: 0.02,
  lowpassHz: 9000,
  highpassHz: 80,
  drive: 0.15,
  wow: 0.2,
  mono: true,
);

/// Hi8 camcorder: sharper and cleaner than VHS, still analogue, with the
/// red REC and tape counter burnt in.
const hi8Look = VideoLook(
  id: 'hi8',
  displayName: 'Hi8',
  outputWidth: 720,
  outputHeight: 540,
  bitrateKbps: 5000,
  lutAsset: 'assets/luts/hi8.png',
  osd: VideoOsd.camcorder,
  contrast: 1.08,
  saturation: 1.05,
  blackLift: 0.03,
  vignette: 0.12,
  lumaBlur: 0.5,
  chromaBlur: 2.5,
  chromaShift: 0.8,
  sharpen: 0.5,
  noise: 0.035,
  chromaNoise: 0.03,
  lineJitter: 0.06,
  tracking: 0.05,
  headSwitch: 0.15,
  interlace: 0.4,
  hiss: 0.03,
  lowpassHz: 12000,
  highpassHz: 60,
  drive: 0.2,
  wow: 0.2,
);

/// MiniDV: digital tape, crisp and a little cold, hard edge enhancement,
/// interlaced, blocky when things move fast.
const miniDvLook = VideoLook(
  id: 'minidv',
  displayName: 'MiniDV',
  outputWidth: 720,
  outputHeight: 540,
  bitrateKbps: 4000,
  lutAsset: 'assets/luts/minidv.png',
  osd: VideoOsd.minidv,
  contrast: 1.1,
  saturation: 1.05,
  vignette: 0.08,
  lumaBlur: 0.4,
  chromaBlur: 2,
  sharpen: 0.8,
  noise: 0.02,
  chromaNoise: 0.02,
  interlace: 0.6,
  lowpassHz: 15000,
  highpassHz: 100,
  crush: 0.15,
);

/// Digi '03 video clip mode: a 2000s pocket digicam's 640x480 movie mode.
/// Same CCD colour as the stills, crisp over-sharpened edges, visible
/// noise and heavy compression blocking, tinny mono mic.
const digi03VideoLook = VideoLook(
  id: 'digi03',
  displayName: "Digi '03",
  outputWidth: 640,
  outputHeight: 480,
  bitrateKbps: 2200,
  fps: 30,
  lutAsset: 'assets/luts/digi03.png',
  contrast: 1.1,
  saturation: 1.02,
  blackLift: 0.03,
  vignette: 0.1,
  lumaBlur: 0.6,
  chromaBlur: 1.5,
  sharpen: 0.5,
  noise: 0.045,
  chromaNoise: 0.05,
  lowpassHz: 9000,
  highpassHz: 200,
  drive: 0.2,
  crush: 0.2,
  mono: true,
);

/// Super 8 home movie: 18 fps, gate weave, projector flicker, dust and
/// scratches, warm faded reversal colour, rounded gate corners.
const super8Look = VideoLook(
  id: 'super8',
  displayName: 'Super 8',
  outputWidth: 720,
  outputHeight: 540,
  bitrateKbps: 6000,
  fps: 18,
  lutAsset: 'assets/luts/super8.png',
  exposure: 0.05,
  contrast: 1.1,
  saturation: 1.05,
  blackLift: 0.04,
  vignette: 0.45,
  lumaBlur: 0.8,
  grain: 0.12,
  gateWeave: 0.6,
  flicker: 0.5,
  dust: 0.6,
  gateMask: 0.7,
  hiss: 0.02,
  lowpassHz: 7000,
  highpassHz: 150,
  wow: 0.3,
  projector: 0.5,
  mono: true,
);

/// 2008 pocket flip camera: 720p but over-compressed, over-saturated,
/// rolling-shutter jello, tinny mic.
const flipLook = VideoLook(
  id: 'flip',
  displayName: 'Flip Cam',
  outputWidth: 1280,
  outputHeight: 720,
  bitrateKbps: 1800,
  fps: 30,
  lutAsset: 'assets/luts/flip.png',
  contrast: 1.12,
  saturation: 1.25,
  vignette: 0.1,
  lumaBlur: 0.5,
  sharpen: 0.4,
  noise: 0.03,
  chromaNoise: 0.04,
  wobble: 0.6,
  lowpassHz: 8000,
  highpassHz: 250,
  drive: 0.25,
  crush: 0.25,
  mono: true,
);

/// 2006 laptop webcam: 640x480 at 15 fps, smeary, blown window light,
/// green-ish tint, muddy compressed voice.
const webcamLook = VideoLook(
  id: 'webcam',
  displayName: "Webcam '06",
  outputWidth: 640,
  outputHeight: 480,
  bitrateKbps: 700,
  fps: 15,
  lutAsset: 'assets/luts/webcam.png',
  exposure: 0.15,
  contrast: 1.15,
  saturation: 0.9,
  blackLift: 0.03,
  vignette: 0.25,
  lumaBlur: 1.2,
  chromaBlur: 3,
  noise: 0.06,
  chromaNoise: 0.08,
  lowpassHz: 5000,
  highpassHz: 300,
  drive: 0.3,
  crush: 0.45,
  mono: true,
);

/// The three video looks shown in the app, in picker order.
const videoLooks = <VideoLook>[vhsLook, miniDvLook, digi03VideoLook];

/// Formats taken out of the picker for now (D-044). Kept so clips already
/// shot with them still play and re-develop.
const archivedVideoLooks = <VideoLook>[
  hi8Look,
  flipLook,
  webcamLook,
  super8Look,
];

VideoLook videoLookById(String id) => [
  ...videoLooks,
  ...archivedVideoLooks,
].firstWhere((l) => l.id == id, orElse: () => vhsLook);

/// The video looks as preview [LookSpec]s, for the shared camera picker.
final List<LookSpec> videoPreviewLooks = [
  for (final l in videoLooks) l.previewLook,
];

VideoLook videoLookForPreview(LookSpec preview) =>
    videoLookById(preview.id.replaceFirst('video_', ''));

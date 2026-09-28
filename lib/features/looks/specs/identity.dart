import 'package:shuttr/features/looks/look_spec.dart';

/// Neutral look: no grading, no effects. Used to validate the render
/// pipeline itself (S2–S4) before any real look is tuned.
const identityLook = LookSpec(
  id: 'identity',
  version: 1,
  displayName: 'Identity (debug)',
  isFree: true,
  aspectWidth: 4,
  aspectHeight: 3,
  outputLongEdge: 2272,
  jpegQuality: 92,
);

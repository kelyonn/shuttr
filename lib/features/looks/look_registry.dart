import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/specs/cine_800.dart';
import 'package:shuttr/features/looks/specs/digi03.dart';
import 'package:shuttr/features/looks/specs/disposable.dart';
import 'package:shuttr/features/looks/specs/instant.dart';
import 'package:shuttr/features/looks/specs/mono_400.dart';
import 'package:shuttr/features/looks/specs/point_and_shoot_35.dart';

/// The five photo cameras shown in the app, in picker order
/// (docs/LOOK_RESEARCH.md). All free pre-launch (`kAllLooksFree`).
final looks = <LookSpec>[
  digi03Look,
  disposableLook,
  instantLook,
  pointAndShoot35Look,
  cine800Look,
];

/// Cameras taken out of the picker for now (D-044). Specs, LUTs and cards
/// stay so photos already shot with them still open and re-develop, and
/// bringing one back is moving it into [looks].
final archivedLooks = <LookSpec>[mono400Look];

/// Finds a camera by id, including archived ones (old photos reference them).
LookSpec lookById(String id) =>
    [...looks, ...archivedLooks].firstWhere((l) => l.id == id);

/// Like [lookById] but null for an unknown id (old or hand-edited data).
LookSpec? lookByIdOrNull(String id) {
  for (final l in [...looks, ...archivedLooks]) {
    if (l.id == id) return l;
  }
  return null;
}

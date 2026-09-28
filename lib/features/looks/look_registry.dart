import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/specs/digi03.dart';
import 'package:shuttr/features/looks/specs/disposable.dart';
import 'package:shuttr/features/looks/specs/instant.dart';
import 'package:shuttr/features/looks/specs/point_and_shoot_35.dart';

/// The ordered list of v1 cameras (docs/PRODUCT.md, docs/LOOKS.md).
/// Order is the order they appear in the camera's mode picker.
final looks = <LookSpec>[
  digi03Look,
  disposableLook,
  instantLook,
  pointAndShoot35Look,
];

LookSpec lookById(String id) => looks.firstWhere((l) => l.id == id);

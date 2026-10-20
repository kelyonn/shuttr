import 'package:flutter/material.dart';

/// The one page transition used everywhere: the incoming screen fades up
/// and drifts in a few pixels while the outgoing one dims a touch, so moving
/// between screens feels like one object instead of hard cuts.
Widget shuttrTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondary,
  Widget child,
) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final dim = CurvedAnimation(parent: secondary, curve: Curves.easeOut);
  return FadeTransition(
    opacity: Tween<double>(begin: 1, end: 0.6).animate(dim),
    child: FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    ),
  );
}

const shuttrRouteIn = Duration(milliseconds: 320);
const shuttrRouteOut = Duration(milliseconds: 260);

/// Drop-in for `MaterialPageRoute` with the shared transition.
class ShuttrRoute<T> extends PageRouteBuilder<T> {
  new({required WidgetBuilder builder})
    : super(
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: shuttrTransition,
        transitionDuration: shuttrRouteIn,
        reverseTransitionDuration: shuttrRouteOut,
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/features/camera/body/look_mode_dial.dart';
import 'package:shuttr/features/looks/look_registry.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: child));

  testWidgets('shows every look and a lock icon on paid ones', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        LookModeDial(
          selected: looks.first,
          accentColor: Colors.pink,
          onSelect: (_) {},
        ),
      ),
    );

    for (final look in looks) {
      expect(find.text(look.displayName), findsOneWidget);
    }
    final lockIcons = tester.widgetList<Icon>(
      find.byIcon(Icons.lock_outline),
    );
    expect(lockIcons.length, looks.where((l) => !l.isFree).length);
  });

  testWidgets('tapping a look calls onSelect with it', (tester) async {
    var selected = looks.first;

    await tester.pumpWidget(
      wrap(
        LookModeDial(
          selected: looks.first,
          accentColor: Colors.pink,
          onSelect: (look) => selected = look,
        ),
      ),
    );

    await tester.tap(find.text(looks[1].displayName));
    await tester.pump();

    expect(selected.id, looks[1].id);
  });
}

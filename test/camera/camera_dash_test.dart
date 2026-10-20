import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/features/camera/body/camera_dash.dart';
import 'package:shuttr/features/looks/look_registry.dart';
import 'package:shuttr/features/looks/look_spec.dart';

void main() {
  // The dash lays out differently sideways; these exercise the upright one
  // (the default test window is landscape).
  void upright(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget dash({required bool open, ValueChanged<LookSpec>? onSelect}) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: CameraDash(
            spec: looks.first,
            pickerOpen: open,
            rollCount: 8,
            flashLabel: 'OFF',
            flashOn: false,
            lensLabel: 'REAR',
            busy: false,
            onTogglePicker: () {},
            onSelectLook: onSelect ?? (_) {},
            onShutter: () {},
            onRoll: () {},
            onFlash: () {},
            onLens: () {},
            onIndex: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('closed picker shows the selected camera, no list', (
    tester,
  ) async {
    upright(tester);
    await tester.pumpWidget(dash(open: false));

    expect(find.text('OPEN +'), findsOneWidget);
    expect(find.text('Disposable'), findsNothing);
    expect(find.text('DIGI'), findsOneWidget);
    expect(find.text('FREE'), findsNothing);
    expect(find.text('SHOOT'), findsOneWidget);
  });

  testWidgets('open picker lists every camera, LOCK only on locked ones', (
    tester,
  ) async {
    upright(tester);
    await tester.pumpWidget(dash(open: true));

    expect(find.text('CLOSE −'), findsOneWidget);
    expect(
      find.text('LOCK'),
      findsNWidgets(looks.where((l) => l.isLocked).length),
    );
    expect(find.text('Disposable'), findsOneWidget);
  });

  testWidgets('tapping a camera selects it', (tester) async {
    upright(tester);
    LookSpec? picked;
    await tester.pumpWidget(dash(open: true, onSelect: (l) => picked = l));

    await tester.tap(find.text('Instant'));

    expect(picked?.id, 'instant');
  });
}

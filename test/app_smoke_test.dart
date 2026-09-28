import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/app/app.dart';

void main() {
  testWidgets('app boots to the camera placeholder route', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShuttrApp()));
    await tester.pumpAndSettle();

    expect(find.text('Camera'), findsOneWidget);
  });
}

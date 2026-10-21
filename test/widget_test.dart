import 'package:flutter_test/flutter_test.dart';

import 'package:adaptive_focus_studio/main.dart';

void main() {
  testWidgets('app starts', (tester) async {
    await tester.pumpWidget(const FocusApp());
    expect(find.text('Adaptive Focus Studio'), findsOneWidget);
  });
}

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:xnz_net_cache_image_example/main.dart';

void main() {
  testWidgets('Demo app renders key sections', (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pump();

    expect(find.text('XnzNetCacheImage Demo'), findsOneWidget);
    expect(find.text('Image URL'), findsOneWidget);
    expect(find.text('Custom Placeholder & Error'), findsOneWidget);
  });
}

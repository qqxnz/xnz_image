import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xnz_image_example/main.dart';

void main() {
  testWidgets('Demo app renders key sections', (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pump();

    expect(find.text('XnzNetCacheImage Demo'), findsOneWidget);
    expect(find.text('XNZNetworkImage'), findsOneWidget);
    expect(find.text('Image + XNZNetworkImageProvider'), findsOneWidget);
    expect(find.byType(Card), findsAtLeastNWidgets(2));
  });
}

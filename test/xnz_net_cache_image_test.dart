import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xnz_net_cache_image/xnz_net_cache_image.dart';

void main() {
  testWidgets('XnzNetCacheImage renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: XNZNetworkImage(imageUrl:  'https://picsum.photos/400/240',
            width: 200,
            height: 120,
          ),
        ),
      ),
    );

    expect(find.byType(XNZNetworkImage), findsOneWidget);
    expect(find.byType(XNZNetworkImage), findsOneWidget);
  });
}

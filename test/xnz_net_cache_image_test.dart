import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xnz_image/xnz_image.dart';

class _TestAssetBundle extends CachingAssetBundle {
  _TestAssetBundle(this._bytes);

  final Uint8List _bytes;

  @override
  Future<ByteData> load(String key) async {
    return ByteData.view(_bytes.buffer);
  }
}

void main() {
  testWidgets('XnzNetCacheImage renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: XNZNetworkImage(
            imageUrl: 'https://picsum.photos/400/240',
            width: 200,
            height: 120,
          ),
        ),
      ),
    );

    expect(find.byType(XNZNetworkImage), findsOneWidget);
  });

  testWidgets('XNZMemoryImage renders from bytes', (tester) async {
    final Uint8List pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: XNZMemoryImage(
            bytes: pngBytes,
            width: 20,
            height: 20,
          ),
        ),
      ),
    );

    expect(find.byType(XNZMemoryImage), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('XNZAssetImage renders from bundle', (tester) async {
    final Uint8List pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
    );
    final bundle = _TestAssetBundle(pngBytes);

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: bundle,
          child: Scaffold(
            body: XNZAssetImage(
              assetName: 'assets/fake.png',
              bundle: bundle,
              width: 20,
              height: 20,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(XNZAssetImage), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  test(
      'XNZNetworkImageProvider equality includes scale and avifOverrideDurationMs',
      () {
    final a = XNZNetworkImageProvider(
      'https://example.com/a.avif',
      scale: 1.0,
      avifOverrideDurationMs: -1,
    );
    final b = XNZNetworkImageProvider(
      'https://example.com/a.avif',
      scale: 2.0,
      avifOverrideDurationMs: -1,
    );
    final c = XNZNetworkImageProvider(
      'https://example.com/a.avif',
      scale: 1.0,
      avifOverrideDurationMs: 1200,
    );
    final d = XNZNetworkImageProvider(
      'https://example.com/a.avif',
      scale: 1.0,
      avifOverrideDurationMs: -1,
    );

    expect(a == b, isFalse);
    expect(a == c, isFalse);
    expect(a == d, isTrue);
    expect(a.hashCode, equals(d.hashCode));
  });

  test('XNZMemoryCache evicts least recently used items by bytes', () {
    final cache = XNZMemoryCache<String>(5);
    final one = Uint8List.fromList([1, 1]); // 2 bytes
    final two = Uint8List.fromList([2, 2]); // 2 bytes
    final three = Uint8List.fromList([3, 3]); // 2 bytes

    cache.put('a', one);
    cache.put('b', two);
    expect(cache.currentBytes, 4);

    // Touch a so b becomes least-recently-used.
    expect(cache.get('a'), isNotNull);

    // Insert c -> total 6 > 5, should evict b.
    cache.put('c', three);

    expect(cache.get('b'), isNull);
    expect(cache.get('a'), isNotNull);
    expect(cache.get('c'), isNotNull);
  });

  test('XNZAssetImageProvider equality includes package and scale', () {
    final a = XNZAssetImageProvider(
      'images/demo.avif',
      package: 'example_pkg',
      scale: 1.0,
      avifOverrideDurationMs: -1,
    );
    final b = XNZAssetImageProvider(
      'images/demo.avif',
      package: 'another_pkg',
      scale: 1.0,
      avifOverrideDurationMs: -1,
    );
    final c = XNZAssetImageProvider(
      'images/demo.avif',
      package: 'example_pkg',
      scale: 2.0,
      avifOverrideDurationMs: -1,
    );
    final d = XNZAssetImageProvider(
      'images/demo.avif',
      package: 'example_pkg',
      scale: 1.0,
      avifOverrideDurationMs: -1,
    );

    expect(a == b, isFalse);
    expect(a == c, isFalse);
    expect(a == d, isTrue);
    expect(a.hashCode, equals(d.hashCode));
  });
}

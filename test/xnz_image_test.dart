import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xnz_image/xnz_image.dart';
import 'package:xnz_image/src/animated/xnz_animated_image_cache_key.dart';

class _TestAssetBundle extends CachingAssetBundle {
  _TestAssetBundle(this._bytes);

  final Uint8List _bytes;

  @override
  Future<ByteData> load(String key) async {
    return ByteData.view(_bytes.buffer);
  }
}

void main() {
  Future<XNZAnimatedImageData> buildAnimatedData(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return XNZAnimatedImageData(
        frames: <XNZAnimatedImageFrame>[
          XNZAnimatedImageFrame(
            image: frame.image,
            duration: const Duration(milliseconds: 100),
          ),
        ],
        duration: const Duration(milliseconds: 100),
      );
    } finally {
      codec.dispose();
    }
  }

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
  }, skip: kIsWeb);

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

  test('XNZNetworkImageProvider normalizes url for identity', () {
    final a = XNZNetworkImageProvider('  https://example.com/a.png  ');
    final b = XNZNetworkImageProvider('https://example.com/a.png');

    expect(a.imageUrl, equals('https://example.com/a.png'));
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  test('XNZImageDownloaderTask requestKey isolates headers safely', () {
    final withoutHeaders = XNZImageDownloaderTask(
      request: XNZUrlRequest('https://example.com/image.png'),
      onComplete: (_) {},
      onError: (_) {},
    );
    final headersA = XNZImageDownloaderTask(
      request: XNZUrlRequest(
        'https://example.com/image.png',
        headers: <String, String>{
          'Authorization': 'Bearer token-a',
          'X-Tenant': 'foo',
        },
      ),
      onComplete: (_) {},
      onError: (_) {},
    );
    final headersAReordered = XNZImageDownloaderTask(
      request: XNZUrlRequest(
        'https://example.com/image.png',
        headers: <String, String>{
          'x-tenant': 'foo',
          'authorization': 'Bearer token-a',
        },
      ),
      onComplete: (_) {},
      onError: (_) {},
    );
    final headersB = XNZImageDownloaderTask(
      request: XNZUrlRequest(
        'https://example.com/image.png',
        headers: <String, String>{
          'Authorization': 'Bearer token-b',
          'X-Tenant': 'foo',
        },
      ),
      onComplete: (_) {},
      onError: (_) {},
    );
    final withWhitespaceUrl = XNZImageDownloaderTask(
      request: XNZUrlRequest('  https://example.com/image.png  '),
      onComplete: (_) {},
      onError: (_) {},
    );

    expect(withoutHeaders.requestKey, equals('https://example.com/image.png'));
    expect(withWhitespaceUrl.requestKey, equals(withoutHeaders.requestKey));
    expect(headersA.requestKey, equals(headersAReordered.requestKey));
    expect(headersA.requestKey, isNot(equals(headersB.requestKey)));
    expect(headersA.requestKey, isNot(equals(withoutHeaders.requestKey)));
  });

  test('XNZUrlRequest cacheKey is configurable by headers strategy', () {
    final urlOnlyA = XNZUrlRequest(
      'https://example.com/a.png',
      headers: <String, String>{'Authorization': 'Bearer token-a'},
      cacheKeyStrategy: XNZCacheKeyStrategy.urlOnly,
    );
    final urlOnlyB = XNZUrlRequest(
      'https://example.com/a.png',
      headers: <String, String>{'Authorization': 'Bearer token-b'},
      cacheKeyStrategy: XNZCacheKeyStrategy.urlOnly,
    );
    final withHeadersA = XNZUrlRequest(
      'https://example.com/a.png',
      headers: <String, String>{'Authorization': 'Bearer token-a'},
      cacheKeyStrategy: XNZCacheKeyStrategy.urlAndHeaders,
    );
    final withHeadersB = XNZUrlRequest(
      'https://example.com/a.png',
      headers: <String, String>{'Authorization': 'Bearer token-b'},
      cacheKeyStrategy: XNZCacheKeyStrategy.urlAndHeaders,
    );

    expect(urlOnlyA.cacheKey, equals(urlOnlyB.cacheKey));
    expect(withHeadersA.cacheKey, isNot(equals(withHeadersB.cacheKey)));
    expect(withHeadersA.requestKey, isNot(equals(withHeadersB.requestKey)));
  });

  test('XNZAnimatedImage cache key isolates headers for network provider', () {
    final a = XNZNetworkImageProvider(
      'https://example.com/a.avif',
      headers: <String, String>{'Authorization': 'Bearer token-a'},
      cacheKeyStrategy: XNZCacheKeyStrategy.urlAndHeaders,
    );
    final b = XNZNetworkImageProvider(
      'https://example.com/a.avif',
      headers: <String, String>{'Authorization': 'Bearer token-b'},
      cacheKeyStrategy: XNZCacheKeyStrategy.urlAndHeaders,
    );

    final keyA = xnzAnimatedCacheKeyForProvider(a);
    final keyB = xnzAnimatedCacheKeyForProvider(b);

    expect(keyA, isNotNull);
    expect(keyB, isNotNull);
    expect(keyA, isNot(equals(keyB)));
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

  test(
    'XNZAnimatedImageCache evicts least recently used entries',
    () async {
      final Uint8List pngBytes =
          File('examples/example_bitmap/assets/tg.png').readAsBytesSync();
      final cache = XNZAnimatedImageCache(maxEntries: 2);
      final a = await buildAnimatedData(pngBytes);
      final b = await buildAnimatedData(pngBytes);
      final c = await buildAnimatedData(pngBytes);

      cache.set('a', a);
      cache.set('b', b);
      expect(cache.caches.keys.toList(), equals(<String>['a', 'b']));

      // Touch a so b becomes LRU.
      expect(cache.get('a'), same(a));
      expect(cache.caches.keys.toList(), equals(<String>['b', 'a']));

      // Insert c -> should evict b.
      cache.set('c', c);
      expect(cache.caches.containsKey('b'), isFalse);
      expect(cache.caches.keys.toList(), equals(<String>['a', 'c']));

      cache.clear();
    },
    skip: kIsWeb,
  );

  test('XNZAssetImageProvider equality includes package and scale', () {
    const a = XNZAssetImageProvider(
      'images/demo.avif',
      package: 'example_pkg',
      scale: 1.0,
      avifOverrideDurationMs: -1,
    );
    const b = XNZAssetImageProvider(
      'images/demo.avif',
      package: 'another_pkg',
      scale: 1.0,
      avifOverrideDurationMs: -1,
    );
    const c = XNZAssetImageProvider(
      'images/demo.avif',
      package: 'example_pkg',
      scale: 2.0,
      avifOverrideDurationMs: -1,
    );
    const d = XNZAssetImageProvider(
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

  testWidgets(
    'XNZAnimatedImage cache key isolates different asset bundles',
    (tester) async {
      final Uint8List tinyPng =
          File('examples/example_bitmap/web/icons/Icon-192.png')
              .readAsBytesSync();
      final Uint8List largePng =
          File('examples/example_bitmap/assets/tg.png').readAsBytesSync();
      final bundleA = _TestAssetBundle(tinyPng);
      final bundleB = _TestAssetBundle(largePng);
      XNZAnimatedImage.cache.clear();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: XNZAnimatedImage(
              image: XNZAssetImageProvider(
                'assets/same_name.png',
                bundle: bundleA,
              ),
              useCache: true,
              autoPlay: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      final firstRaw = tester.widget<RawImage>(find.byType(RawImage));
      final firstWidth = firstRaw.image?.width;
      expect(firstWidth, equals(192));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: XNZAnimatedImage(
              image: XNZAssetImageProvider(
                'assets/same_name.png',
                bundle: bundleB,
              ),
              useCache: true,
              autoPlay: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      final secondRaw = tester.widget<RawImage>(find.byType(RawImage));
      final secondWidth = secondRaw.image?.width;
      expect(secondWidth, equals(138));

      XNZAnimatedImage.cache.clear();
    },
    skip: kIsWeb,
  );

  testWidgets(
    'XNZAnimatedImage uses cloned frame handles for cache ownership safety',
    (tester) async {
      final previousCache = XNZAnimatedImage.cache;
      final localCache = XNZAnimatedImageCache(maxEntries: 8);
      XNZAnimatedImage.cache = localCache;
      addTearDown(() {
        localCache.clear();
        XNZAnimatedImage.cache = previousCache;
      });

      final Uint8List png =
          File('examples/example_bitmap/web/icons/Icon-192.png')
              .readAsBytesSync();
      final bundle = _TestAssetBundle(png);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: XNZAnimatedImage(
              image: XNZAssetImageProvider(
                'assets/clone_check.png',
                bundle: bundle,
              ),
              useCache: true,
              autoPlay: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      final rendered = tester.widget<RawImage>(find.byType(RawImage)).image;
      expect(rendered, isNotNull);
      expect(localCache.caches.length, equals(1));

      final cached = localCache.caches.values.single.frames.first.image;
      expect(identical(rendered, cached), isFalse);
      expect(rendered!.isCloneOf(cached), isTrue);
    },
    skip: kIsWeb,
  );
}

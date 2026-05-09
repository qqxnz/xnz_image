import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xnz_image_avif/xnz_image_avif.dart';

class _TestAssetBundle extends CachingAssetBundle {
  _TestAssetBundle(this._bytes);

  final Uint8List _bytes;

  @override
  Future<ByteData> load(String key) async {
    return ByteData.view(_bytes.buffer);
  }
}

void main() {
  test('XNZMemoryAvifImage equality includes avifOverrideDurationMs', () {
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final a = XNZMemoryAvifImage(bytes, scale: 1.0, avifOverrideDurationMs: 80);
    final b =
        XNZMemoryAvifImage(bytes, scale: 1.0, avifOverrideDurationMs: 120);
    final c = XNZMemoryAvifImage(bytes, scale: 1.0, avifOverrideDurationMs: 80);

    expect(a == b, isFalse);
    expect(a == c, isTrue);
    expect(a.hashCode, equals(c.hashCode));
  });

  test('XNZAvifNetworkImageProvider normalizes url and key fields', () {
    final a = XNZAvifNetworkImageProvider(
      '  https://example.com/a.avif  ',
      scale: 1.0,
      avifOverrideDurationMs: 80,
    );
    final b = XNZAvifNetworkImageProvider(
      'https://example.com/a.avif',
      scale: 1.0,
      avifOverrideDurationMs: 80,
    );
    final c = XNZAvifNetworkImageProvider(
      'https://example.com/a.avif',
      scale: 1.0,
      avifOverrideDurationMs: 120,
    );

    expect(a.imageUrl, equals('https://example.com/a.avif'));
    expect(a == b, isTrue);
    expect(a.hashCode, equals(b.hashCode));
    expect(a == c, isFalse);
  });

  test('XNZAvifFileImageProvider equality includes path and overrides', () {
    const path = '/tmp/demo.avif';
    final a = XNZAvifFileImageProvider(
      File(path),
      scale: 1.0,
      avifOverrideDurationMs: 100,
    );
    final b = XNZAvifFileImageProvider(
      File(path),
      scale: 1.0,
      avifOverrideDurationMs: 100,
    );
    final c = XNZAvifFileImageProvider(
      File(path),
      scale: 1.0,
      avifOverrideDurationMs: 200,
    );

    expect(a == b, isTrue);
    expect(a.hashCode, equals(b.hashCode));
    expect(a == c, isFalse);
  });

  test('XNZAvifAssetImageProvider equality includes bundle/package/scale', () {
    final bytes = Uint8List.fromList(<int>[1, 2, 3]);
    final bundleA = _TestAssetBundle(bytes);
    final bundleB = _TestAssetBundle(bytes);

    final a = XNZAvifAssetImageProvider(
      'assets/demo.avif',
      bundle: bundleA,
      package: 'pkg',
      scale: 1.0,
      avifOverrideDurationMs: 100,
    );
    final b = XNZAvifAssetImageProvider(
      'assets/demo.avif',
      bundle: bundleA,
      package: 'pkg',
      scale: 1.0,
      avifOverrideDurationMs: 100,
    );
    final c = XNZAvifAssetImageProvider(
      'assets/demo.avif',
      bundle: bundleB,
      package: 'pkg',
      scale: 1.0,
      avifOverrideDurationMs: 100,
    );

    expect(a == b, isTrue);
    expect(a.hashCode, equals(b.hashCode));
    expect(a == c, isFalse);
  });
}

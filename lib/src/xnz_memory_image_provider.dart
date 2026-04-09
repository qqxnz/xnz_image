import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_avif_platform_interface/flutter_avif_platform_interface.dart'
    as avif_platform;
import 'package:xnz_image/src/xnz_memory_avif_image_provider.dart';

class XNZMemoryImageProvider extends ImageProvider<XNZMemoryImageProvider> {
  const XNZMemoryImageProvider(
    this.bytes, {
    this.scale = 1.0,
    this.avifOverrideDurationMs = -1,
  });

  final Uint8List bytes;
  final double scale;
  final int? avifOverrideDurationMs;

  @override
  Future<XNZMemoryImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<XNZMemoryImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    XNZMemoryImageProvider key,
    ImageDecoderCallback decode,
  ) {
    if (isAvifBytes(key.bytes) &&
        !avif_platform.FlutterAvifPlatform.useNativeDecoder) {
      return AvifImageStreamCompleter(
        key: key,
        codec: _loadAvifAsync(key),
        scale: key.scale,
        debugLabel: 'XNZMemoryImageProvider(${describeIdentity(key.bytes)})',
        informationCollector: () sync* {
          yield ErrorDescription(
              'XNZMemoryImageProvider Image provider: $this');
        },
      );
    }
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: key.scale,
      informationCollector: () sync* {
        yield ErrorDescription('XNZMemoryImageProvider Image provider: $this');
      },
    );
  }

  Future<ui.Codec> _loadAsync(XNZMemoryImageProvider key) async {
    assert(key == this);
    return ui.instantiateImageCodec(key.bytes);
  }

  Future<AvifCodec> _loadAvifAsync(XNZMemoryImageProvider key) async {
    assert(key == this);
    if (kIsWeb) {
      throw UnsupportedError(
        'XNZMemoryImageProvider does not support the web platform.',
      );
    }
    return loadMemoryAvifCodec(
      key.bytes,
      codecKey: hashCode,
      avifOverrideDurationMs: avifOverrideDurationMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XNZMemoryImageProvider &&
          runtimeType == other.runtimeType &&
          bytes == other.bytes &&
          scale == other.scale &&
          avifOverrideDurationMs == other.avifOverrideDurationMs;

  @override
  int get hashCode =>
      Object.hash(bytes.hashCode, scale, avifOverrideDurationMs);
}

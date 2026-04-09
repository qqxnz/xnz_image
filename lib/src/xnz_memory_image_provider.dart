import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

import 'package:xnz_image/src/xnz_proxy_image_stream_completer.dart';

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
    final request = XNZImageRequest(
      sourceType: XNZImageSourceType.memory,
      bytes: key.bytes,
      options: <String, Object?>{
        'scale': key.scale,
        'avifOverrideDurationMs': key.avifOverrideDurationMs,
      },
    );
    final resolved = XNZImageRegistry.instance.resolve(request);
    if (resolved?.provider != null) {
      return XNZProxyImageStreamCompleter(
        provider: resolved!.provider!,
        debugLabel: 'XNZMemoryImageProvider(${describeIdentity(key.bytes)})',
        informationCollector: () sync* {
          yield ErrorDescription(
              'XNZMemoryImageProvider Image provider: $this');
        },
      );
    }

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      informationCollector: () sync* {
        yield ErrorDescription('XNZMemoryImageProvider Image provider: $this');
      },
    );
  }

  Future<ui.Codec> _loadAsync(
    XNZMemoryImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    assert(key == this);
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
      key.bytes,
    );
    return decode(buffer);
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

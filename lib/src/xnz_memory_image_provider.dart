import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

import 'package:xnz_image/src/animated/xnz_animated_bytes_fingerprint.dart';
import 'package:xnz_image/src/xnz_image_decode_utils.dart';
import 'package:xnz_image/src/xnz_proxy_image_stream_completer.dart';

class XNZMemoryImageProvider extends ImageProvider<XNZMemoryImageProvider> {
  static final Expando<ImageConfiguration> _lastImageConfigurations =
      Expando<ImageConfiguration>('xnz_memory_image_configuration');

  const XNZMemoryImageProvider(
    this.bytes, {
    this.scale = 1.0,
    this.avifOverrideDurationMs = -1,
  });

  final Uint8List bytes;
  final double scale;
  final int? avifOverrideDurationMs;

  /// Stable fingerprint cached by bytes identity for animated cache-key usage.
  int get bytesFingerprint => xnzStableBytesFingerprint(bytes);

  @override
  Future<XNZMemoryImageProvider> obtainKey(ImageConfiguration configuration) {
    XNZImageLogs.log('XNZMemoryImageProvider', 'obtainKey');
    _lastImageConfigurations[this] = configuration;
    return SynchronousFuture<XNZMemoryImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    XNZMemoryImageProvider key,
    ImageDecoderCallback decode,
  ) {
    XNZImageLogs.log('XNZMemoryImageProvider', 'loadImage');
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
      XNZImageLogs.log('XNZMemoryImageProvider', 'loadImage-命中自定义支持');
      return XNZProxyImageStreamCompleter(
        provider: resolved!.provider!,
        configuration:
            _lastImageConfigurations[key] ?? ImageConfiguration.empty,
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
    XNZImageLogs.log('XNZMemoryImageProvider', '_loadAsync-内置解码');
    return XNZImageDecodeUtils.decodeChecked(
      data: key.bytes,
      decode: decode,
      source: 'memory:${describeIdentity(key.bytes)}',
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

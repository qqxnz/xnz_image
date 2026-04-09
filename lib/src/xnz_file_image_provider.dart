import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_avif_platform_interface/flutter_avif_platform_interface.dart'
    as avif_platform;
import 'package:xnz_image/src/xnz_memory_avif_image_provider.dart';

class XNZFileImageProvider extends ImageProvider<XNZFileImageProvider> {
  const XNZFileImageProvider(
    this.file, {
    this.scale = 1.0,
    this.avifOverrideDurationMs = -1,
  });

  final File file;
  final double scale;
  final int? avifOverrideDurationMs;

  @override
  Future<XNZFileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<XNZFileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    XNZFileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    if (_isLikelyAvifPath(key.file.path) &&
        !avif_platform.FlutterAvifPlatform.useNativeDecoder) {
      return AvifImageStreamCompleter(
        key: key,
        codec: _loadAvifAsync(key),
        scale: key.scale,
        debugLabel: 'XNZFileImageProvider(${key.file.path})',
        informationCollector: () sync* {
          yield ErrorDescription('XNZFileImageProvider Image provider: $this');
        },
      );
    }

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: key.scale,
      informationCollector: () sync* {
        yield ErrorDescription('XNZFileImageProvider Image provider: $this');
      },
    );
  }

  Future<ui.Codec> _loadAsync(XNZFileImageProvider key) async {
    assert(key == this);
    final bytes = await key.file.readAsBytes();
    return ui.instantiateImageCodec(bytes);
  }

  Future<AvifCodec> _loadAvifAsync(XNZFileImageProvider key) async {
    assert(key == this);
    if (kIsWeb) {
      throw UnsupportedError(
        'XNZFileImageProvider does not support the web platform.',
      );
    }

    final bytes = await key.file.readAsBytes();
    return loadMemoryAvifCodec(
      bytes,
      codecKey: hashCode,
      avifOverrideDurationMs: avifOverrideDurationMs,
    );
  }

  bool _isLikelyAvifPath(String path) {
    final lowercasePath = path.toLowerCase();
    return lowercasePath.endsWith('.avif') || lowercasePath.endsWith('.avifs');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XNZFileImageProvider &&
          runtimeType == other.runtimeType &&
          file.path == other.file.path &&
          scale == other.scale &&
          avifOverrideDurationMs == other.avifOverrideDurationMs;

  @override
  int get hashCode => Object.hash(file.path, scale, avifOverrideDurationMs);
}

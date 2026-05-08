import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class XNZFileImageProvider extends ImageProvider<XNZFileImageProvider> {
  const XNZFileImageProvider(
    this.file, {
    this.scale = 1.0,
    this.avifOverrideDurationMs = -1,
  });

  final dynamic file;
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
    return MultiFrameImageStreamCompleter(
      codec: Future<ui.Codec>.error(
        UnsupportedError(
          'XNZFileImageProvider does not support the web platform.',
        ),
      ),
      scale: key.scale,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XNZFileImageProvider &&
          runtimeType == other.runtimeType &&
          file == other.file &&
          scale == other.scale &&
          avifOverrideDurationMs == other.avifOverrideDurationMs;

  @override
  int get hashCode => Object.hash(file, scale, avifOverrideDurationMs);
}

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Decoder signature used by animated image widgets for custom frame decoding.
typedef XNZAnimatedImageDecoder = Future<Object?> Function(
  XNZAnimatedImageDecodeRequest request,
);

/// Decode request passed to [XNZAnimatedImageDecoder].
@immutable
class XNZAnimatedImageDecodeRequest {
  /// Creates a decode request.
  const XNZAnimatedImageDecodeRequest({
    required this.image,
    required this.bytes,
    required this.scale,
    this.avifOverrideDurationMs,
  });

  /// Source image provider.
  final ImageProvider image;

  /// Raw bytes resolved from [image].
  final Uint8List bytes;

  /// Render scale used for decoded frames.
  final double scale;

  /// Optional per-frame duration override used by AVIF decoders.
  final int? avifOverrideDurationMs;
}

/// A single decoded animation frame.
@immutable
class XNZAnimatedImageFrame {
  /// Creates a frame.
  const XNZAnimatedImageFrame({
    required this.image,
    required this.duration,
    this.scale = 1.0,
  });

  /// Frame bitmap.
  final ui.Image image;

  /// Frame display duration.
  final Duration duration;

  /// Frame scale.
  final double scale;
}

/// Fully decoded animation payload.
@immutable
class XNZAnimatedImageData {
  /// Creates decoded animation data.
  const XNZAnimatedImageData({
    required this.frames,
    required this.duration,
  });

  /// Ordered frame list.
  final List<XNZAnimatedImageFrame> frames;

  /// Total animation duration.
  final Duration duration;
}

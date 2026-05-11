import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

import 'xnz_animated_image_models.dart';
import 'xnz_animated_provider_context.dart';

/// Resolves animated decoder provided by registered supports.
XNZAnimatedImageDecoder? xnzResolveSupportAnimatedDecoder({
  required ImageProvider provider,
  required Uint8List bytes,
  required double scale,
  required int? avifOverrideDurationMs,
}) {
  final sourceType = xnzAnimatedSourceTypeOf(provider);
  if (sourceType == null) {
    return null;
  }
  final request = XNZImageRequest(
    sourceType: sourceType,
    uri: xnzAnimatedUriOfProvider(provider),
    bytes: sourceType == XNZImageSourceType.memory ? bytes : null,
    options: <String, Object?>{
      ...xnzAnimatedProviderOptions(provider),
      'scale': scale,
      'avifOverrideDurationMs': avifOverrideDurationMs,
    },
  );

  final resolved = XNZImageRegistry.instance.resolve(request);
  final meta = resolved?.meta;
  if (meta is Map<Object?, Object?>) {
    final decoder = meta['animatedDecoder'];
    if (decoder is XNZAnimatedImageDecoder) {
      return decoder;
    }
    if (decoder is Function) {
      return (decodeRequest) async => await decoder(decodeRequest);
    }
  }
  return null;
}

/// Coerces extension decoder result into [XNZAnimatedImageData].
XNZAnimatedImageData? xnzCoerceAnimatedDecodedData(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is XNZAnimatedImageData) {
    return value;
  }
  if (value is! Map<Object?, Object?>) {
    return null;
  }

  final rawFrames = value['frames'];
  if (rawFrames is! List) {
    return null;
  }

  final frames = <XNZAnimatedImageFrame>[];
  final isSingleFrame = rawFrames.length <= 1;
  for (final rawFrame in rawFrames) {
    if (rawFrame is! Map<Object?, Object?>) {
      return null;
    }
    final image = rawFrame['image'];
    final duration = rawFrame['duration'];
    final scale = rawFrame['scale'];
    if (image is! ui.Image || duration is! Duration) {
      return null;
    }
    frames.add(
      XNZAnimatedImageFrame(
        image: image,
        duration: isSingleFrame
            ? duration
            : duration.inMilliseconds <= 0
                ? const Duration(milliseconds: 1)
                : duration,
        scale: scale is num ? scale.toDouble() : 1.0,
      ),
    );
  }

  final rawDuration = value['duration'];
  final totalDuration =
      rawDuration is Duration ? rawDuration : xnzSumAnimatedDuration(frames);
  return XNZAnimatedImageData(
    frames: frames,
    duration: totalDuration.inMilliseconds <= 0
        ? xnzSumAnimatedDuration(frames)
        : totalDuration,
  );
}

/// Sums frame durations with animated minimum frame duration fallback.
Duration xnzSumAnimatedDuration(List<XNZAnimatedImageFrame> frames) {
  if (frames.length <= 1) {
    return Duration.zero;
  }
  var duration = Duration.zero;
  for (final frame in frames) {
    duration += frame.duration.inMilliseconds <= 0
        ? const Duration(milliseconds: 1)
        : frame.duration;
  }
  return duration;
}

/// Clones decoded frame handles for isolated ownership.
XNZAnimatedImageData xnzCloneAnimatedDecodedData(XNZAnimatedImageData data) {
  final frames = data.frames
      .map(
        (frame) => XNZAnimatedImageFrame(
          image: frame.image.clone(),
          duration: frame.duration,
          scale: frame.scale,
        ),
      )
      .toList(growable: false);
  return XNZAnimatedImageData(frames: frames, duration: data.duration);
}

/// Built-in codec-based animated decoder.
Future<XNZAnimatedImageData> xnzDefaultDecodeAnimatedImage(
  XNZAnimatedImageDecodeRequest request,
) async {
  final codec = await ui.instantiateImageCodec(
    request.bytes,
    targetWidth: null,
    targetHeight: null,
  );

  final frames = <XNZAnimatedImageFrame>[];
  var totalDuration = Duration.zero;
  final isSingleFrame = codec.frameCount <= 1;
  try {
    for (var i = 0; i < codec.frameCount; i++) {
      final frame = await codec.getNextFrame();
      final frameDuration = isSingleFrame
          ? frame.duration
          : frame.duration.inMilliseconds <= 0
              ? const Duration(milliseconds: 1)
              : frame.duration;
      frames.add(
        XNZAnimatedImageFrame(
          image: frame.image,
          duration: frameDuration,
          scale: request.scale,
        ),
      );
      totalDuration += frameDuration;
    }
  } finally {
    codec.dispose();
  }
  return XNZAnimatedImageData(frames: frames, duration: totalDuration);
}

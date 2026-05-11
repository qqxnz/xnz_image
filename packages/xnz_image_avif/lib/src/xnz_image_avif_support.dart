import 'dart:io';

import 'package:flutter/services.dart';
import 'package:xnz_image/xnz_image.dart';

import 'xnz_avif_image_providers.dart';
import 'xnz_memory_avif_image_provider.dart';

class XNZImageAvif implements XNZImageSupport {
  @override
  String get id => 'avif';

  @override
  int get priority => 90;

  @override
  bool canHandle(XNZImageRequest request) {
    if (request.bytes != null && isAvifBytes(request.bytes!)) {
      return true;
    }
    final path = request.uri?.path;
    if (path == null || path.isEmpty) {
      return false;
    }
    final lower = path.toLowerCase();
    return lower.endsWith('.avif') || lower.endsWith('.avifs');
  }

  @override
  XNZImageBuildResult? resolve(XNZImageRequest request) {
    final avifOverrideDurationMs =
        request.option('avifOverrideDurationMs') as int?;
    final scale = request.option('scale') as double? ?? 1.0;
    final headers = request.option('headers') as Map<String, String>?;
    final cacheKeyStrategy =
        request.option('cacheKeyStrategy') as XNZCacheKeyStrategy?;

    final meta = <String, Object?>{
      'animatedDecoder': _decodeAvifAnimatedImage,
    };

    switch (request.sourceType) {
      case XNZImageSourceType.network:
        final bytes = request.bytes;
        if (bytes != null && isAvifBytes(bytes)) {
          return XNZImageBuildResult.provider(
            provider: XNZAvifMemoryImageProvider(
              bytes,
              scale: scale,
              avifOverrideDurationMs: avifOverrideDurationMs,
            ),
            format: 'avif',
            meta: meta,
          );
        }
        final uri = request.uri;
        if (uri == null) {
          return null;
        }
        return XNZImageBuildResult.provider(
          provider: XNZAvifNetworkImageProvider(
            uri.toString(),
            headers: headers,
            cacheKeyStrategy: cacheKeyStrategy ?? XNZCacheKeyStrategy.urlOnly,
            scale: scale,
            avifOverrideDurationMs: avifOverrideDurationMs,
          ),
          format: 'avif',
          meta: meta,
        );
      case XNZImageSourceType.memory:
        final bytes = request.bytes;
        if (bytes == null || !isAvifBytes(bytes)) {
          return null;
        }
        return XNZImageBuildResult.provider(
          provider: XNZAvifMemoryImageProvider(
            bytes,
            scale: scale,
            avifOverrideDurationMs: avifOverrideDurationMs,
          ),
          format: 'avif',
          meta: meta,
        );
      case XNZImageSourceType.file:
        final uri = request.uri;
        if (uri == null) {
          return null;
        }
        return XNZImageBuildResult.provider(
          provider: XNZAvifFileImageProvider(
            File(uri.toFilePath()),
            scale: scale,
            avifOverrideDurationMs: avifOverrideDurationMs,
          ),
          format: 'avif',
          meta: meta,
        );
      case XNZImageSourceType.asset:
        final assetName = request.option('assetName') as String?;
        if (assetName == null || assetName.isEmpty) {
          return null;
        }
        return XNZImageBuildResult.provider(
          provider: XNZAvifAssetImageProvider(
            assetName,
            bundle: request.option('bundle') as AssetBundle?,
            package: request.option('package') as String?,
            scale: scale,
            avifOverrideDurationMs: avifOverrideDurationMs,
          ),
          format: 'avif',
          meta: meta,
        );
    }
  }
}

Future<Map<String, Object?>?> _decodeAvifAnimatedImage(dynamic request) async {
  final bytes = request.bytes as Uint8List;
  if (!isAvifBytes(bytes)) {
    return null;
  }

  final codec = await loadMemoryAvifCodec(
    bytes,
    codecKey: xnzNextAvifCodecKey(),
    avifOverrideDurationMs: request.avifOverrideDurationMs as int?,
  );

  final frames = <Map<String, Object?>>[];
  var duration = Duration.zero;
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
        <String, Object?>{
          'image': frame.image,
          'duration': frameDuration,
          'scale': (request.scale as num?)?.toDouble() ?? 1.0,
        },
      );
      duration += frameDuration;
    }
  } finally {
    codec.dispose();
  }

  return <String, Object?>{
    'frames': frames,
    'duration': duration,
  };
}

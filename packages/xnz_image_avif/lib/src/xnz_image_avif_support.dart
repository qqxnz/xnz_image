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
          );
        }
        final uri = request.uri;
        if (uri == null) {
          return null;
        }
        return XNZImageBuildResult.provider(
          provider: XNZAvifNetworkImageProvider(
            uri.toString(),
            scale: scale,
            avifOverrideDurationMs: avifOverrideDurationMs,
          ),
          format: 'avif',
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
        );
    }
  }
}

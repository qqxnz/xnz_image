import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

import 'package:xnz_image/src/xnz_memory_image_provider.dart';
import 'package:xnz_image/src/xnz_resolved_image.dart';

class XNZMemoryImage extends StatelessWidget {
  const XNZMemoryImage({
    super.key,
    required this.bytes,
    this.width,
    this.height,
    this.color,
    this.fit,
    this.renderBuilder,
    this.avifOverrideDurationMs = -1,
  });

  final Uint8List bytes;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit? fit;
  final XNZRenderBuilder? renderBuilder;
  final int? avifOverrideDurationMs;

  XNZResolvedImage _resolveImage() {
    final request = XNZImageRequest(
      sourceType: XNZImageSourceType.memory,
      bytes: bytes,
      options: <String, Object?>{
        'width': width,
        'height': height,
        'fit': fit,
        'color': color,
        'scale': 1.0,
        'avifOverrideDurationMs': avifOverrideDurationMs,
      },
    );
    return xnzResolveWithRegistry(
      request: request,
      fallbackProvider: XNZMemoryImageProvider(
        bytes,
        avifOverrideDurationMs: avifOverrideDurationMs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveImage();
    return xnzBuildResolvedImage(
      context: context,
      resolved: resolved,
      renderBuilder: renderBuilder,
      bitmapBuilder: (provider) => Image(
        image: provider,
        width: width,
        height: height,
        color: color,
        fit: fit,
      ),
    );
  }
}

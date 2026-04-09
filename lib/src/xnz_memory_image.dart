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
    final result = XNZImageRegistry.instance.resolve(request);
    if (result != null) {
      return XNZResolvedImage(
        kind: result.kind == XNZImageBuildKind.widget
            ? XNZResolvedKind.customWidget
            : XNZResolvedKind.bitmapProvider,
        provider: result.provider,
        widget: result.widget,
        format: result.format,
        meta: result.meta,
      );
    }

    return XNZResolvedImage(
      kind: XNZResolvedKind.bitmapProvider,
      provider: XNZMemoryImageProvider(
        bytes,
        avifOverrideDurationMs: avifOverrideDurationMs,
      ),
      format: 'bitmap',
    );
  }

  Widget _defaultRender(XNZResolvedImage resolved) {
    if (resolved.kind == XNZResolvedKind.customWidget) {
      return resolved.widget ?? const SizedBox.shrink();
    }

    final provider = resolved.provider!;

    return Image(
      image: provider,
      width: width,
      height: height,
      color: color,
      fit: fit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveImage();
    final child = _defaultRender(resolved);
    return xnzApplyRenderBuilder(
      context: context,
      child: child,
      renderBuilder: renderBuilder,
    );
  }
}

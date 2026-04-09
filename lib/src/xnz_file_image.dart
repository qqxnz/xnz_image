import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

import 'package:xnz_image/src/xnz_file_image_provider.dart';
import 'package:xnz_image/src/xnz_resolved_image.dart';

class XNZFileImage extends StatelessWidget {
  const XNZFileImage({
    super.key,
    required this.file,
    this.width,
    this.height,
    this.color,
    this.fit,
    this.renderBuilder,
    this.avifOverrideDurationMs = -1,
  });

  final File file;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit? fit;
  final XNZRenderBuilder? renderBuilder;
  final int? avifOverrideDurationMs;

  XNZResolvedImage _resolveImage() {
    final request = XNZImageRequest(
      sourceType: XNZImageSourceType.file,
      uri: file.uri,
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
      provider: XNZFileImageProvider(
        file,
        avifOverrideDurationMs: avifOverrideDurationMs,
      ),
      format: 'bitmap',
    );
  }

  Widget _defaultRender(BuildContext context, XNZResolvedImage resolved) {
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
    if (renderBuilder != null) {
      return renderBuilder!(context, resolved);
    }
    return _defaultRender(context, resolved);
  }
}

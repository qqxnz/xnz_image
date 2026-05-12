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
    return xnzResolveWithRegistry(
      request: request,
      fallbackProvider: XNZFileImageProvider(
        file,
        avifOverrideDurationMs: avifOverrideDurationMs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    XNZImageLogs.event('XNZFileImage', 'build_start', fields: {
      'path': file.path,
      'width': width,
      'height': height,
    });
    final resolved = _resolveImage();
    XNZImageLogs.event('XNZFileImage', 'resolve_complete', fields: {
      'path': file.path,
      'format': resolved.format,
      'kind': resolved.kind.name,
    });
    try {
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
    } catch (error, stackTrace) {
      XNZImageLogs.event('XNZFileImage', 'display_failed', fields: {
        'path': file.path,
        'format': resolved.format,
        'kind': resolved.kind.name,
        'error': error,
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

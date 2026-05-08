import 'package:flutter/material.dart';
import 'package:xnz_image/src/xnz_resolved_image.dart';

/// Web stub for file-based image widget.
///
/// Flutter Web does not support `dart:io` file rendering APIs.
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

  final dynamic file;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit? fit;
  final XNZRenderBuilder? renderBuilder;
  final int? avifOverrideDurationMs;

  @override
  Widget build(BuildContext context) {
    throw UnsupportedError('XNZFileImage does not support the web platform.');
  }
}

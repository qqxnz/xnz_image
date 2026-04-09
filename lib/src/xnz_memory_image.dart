import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:xnz_image/src/xnz_network_image.dart';
import 'package:xnz_image/src/xnz_memory_image_provider.dart';
import 'package:xnz_image/src/xnz_svg.dart';

class XNZMemoryImage extends StatelessWidget {
  const XNZMemoryImage({
    super.key,
    required this.bytes,
    this.width,
    this.height,
    this.color,
    this.fit,
    this.imageBuilder,
    this.svgBuilder,
    this.avifOverrideDurationMs = -1,
  });

  final Uint8List bytes;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit? fit;
  final ImageWidgetBuilder? imageBuilder;
  final SvgWidgetBuilder? svgBuilder;
  final int? avifOverrideDurationMs;

  @override
  Widget build(BuildContext context) {
    if (isSvgBytes(bytes)) {
      final svgWidget = SvgPicture.memory(
        bytes,
        width: width,
        height: height,
        fit: fit ?? BoxFit.contain,
        colorFilter: svgColorFilterFromColor(color),
      );
      if (svgBuilder != null) {
        return svgBuilder!(context, svgWidget);
      }
      return svgWidget;
    }

    final provider = XNZMemoryImageProvider(
      bytes,
      avifOverrideDurationMs: avifOverrideDurationMs,
    );

    if (imageBuilder != null) {
      return imageBuilder!(context, provider);
    }

    return Image(
      image: provider,
      width: width,
      height: height,
      color: color,
      fit: fit,
    );
  }
}

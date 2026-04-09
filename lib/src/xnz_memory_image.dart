import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:xnz_image/src/xnz_network_image.dart';
import 'package:xnz_image/src/xnz_memory_image_provider.dart';

class XNZMemoryImage extends StatelessWidget {
  const XNZMemoryImage({
    super.key,
    required this.bytes,
    this.width,
    this.height,
    this.color,
    this.fit,
    this.imageBuilder,
    this.avifOverrideDurationMs = -1,
  });

  final Uint8List bytes;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit? fit;
  final ImageWidgetBuilder? imageBuilder;
  final int? avifOverrideDurationMs;

  @override
  Widget build(BuildContext context) {
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

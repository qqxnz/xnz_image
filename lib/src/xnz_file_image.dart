import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xnz_net_cache_image/src/xnz_file_image_provider.dart';
import 'package:xnz_net_cache_image/src/xnz_network_image.dart';

class XNZFileImage extends StatelessWidget {
  const XNZFileImage({
    super.key,
    required this.file,
    this.width,
    this.height,
    this.color,
    this.fit,
    this.imageBuilder,
    this.avifOverrideDurationMs = -1,
  });

  final File file;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit? fit;
  final ImageWidgetBuilder? imageBuilder;
  final int? avifOverrideDurationMs;

  @override
  Widget build(BuildContext context) {
    final provider = XNZFileImageProvider(
      file,
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

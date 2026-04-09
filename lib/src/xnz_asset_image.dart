import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnz_image/src/xnz_asset_image_provider.dart';
import 'package:xnz_image/src/xnz_network_image.dart';

class XNZAssetImage extends StatelessWidget {
  const XNZAssetImage({
    super.key,
    required this.assetName,
    this.bundle,
    this.package,
    this.width,
    this.height,
    this.color,
    this.fit,
    this.imageBuilder,
    this.avifOverrideDurationMs = -1,
  });

  final String assetName;
  final AssetBundle? bundle;
  final String? package;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit? fit;
  final ImageWidgetBuilder? imageBuilder;
  final int? avifOverrideDurationMs;

  @override
  Widget build(BuildContext context) {
    final provider = XNZAssetImageProvider(
      assetName,
      bundle: bundle,
      package: package,
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

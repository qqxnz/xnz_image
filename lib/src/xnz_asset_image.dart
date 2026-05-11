import 'package:flutter/material.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

import 'package:xnz_image/src/xnz_asset_image_provider.dart';
import 'package:xnz_image/src/xnz_resolved_image.dart';

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
    this.renderBuilder,
    this.avifOverrideDurationMs = -1,
  });

  final String assetName;
  final AssetBundle? bundle;
  final String? package;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit? fit;
  final XNZRenderBuilder? renderBuilder;
  final int? avifOverrideDurationMs;

  XNZResolvedImage _resolveImage() {
    final assetPath = package == null || package!.isEmpty
        ? assetName
        : 'packages/$package/$assetName';
    final request = XNZImageRequest(
      sourceType: XNZImageSourceType.asset,
      uri: Uri(path: assetPath),
      options: <String, Object?>{
        'assetName': assetName,
        'bundle': bundle,
        'package': package,
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
      fallbackProvider: XNZAssetImageProvider(
        assetName,
        bundle: bundle,
        package: package,
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

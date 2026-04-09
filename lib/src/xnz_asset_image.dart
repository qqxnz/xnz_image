// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/material.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

import 'package:xnz_image/src/xnz_asset_image_provider.dart';
import 'package:xnz_image/src/xnz_network_image.dart';
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
    this.imageBuilder,
    this.svgBuilder,
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
  @Deprecated('Use renderBuilder instead.')
  final ImageWidgetBuilder? imageBuilder;
  @Deprecated('Use renderBuilder instead.')
  final SvgWidgetBuilder? svgBuilder;
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
      provider: XNZAssetImageProvider(
        assetName,
        bundle: bundle,
        package: package,
        avifOverrideDurationMs: avifOverrideDurationMs,
      ),
      format: 'bitmap',
    );
  }

  Widget _defaultRender(BuildContext context, XNZResolvedImage resolved) {
    if (resolved.kind == XNZResolvedKind.customWidget) {
      final customWidget = resolved.widget ?? const SizedBox.shrink();
      if (svgBuilder != null) {
        return svgBuilder!(context, customWidget);
      }
      return customWidget;
    }

    final provider = resolved.provider!;
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

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveImage();
    if (renderBuilder != null) {
      return renderBuilder!(context, resolved);
    }
    return _defaultRender(context, resolved);
  }
}

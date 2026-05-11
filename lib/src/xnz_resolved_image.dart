import 'package:flutter/widgets.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

enum XNZResolvedKind { bitmapProvider, customWidget }

class XNZResolvedImage {
  const XNZResolvedImage({
    required this.kind,
    this.provider,
    this.widget,
    required this.format,
    this.meta,
  });

  final XNZResolvedKind kind;
  final ImageProvider? provider;
  final Widget? widget;
  final String format;
  final Object? meta;
}

typedef XNZRenderBuilder = Widget? Function(
  BuildContext context,
  Widget child,
);

Widget xnzApplyRenderBuilder({
  required BuildContext context,
  required Widget child,
  required XNZRenderBuilder? renderBuilder,
}) {
  return renderBuilder?.call(context, child) ?? child;
}

XNZResolvedImage xnzResolvedImageFromBuildResult(XNZImageBuildResult result) {
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

XNZResolvedImage xnzResolveWithRegistry({
  required XNZImageRequest request,
  required ImageProvider fallbackProvider,
  String fallbackFormat = 'bitmap',
}) {
  final result = XNZImageRegistry.instance.resolve(request);
  if (result != null) {
    return xnzResolvedImageFromBuildResult(result);
  }
  return XNZResolvedImage(
    kind: XNZResolvedKind.bitmapProvider,
    provider: fallbackProvider,
    format: fallbackFormat,
  );
}

Widget xnzDefaultResolvedRender({
  required XNZResolvedImage resolved,
  required Widget Function(ImageProvider provider) bitmapBuilder,
}) {
  if (resolved.kind == XNZResolvedKind.customWidget) {
    return resolved.widget ?? const SizedBox.shrink();
  }
  final provider = resolved.provider;
  if (provider == null) {
    return const SizedBox.shrink();
  }
  return bitmapBuilder(provider);
}

Widget xnzBuildResolvedImage({
  required BuildContext context,
  required XNZResolvedImage resolved,
  required XNZRenderBuilder? renderBuilder,
  required Widget Function(ImageProvider provider) bitmapBuilder,
}) {
  final child = xnzDefaultResolvedRender(
    resolved: resolved,
    bitmapBuilder: bitmapBuilder,
  );
  return xnzApplyRenderBuilder(
    context: context,
    child: child,
    renderBuilder: renderBuilder,
  );
}

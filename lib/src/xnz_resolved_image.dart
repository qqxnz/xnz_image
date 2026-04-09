import 'package:flutter/widgets.dart';

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

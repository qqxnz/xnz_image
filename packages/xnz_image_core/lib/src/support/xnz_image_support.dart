import 'dart:typed_data';

import 'package:flutter/widgets.dart';

enum XNZImageSourceType { network, memory, file, asset }

enum XNZImageBuildKind { provider, widget }

class XNZImageRequest {
  const XNZImageRequest({
    required this.sourceType,
    this.uri,
    this.bytes,
    this.options = const <String, Object?>{},
  });

  final Uri? uri;
  final Uint8List? bytes;
  final XNZImageSourceType sourceType;
  final Map<String, Object?> options;

  Object? option(String key) => options[key];
}

class XNZImageBuildResult {
  const XNZImageBuildResult._({
    required this.kind,
    this.provider,
    this.widget,
    required this.format,
    this.meta,
  });

  factory XNZImageBuildResult.provider({
    required ImageProvider provider,
    required String format,
    Object? meta,
  }) {
    return XNZImageBuildResult._(
      kind: XNZImageBuildKind.provider,
      provider: provider,
      format: format,
      meta: meta,
    );
  }

  factory XNZImageBuildResult.widget({
    required Widget widget,
    required String format,
    Object? meta,
  }) {
    return XNZImageBuildResult._(
      kind: XNZImageBuildKind.widget,
      widget: widget,
      format: format,
      meta: meta,
    );
  }

  final XNZImageBuildKind kind;
  final ImageProvider? provider;
  final Widget? widget;
  final String format;
  final Object? meta;
}

abstract class XNZImageSupport {
  String get id;

  int get priority => 0;

  bool canHandle(XNZImageRequest request);

  XNZImageBuildResult? resolve(XNZImageRequest request);
}

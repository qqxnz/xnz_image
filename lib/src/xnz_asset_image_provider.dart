import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

import 'package:xnz_image/src/xnz_image_decode_utils.dart';
import 'package:xnz_image/src/xnz_proxy_image_stream_completer.dart';

class XNZAssetImageProvider extends ImageProvider<XNZAssetImageProvider> {
  static final Expando<ImageConfiguration> _lastImageConfigurations =
      Expando<ImageConfiguration>('xnz_asset_image_configuration');

  const XNZAssetImageProvider(
    this.assetName, {
    this.bundle,
    this.package,
    this.scale = 1.0,
    this.avifOverrideDurationMs = -1,
  });

  final String assetName;
  final AssetBundle? bundle;
  final String? package;
  final double scale;
  final int? avifOverrideDurationMs;

  String get _resolvedAssetName {
    if (package == null || package!.isEmpty) {
      return assetName;
    }
    return 'packages/$package/$assetName';
  }

  @override
  Future<XNZAssetImageProvider> obtainKey(ImageConfiguration configuration) {
    XNZImageLogs.log('XNZAssetImageProvider', 'obtainKey $_resolvedAssetName');
    _lastImageConfigurations[this] = configuration;
    return SynchronousFuture<XNZAssetImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    XNZAssetImageProvider key,
    ImageDecoderCallback decode,
  ) {
    XNZImageLogs.log(
        'XNZAssetImageProvider', 'loadImage ${key._resolvedAssetName}');
    final request = XNZImageRequest(
      sourceType: XNZImageSourceType.asset,
      uri: Uri(path: key._resolvedAssetName),
      options: <String, Object?>{
        'assetName': key.assetName,
        'bundle': key.bundle,
        'package': key.package,
        'scale': key.scale,
        'avifOverrideDurationMs': key.avifOverrideDurationMs,
      },
    );
    final resolved = XNZImageRegistry.instance.resolve(request);
    if (resolved?.provider != null) {
      XNZImageLogs.log('XNZAssetImageProvider', 'loadImage-命中自定义支持');
      return XNZProxyImageStreamCompleter(
        provider: resolved!.provider!,
        configuration:
            _lastImageConfigurations[key] ?? ImageConfiguration.empty,
        debugLabel: key._resolvedAssetName,
        informationCollector: () sync* {
          yield ErrorDescription('XNZAssetImageProvider Image provider: $this');
        },
      );
    }

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      informationCollector: () sync* {
        yield ErrorDescription('XNZAssetImageProvider Image provider: $this');
      },
    );
  }

  Future<ui.Codec> _loadAsync(
    XNZAssetImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    assert(key == this);
    XNZImageLogs.log(
        'XNZAssetImageProvider', '_loadAsync-内置解码 ${key._resolvedAssetName}');
    final data = await _loadAssetData(key);
    return XNZImageDecodeUtils.decodeChecked(
      data: data,
      decode: decode,
      source: key._resolvedAssetName,
    );
  }

  Future<Uint8List> _loadAssetData(XNZAssetImageProvider key) async {
    final assetBundle = key.bundle ?? rootBundle;
    final byteData = await assetBundle.load(key._resolvedAssetName);
    return byteData.buffer.asUint8List();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XNZAssetImageProvider &&
          runtimeType == other.runtimeType &&
          assetName == other.assetName &&
          bundle == other.bundle &&
          package == other.package &&
          scale == other.scale &&
          avifOverrideDurationMs == other.avifOverrideDurationMs;

  @override
  int get hashCode =>
      Object.hash(assetName, bundle, package, scale, avifOverrideDurationMs);
}

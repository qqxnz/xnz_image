import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_avif_platform_interface/flutter_avif_platform_interface.dart'
    as avif_platform;
import 'package:xnz_image/src/xnz_memory_avif_image_provider.dart';

class XNZAssetImageProvider extends ImageProvider<XNZAssetImageProvider> {
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
    return SynchronousFuture<XNZAssetImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    XNZAssetImageProvider key,
    ImageDecoderCallback decode,
  ) {
    if (_isLikelyAvifAsset(key._resolvedAssetName) &&
        !avif_platform.FlutterAvifPlatform.useNativeDecoder) {
      return AvifImageStreamCompleter(
        key: key,
        codec: _loadAvifAsync(key),
        scale: key.scale,
        debugLabel: key._resolvedAssetName,
        informationCollector: () sync* {
          yield ErrorDescription('XNZAssetImageProvider Image provider: $this');
        },
      );
    }

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: key.scale,
      informationCollector: () sync* {
        yield ErrorDescription('XNZAssetImageProvider Image provider: $this');
      },
    );
  }

  Future<ui.Codec> _loadAsync(XNZAssetImageProvider key) async {
    assert(key == this);
    final data = await _loadAssetData(key);
    return ui.instantiateImageCodec(data);
  }

  Future<AvifCodec> _loadAvifAsync(XNZAssetImageProvider key) async {
    assert(key == this);
    if (kIsWeb) {
      throw UnsupportedError(
        'XNZAssetImageProvider does not support the web platform.',
      );
    }

    final data = await _loadAssetData(key);
    return loadMemoryAvifCodec(
      data,
      codecKey: hashCode,
      avifOverrideDurationMs: avifOverrideDurationMs,
    );
  }

  Future<Uint8List> _loadAssetData(XNZAssetImageProvider key) async {
    final assetBundle = key.bundle ?? rootBundle;
    final byteData = await assetBundle.load(key._resolvedAssetName);
    return byteData.buffer.asUint8List();
  }

  bool _isLikelyAvifAsset(String path) {
    final lowercasePath = path.toLowerCase();
    return lowercasePath.endsWith('.avif') || lowercasePath.endsWith('.avifs');
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

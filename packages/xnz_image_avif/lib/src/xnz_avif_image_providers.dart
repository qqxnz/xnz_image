import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnz_image/xnz_image.dart';

import 'xnz_memory_avif_image_provider.dart';

String _normalizeNetworkUrl(String url) => url.trim();

class XNZAvifNetworkImageProvider
    extends ImageProvider<XNZAvifNetworkImageProvider> {
  XNZAvifNetworkImageProvider(
    String imageUrl, {
    this.scale = 1.0,
    this.avifOverrideDurationMs = -1,
  }) : imageUrl = _normalizeNetworkUrl(imageUrl);

  final String imageUrl;
  final double scale;
  final int? avifOverrideDurationMs;

  @override
  Future<XNZAvifNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<XNZAvifNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    XNZAvifNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return AvifImageStreamCompleter(
      key: key,
      codec: _loadAsync(key),
      scale: key.scale,
      debugLabel: key.imageUrl,
      informationCollector: () sync* {
        yield ErrorDescription(
          'XNZAvifNetworkImageProvider Image provider: $this',
        );
      },
    );
  }

  Future<AvifCodec> _loadAsync(XNZAvifNetworkImageProvider key) async {
    final bytes = await _loadImageData(key.imageUrl);
    unawaited(XNZCacheManager().setCache(key.imageUrl, bytes));
    return loadMemoryAvifCodec(
      bytes,
      codecKey: hashCode,
      avifOverrideDurationMs: avifOverrideDurationMs,
    );
  }

  Future<Uint8List> _loadImageData(String url) async {
    final normalizedUrl = _normalizeNetworkUrl(url);
    Uint8List? data = await XNZCacheManager().getCache(normalizedUrl);
    if (data != null) {
      return data;
    }

    final completer = Completer<Uint8List?>();
    Object? downloadError;
    final task = XNZImageDownloaderTask(
      url: normalizedUrl,
      onComplete: (bytes) => completer.complete(bytes),
      onError: (error) {
        downloadError = error;
        completer.complete(null);
      },
    );
    XNZImageDownloader().start(task);

    data = await completer.future;
    if (data == null) {
      throw Exception(
        'Failed to load AVIF image data: $normalizedUrl, error: ${downloadError ?? "unknown"}',
      );
    }
    if (data.isEmpty) {
      throw const FormatException('Invalid AVIF bytes: empty image data.');
    }
    return data;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XNZAvifNetworkImageProvider &&
          runtimeType == other.runtimeType &&
          imageUrl == other.imageUrl &&
          scale == other.scale &&
          avifOverrideDurationMs == other.avifOverrideDurationMs;

  @override
  int get hashCode => Object.hash(imageUrl, scale, avifOverrideDurationMs);
}

class XNZAvifMemoryImageProvider extends XNZMemoryAvifImage {
  const XNZAvifMemoryImageProvider(
    super.bytes, {
    super.scale = 1.0,
    super.avifOverrideDurationMs = -1,
  });
}

class XNZAvifFileImageProvider extends ImageProvider<XNZAvifFileImageProvider> {
  const XNZAvifFileImageProvider(
    this.file, {
    this.scale = 1.0,
    this.avifOverrideDurationMs = -1,
  });

  final File file;
  final double scale;
  final int? avifOverrideDurationMs;

  @override
  Future<XNZAvifFileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<XNZAvifFileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    XNZAvifFileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return AvifImageStreamCompleter(
      key: key,
      codec: _loadAsync(key),
      scale: key.scale,
      debugLabel: key.file.path,
      informationCollector: () sync* {
        yield ErrorDescription(
            'XNZAvifFileImageProvider Image provider: $this');
      },
    );
  }

  Future<AvifCodec> _loadAsync(XNZAvifFileImageProvider key) async {
    final data = await key.file.readAsBytes();
    return loadMemoryAvifCodec(
      data,
      codecKey: hashCode,
      avifOverrideDurationMs: avifOverrideDurationMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XNZAvifFileImageProvider &&
          runtimeType == other.runtimeType &&
          file.path == other.file.path &&
          scale == other.scale &&
          avifOverrideDurationMs == other.avifOverrideDurationMs;

  @override
  int get hashCode => Object.hash(file.path, scale, avifOverrideDurationMs);
}

class XNZAvifAssetImageProvider
    extends ImageProvider<XNZAvifAssetImageProvider> {
  const XNZAvifAssetImageProvider(
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
  Future<XNZAvifAssetImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<XNZAvifAssetImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    XNZAvifAssetImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return AvifImageStreamCompleter(
      key: key,
      codec: _loadAsync(key),
      scale: key.scale,
      debugLabel: key._resolvedAssetName,
      informationCollector: () sync* {
        yield ErrorDescription(
          'XNZAvifAssetImageProvider Image provider: $this',
        );
      },
    );
  }

  Future<AvifCodec> _loadAsync(XNZAvifAssetImageProvider key) async {
    final data = await _loadAssetData(key);
    return loadMemoryAvifCodec(
      data,
      codecKey: hashCode,
      avifOverrideDurationMs: avifOverrideDurationMs,
    );
  }

  Future<Uint8List> _loadAssetData(XNZAvifAssetImageProvider key) async {
    final assetBundle = key.bundle ?? rootBundle;
    final byteData = await assetBundle.load(key._resolvedAssetName);
    return byteData.buffer.asUint8List();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XNZAvifAssetImageProvider &&
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

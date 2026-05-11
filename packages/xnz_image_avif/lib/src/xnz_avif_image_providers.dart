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
    this.headers,
    this.cacheKeyStrategy = XNZCacheKeyStrategy.urlOnly,
    this.scale = 1.0,
    this.avifOverrideDurationMs = -1,
  }) : imageUrl = _normalizeNetworkUrl(imageUrl);

  final String imageUrl;

  /// Optional HTTP headers for AVIF network requests.
  final Map<String, String>? headers;

  /// Cache key generation strategy.
  final XNZCacheKeyStrategy cacheKeyStrategy;
  final double scale;
  final int? avifOverrideDurationMs;

  XNZUrlRequest get _request => XNZUrlRequest(
        imageUrl,
        headers: headers,
        cacheKeyStrategy: cacheKeyStrategy,
      );

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
    final cancelSignal = Completer<void>();
    final streamCompleter = AvifImageStreamCompleter(
      key: key,
      codec: _loadAsync(
        key,
        cancelSignal: cancelSignal,
      ),
      scale: key.scale,
      debugLabel: key.imageUrl,
      informationCollector: () sync* {
        yield ErrorDescription(
          'XNZAvifNetworkImageProvider Image provider: $this',
        );
      },
    );
    streamCompleter.addOnLastListenerRemovedCallback(() {
      if (!cancelSignal.isCompleted) {
        cancelSignal.complete();
      }
    });
    return streamCompleter;
  }

  Future<AvifCodec> _loadAsync(
    XNZAvifNetworkImageProvider key, {
    required Completer<void> cancelSignal,
  }) async {
    final request = key._request;
    Uint8List bytes = await _loadImageData(
      request,
      useCache: true,
      cancelSignal: cancelSignal,
    );
    try {
      final codec = await loadMemoryAvifCodec(
        bytes,
        codecKey: xnzNextAvifCodecKey(),
        avifOverrideDurationMs: avifOverrideDurationMs,
      );
      unawaited(XNZCacheManager().setCache(request, bytes));
      return codec;
    } catch (_) {
      await XNZCacheManager().removeCache(request);
    }

    bytes = await _loadImageData(
      request,
      useCache: false,
      cancelSignal: cancelSignal,
    );
    final codec = await loadMemoryAvifCodec(
      bytes,
      codecKey: xnzNextAvifCodecKey(),
      avifOverrideDurationMs: avifOverrideDurationMs,
    );
    unawaited(XNZCacheManager().setCache(request, bytes));
    return codec;
  }

  Future<Uint8List> _loadImageData(
    XNZUrlRequest request, {
    required bool useCache,
    required Completer<void> cancelSignal,
  }) async {
    if (cancelSignal.isCompleted) {
      throw _XNZAvifImageLoadCanceled(request.url);
    }

    Uint8List? data;
    if (useCache) {
      data = await XNZCacheManager().getCache(request);
      if (data != null) {
        return data;
      }
    }

    final completer = Completer<Uint8List?>();
    Object? downloadError;
    final task = XNZImageDownloaderTask(
      request: request,
      onComplete: (bytes) {
        if (!completer.isCompleted) {
          completer.complete(bytes);
        }
      },
      onError: (error) {
        downloadError = error;
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );
    XNZImageDownloader().start(task);

    data = await Future.any<Uint8List?>(<Future<Uint8List?>>[
      completer.future,
      cancelSignal.future.then((_) {
        XNZImageDownloader().cancel(task);
        return null;
      }),
    ]);
    if (data == null) {
      if (cancelSignal.isCompleted) {
        throw _XNZAvifImageLoadCanceled(request.url);
      }
      throw Exception(
        'Failed to load AVIF image data: ${request.url}, error: ${downloadError ?? "unknown"}',
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
          _request == other._request &&
          scale == other.scale &&
          avifOverrideDurationMs == other.avifOverrideDurationMs;

  @override
  int get hashCode => Object.hash(
        _request,
        scale,
        avifOverrideDurationMs,
      );
}

class _XNZAvifImageLoadCanceled implements Exception {
  const _XNZAvifImageLoadCanceled(this.url);

  final String url;

  @override
  String toString() => 'AVIF image load canceled: $url';
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
      codecKey: xnzNextAvifCodecKey(),
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
      codecKey: xnzNextAvifCodecKey(),
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

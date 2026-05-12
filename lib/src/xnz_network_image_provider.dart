import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xnz_image_core/xnz_image_core.dart';
import 'package:xnz_image/src/xnz_image_decode_utils.dart';
import 'package:xnz_image/src/xnz_proxy_image_stream_completer.dart';

class XNZNetworkImageProvider extends ImageProvider<XNZNetworkImageProvider> {
  static final Expando<ImageConfiguration> _lastImageConfigurations =
      Expando<ImageConfiguration>('xnz_network_image_configuration');

  XNZNetworkImageProvider(
    String imageUrl, {
    this.headers,
    this.cacheKeyStrategy = XNZCacheKeyStrategy.urlOnly,
    this.scale = 1.0,
    this.avifOverrideDurationMs = -1,
  }) : imageUrl = xnzNormalizeNetworkUrl(imageUrl);

  final String imageUrl;

  /// Optional HTTP headers for the network request.
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

  void _setCacheSafely(Uint8List data) {
    final request = _request;
    unawaited(
      XNZCacheManager().setCache(request, data).catchError((Object error) {
        XNZImageLogs.event(
          'XNZNetworkImageProvider',
          'cache_set_failed',
          fields: {
            'url': request.url,
            'error': error,
          },
        );
      }),
    );
  }

  @override
  Future<XNZNetworkImageProvider> obtainKey(ImageConfiguration configuration) {
    XNZImageLogs.event('XNZNetworkImageProvider', 'obtain_key', fields: {
      'url': imageUrl,
    });
    _lastImageConfigurations[this] = configuration;
    return SynchronousFuture<XNZNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    XNZNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final request = XNZImageRequest(
      sourceType: XNZImageSourceType.network,
      uri: Uri.tryParse(key.imageUrl),
      options: <String, Object?>{
        'headers': key.headers,
        'cacheKeyStrategy': key.cacheKeyStrategy,
        'scale': key.scale,
        'avifOverrideDurationMs': key.avifOverrideDurationMs,
      },
    );
    final resolved = XNZImageRegistry.instance.resolve(request);
    if (resolved?.provider != null) {
      return XNZProxyImageStreamCompleter(
        provider: resolved!.provider!,
        configuration:
            _lastImageConfigurations[key] ?? ImageConfiguration.empty,
        debugLabel: key.imageUrl,
        informationCollector: () sync* {
          yield ErrorDescription(
            'XNZNetworkImageProvider Image provider: $this',
          );
        },
      );
    }

    final cancelSignal = Completer<void>();
    final streamCompleter = MultiFrameImageStreamCompleter(
      codec: _loadAsync(
        key,
        decode,
        cancelSignal: cancelSignal,
      ),
      scale: key.scale,
      informationCollector: () sync* {
        yield ErrorDescription('XNZNetworkImageProvider Image provider: $this');
      },
    );
    streamCompleter.addOnLastListenerRemovedCallback(() {
      if (!cancelSignal.isCompleted) {
        cancelSignal.complete();
      }
    });
    return streamCompleter;
  }

  Future<ui.Codec> _loadAsync(
      XNZNetworkImageProvider key, ImageDecoderCallback decode,
      {required Completer<void> cancelSignal}) async {
    XNZImageLogs.event('XNZNetworkImageProvider', 'load_async', fields: {
      'url': key.imageUrl,
    });
    final request = key._request;
    Uint8List data = await _loadImageData(
      request,
      useCache: true,
      cancelSignal: cancelSignal,
    );
    try {
      final codec = await XNZImageDecodeUtils.decodeChecked(
        data: data,
        decode: decode,
        source: key.imageUrl,
        logModule: 'XNZNetworkImageProvider',
      );
      _setCacheSafely(data);
      return codec;
    } catch (firstError) {
      XNZImageLogs.event('XNZNetworkImageProvider', 'decode_failed_retry',
          fields: {
            'url': key.imageUrl,
            'error': firstError,
          });
      await XNZCacheManager().removeCache(request);
    }

    data = await _loadImageData(
      request,
      useCache: false,
      cancelSignal: cancelSignal,
    );
    try {
      final codec = await XNZImageDecodeUtils.decodeChecked(
        data: data,
        decode: decode,
        source: key.imageUrl,
        logModule: 'XNZNetworkImageProvider',
      );
      _setCacheSafely(data);
      return codec;
    } catch (retryError) {
      XNZImageLogs.event('XNZNetworkImageProvider', 'decode_failed_final',
          fields: {
            'url': key.imageUrl,
            'error': retryError,
          });
      throw StateError(
        'Invalid image data after retry: ${key.imageUrl}, '
        'bytes:${data.length}, reason:$retryError',
      );
    }
  }

  Future<Uint8List> _loadImageData(
    XNZUrlRequest request, {
    required bool useCache,
    required Completer<void> cancelSignal,
  }) async {
    if (cancelSignal.isCompleted) {
      throw _XNZImageLoadCanceled(request.url);
    }

    Uint8List? data;
    if (useCache) {
      data = await XNZCacheManager().getCache(request);
      if (data != null) {
        XNZImageLogs.event('XNZNetworkImageProvider', 'load_data_cache_hit',
            fields: {
              'url': request.url,
              'requestKey': request.requestKey,
            });
        return data;
      }
    }
    XNZImageLogs.event('XNZNetworkImageProvider', 'load_data_download_start',
        fields: {
          'url': request.url,
          'requestKey': request.requestKey,
        });
    final completer = Completer<Uint8List?>();
    Object? downloadError;
    final task = XNZImageDownloaderTask(
      request: request,
      onComplete: (bytes) {
        if (!completer.isCompleted) {
          completer.complete(bytes);
        }
        XNZImageLogs.event(
            'XNZNetworkImageProvider', 'load_data_download_complete',
            fields: {
              'url': request.url,
              'requestKey': request.requestKey,
              'bytes': bytes.length,
            });
      },
      onError: (error) {
        downloadError = error;
        XNZImageLogs.event(
            'XNZNetworkImageProvider', 'load_data_download_failed',
            fields: {
              'url': request.url,
              'requestKey': request.requestKey,
              'error': error,
            });
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );
    try {
      XNZImageDownloader().start(task);
    } catch (error) {
      throw Exception(
        'Failed to start image download: ${request.url}, error: $error',
      );
    }
    data = await Future.any<Uint8List?>(<Future<Uint8List?>>[
      completer.future,
      cancelSignal.future.then((_) {
        XNZImageDownloader().cancel(task);
        return null;
      }),
    ]);
    if (data == null) {
      if (cancelSignal.isCompleted) {
        throw _XNZImageLoadCanceled(request.url);
      }
      throw Exception(
        'Failed to load image data: ${request.url}, error: ${downloadError ?? "unknown"}',
      );
    }
    return data;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XNZNetworkImageProvider &&
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

class _XNZImageLoadCanceled implements Exception {
  const _XNZImageLoadCanceled(this.url);

  final String url;

  @override
  String toString() => 'Image load canceled: $url';
}

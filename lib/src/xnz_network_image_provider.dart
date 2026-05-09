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
    this.scale = 1.0,
    this.avifOverrideDurationMs = -1,
  }) : imageUrl = xnzNormalizeNetworkUrl(imageUrl);

  final String imageUrl;
  final double scale;
  final int? avifOverrideDurationMs;

  void _setCacheSafely(Uint8List data) {
    unawaited(
      XNZCacheManager().setCache(imageUrl, data).catchError((Object error) {
        XNZImageLogs.log(
          'XNZNetworkImageProvider',
          '_setCacheSafely 失败 url:$imageUrl error:$error',
        );
      }),
    );
  }

  @override
  Future<XNZNetworkImageProvider> obtainKey(ImageConfiguration configuration) {
    XNZImageLogs.log('XNZNetworkImageProvider', 'obtainKey');
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

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      informationCollector: () sync* {
        yield ErrorDescription('XNZNetworkImageProvider Image provider: $this');
      },
    );
  }

  Future<ui.Codec> _loadAsync(
    XNZNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    XNZImageLogs.log('XNZNetworkImageProvider', '_loadAsync');
    Uint8List data = await _loadImageData(key.imageUrl, useCache: true);
    try {
      final codec = await XNZImageDecodeUtils.decodeChecked(
        data: data,
        decode: decode,
        source: key.imageUrl,
      );
      _setCacheSafely(data);
      return codec;
    } catch (firstError) {
      XNZImageLogs.log(
        'XNZNetworkImageProvider',
        '_loadAsync-首次解码失败，清理缓存并重试, url:${key.imageUrl}, error:$firstError',
      );
      await XNZCacheManager().removeCache(key.imageUrl);
    }

    data = await _loadImageData(key.imageUrl, useCache: false);
    try {
      final codec = await XNZImageDecodeUtils.decodeChecked(
        data: data,
        decode: decode,
        source: key.imageUrl,
      );
      _setCacheSafely(data);
      return codec;
    } catch (retryError) {
      throw StateError(
        'Invalid image data after retry: ${key.imageUrl}, '
        'bytes:${data.length}, reason:$retryError',
      );
    }
  }

  Future<Uint8List> _loadImageData(
    String imageUrl, {
    required bool useCache,
  }) async {
    final normalizedUrl = xnzNormalizeNetworkUrl(imageUrl);
    Uint8List? data;
    if (useCache) {
      data = await XNZCacheManager().getCache(normalizedUrl);
      if (data != null) {
        XNZImageLogs.log(
          'XNZNetworkImageProvider',
          '_loadImageData-返回缓存对象',
        );
        return data;
      }
    }
    XNZImageLogs.log('XNZNetworkImageProvider', '_loadImageData-开始下载');
    final completer = Completer<Uint8List?>();
    Object? downloadError;
    final task = XNZImageDownloaderTask(
      url: normalizedUrl,
      onComplete: (bytes) {
        if (!completer.isCompleted) {
          completer.complete(bytes);
        }
        XNZImageLogs.log('XNZNetworkImageProvider', '_loadImageData-下载完成');
      },
      onError: (error) {
        downloadError = error;
        XNZImageLogs.log('XNZNetworkImageProvider', '_loadImageData-下载失败');
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );
    try {
      XNZImageDownloader().start(task);
    } catch (error) {
      throw Exception(
        'Failed to start image download: $normalizedUrl, error: $error',
      );
    }
    data = await completer.future;
    if (data == null) {
      throw Exception(
        'Failed to load image data: $normalizedUrl, error: ${downloadError ?? "unknown"}',
      );
    }
    return data;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XNZNetworkImageProvider &&
          runtimeType == other.runtimeType &&
          imageUrl == other.imageUrl &&
          scale == other.scale &&
          avifOverrideDurationMs == other.avifOverrideDurationMs;

  @override
  int get hashCode => Object.hash(imageUrl, scale, avifOverrideDurationMs);
}

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:xnz_image/src/xnz_cache_manager.dart';
import 'package:xnz_image/src/xnz_image_cache_logs.dart';
import 'package:xnz_image/src/xnz_image_downloader.dart';
import 'package:xnz_image/src/xnz_memory_avif_image_provider.dart';

class XNZNetworkImageProvider extends ImageProvider<XNZNetworkImageProvider> {
  final String imageUrl;
  final double scale;
  final int? avifOverrideDurationMs;

  XNZNetworkImageProvider(
    this.imageUrl, {
    this.scale = 1.0,
    this.avifOverrideDurationMs = -1,
  });

  @override
  Future<XNZNetworkImageProvider> obtainKey(ImageConfiguration configuration) {
    XNZNetworkImageLogs.log('XNZNetworkImageProvider', 'obtainKey');
    return SynchronousFuture<XNZNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      XNZNetworkImageProvider key, ImageDecoderCallback decode) {
    XNZNetworkImageLogs.log('XNZNetworkImageProvider', 'loadImage');
    if (_isLikelyAvifUrl(key.imageUrl)) {
      return AvifImageStreamCompleter(
        key: key,
        codec: _loadAvifAsync(key),
        scale: key.scale,
        debugLabel: key.imageUrl,
        informationCollector: () sync* {
          yield ErrorDescription(
              'XNZNetworkImageProvider Image provider: $this');
        },
      );
    }
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: key.scale,
      informationCollector: () sync* {
        yield ErrorDescription('XNZNetworkImageProvider Image provider: $this');
      },
    );
  }

  Future<ui.Codec> _loadAsync(XNZNetworkImageProvider key) async {
    XNZNetworkImageLogs.log('XNZNetworkImageProvider', '_loadAsync');
    final Uint8List data = await _loadImageData(key.imageUrl);
    unawaited(XNZCacheManager().setCache(key.imageUrl, data));
    return await ui.instantiateImageCodec(data);
  }

  Future<AvifCodec> _loadAvifAsync(XNZNetworkImageProvider key) async {
    XNZNetworkImageLogs.log('XNZNetworkImageProvider', '_loadAvifAsync');
    final Uint8List data = await _loadImageData(key.imageUrl);
    unawaited(XNZCacheManager().setCache(key.imageUrl, data));
    return loadMemoryAvifCodec(
      data,
      codecKey: hashCode,
      avifOverrideDurationMs: avifOverrideDurationMs,
    );
  }

  Future<Uint8List> _loadImageData(String imageUrl) async {
    Uint8List? data = await XNZCacheManager().getCache(imageUrl);
    if (data != null) {
      XNZNetworkImageLogs.log(
          'XNZNetworkImageProvider', '_loadImageData-返回缓存对象');
      return Future.value(data);
    }
    XNZNetworkImageLogs.log('XNZNetworkImageProvider', '_loadImageData-开始下载');
    Completer<Uint8List?> completer = Completer<Uint8List?>();
    Object? downloadError;
    XNZImageDownloaderTask task = XNZImageDownloaderTask(
      url: imageUrl,
      onComplete: (bytes) {
        completer.complete(bytes);
        XNZNetworkImageLogs.log(
            'XNZNetworkImageProvider', '_loadImageData-下载完成');
      },
      onError: (error) {
        downloadError = error;
        XNZNetworkImageLogs.log(
            'XNZNetworkImageProvider', '_loadImageData-下载失败');
        completer.complete(null);
      },
    );
    XNZImageDownloader().start(task);
    data = await completer.future;
    if (data == null) {
      throw Exception(
        'Failed to load image data: $imageUrl, error: ${downloadError ?? "unknown"}',
      );
    }
    return data;
  }

  bool _isLikelyAvifUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.avif') || path.endsWith('.avifs');
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

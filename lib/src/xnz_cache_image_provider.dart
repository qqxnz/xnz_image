import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:xnz_net_cache_image/src/xnz_cache_manager.dart';
import 'package:xnz_net_cache_image/src/xnz_image_cache_logs.dart';
import 'package:xnz_net_cache_image/src/xnz_image_downloader.dart';
import 'package:xnz_net_cache_image/src/xnz_memory_avif_image_provider.dart';

class XNZCacheImageProvider extends ImageProvider<XNZCacheImageProvider> {
  final String imageUrl;
  final double scale;
  final int? overrideDurationMs;

  XNZCacheImageProvider(
    this.imageUrl, {
    this.scale = 1.0,
    this.overrideDurationMs = -1,
  });

  @override
  Future<XNZCacheImageProvider> obtainKey(ImageConfiguration configuration) {
    XNZCacheImageLogs.log('XNZCacheImageProvider', 'obtainKey');
    return SynchronousFuture<XNZCacheImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      XNZCacheImageProvider key, ImageDecoderCallback decode) {
    XNZCacheImageLogs.log('XNZCacheImageProvider', 'loadImage');
    if (_isLikelyAvifUrl(key.imageUrl)) {
      return AvifImageStreamCompleter(
        key: key,
        codec: _loadAvifAsync(key),
        scale: key.scale,
        debugLabel: key.imageUrl,
        informationCollector: () sync* {
          yield ErrorDescription('XNZCacheImageProvider Image provider: $this');
        },
      );
    }
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: key.scale,
      informationCollector: () sync* {
        yield ErrorDescription('XNZCacheImageProvider Image provider: $this');
      },
    );
  }

  Future<ui.Codec> _loadAsync(XNZCacheImageProvider key) async {
    XNZCacheImageLogs.log('XNZCacheImageProvider', '_loadAsync');
    final Uint8List data = await _loadImageData(key.imageUrl);
    XNZCacheManager().setCache(key.imageUrl, data);
    return await ui.instantiateImageCodec(data);
  }

  Future<AvifCodec> _loadAvifAsync(XNZCacheImageProvider key) async {
    XNZCacheImageLogs.log('XNZCacheImageProvider', '_loadAvifAsync');
    final Uint8List data = await _loadImageData(key.imageUrl);
    XNZCacheManager().setCache(key.imageUrl, data);
    return loadMemoryAvifCodec(
      data,
      codecKey: hashCode,
      overrideDurationMs: overrideDurationMs,
    );
  }

  Future<Uint8List> _loadImageData(String imageUrl) async {
    Uint8List? data = await XNZCacheManager().getCache(imageUrl);
    if (data != null) {
      XNZCacheImageLogs.log('XNZCacheImageProvider', '_loadImageData-返回缓存对象');
      return Future.value(data);
    }
    XNZCacheImageLogs.log('XNZCacheImageProvider', '_loadImageData-开始下载');
    Completer<Uint8List?> completer = Completer<Uint8List?>();
    Object? downloadError;
    XNZImageDownloaderTask task = XNZImageDownloaderTask(
      url: imageUrl,
      onComplete: (bytes) {
        completer.complete(bytes);
        XNZCacheImageLogs.log('XNZCacheImageProvider', '_loadImageData-下载完成');
      },
      onError: (error) {
        downloadError = error;
        XNZCacheImageLogs.log('XNZCacheImageProvider', '_loadImageData-下载失败');
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
      other is XNZCacheImageProvider &&
          runtimeType == other.runtimeType &&
          imageUrl == other.imageUrl;

  @override
  int get hashCode => imageUrl.hashCode;
}

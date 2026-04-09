import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

import 'package:xnz_image/src/xnz_proxy_image_stream_completer.dart';

class XNZNetworkImageProvider extends ImageProvider<XNZNetworkImageProvider> {
  XNZNetworkImageProvider(
    this.imageUrl, {
    this.scale = 1.0,
    this.avifOverrideDurationMs = -1,
  });

  final String imageUrl;
  final double scale;
  final int? avifOverrideDurationMs;

  @override
  Future<XNZNetworkImageProvider> obtainKey(ImageConfiguration configuration) {
    XNZNetworkImageLogs.log('XNZNetworkImageProvider', 'obtainKey');
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
        debugLabel: key.imageUrl,
        informationCollector: () sync* {
          yield ErrorDescription(
            'XNZNetworkImageProvider Image provider: $this',
          );
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
    return ui.instantiateImageCodec(data);
  }

  Future<Uint8List> _loadImageData(String imageUrl) async {
    Uint8List? data = await XNZCacheManager().getCache(imageUrl);
    if (data != null) {
      XNZNetworkImageLogs.log(
        'XNZNetworkImageProvider',
        '_loadImageData-返回缓存对象',
      );
      return data;
    }
    XNZNetworkImageLogs.log('XNZNetworkImageProvider', '_loadImageData-开始下载');
    final completer = Completer<Uint8List?>();
    Object? downloadError;
    final task = XNZImageDownloaderTask(
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

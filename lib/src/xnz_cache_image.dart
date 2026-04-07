import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_avif_platform_interface/flutter_avif_platform_interface.dart'
    as avif_platform;
import 'package:xnz_net_cache_image/src/xnz_cache.dart';
import 'package:xnz_net_cache_image/src/xnz_image_cache_logs.dart';
import 'package:xnz_net_cache_image/src/xnz_image_downloader.dart';
import 'package:xnz_net_cache_image/src/xnz_memory_avif_image_provider.dart';

enum XNZCacheImageDonwloadStatus {
  none,
  downloading,
  complete,
  failed,
}

typedef ImageWidgetBuilder = Widget Function(
  BuildContext context,
  ImageProvider imageProvider,
);

class XNZCacheImage extends StatefulWidget {
  /// 下载图片并缓存
  static Future<Uint8List?> downloadImageData(String imageUrl) async {
    Completer<Uint8List?> completer = Completer<Uint8List?>();

    XNZImageDownloaderTask task = XNZImageDownloaderTask(
      url: imageUrl,
      onComplete: (bytes) {
        XNZCache().setCache(imageUrl, bytes);
        completer.complete(bytes);
        XNZCacheImageLogs.log(
            'XNZCacheImageProvider', 'downloadImageData- $imageUrl 下载完成');
      },
      onError: (error) {
        XNZCacheImageLogs.log(
            'XNZCacheImageProvider', 'downloadImageData-  $imageUrl 下载失败');
        completer.complete(null);
      },
    );

    XNZImageDownloader().start(task);
    return completer.future;
  }

  final String url;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit? fit;
  final Widget? placeholder;
  final ImageWidgetBuilder? imageBuilder;
  final Widget Function(double progress)? progressIndicatorBuilder;
  final Widget Function(String url, dynamic error)? loadFailedBuilder;

  /// 各类超时时间（毫秒）
  final Duration? connectTimeout;
  final Duration? sendTimeout;
  final Duration? receiveTimeout;

  /// 覆盖 AVIF 动图总时长（毫秒），`-1` 表示使用图片原始时长。
  ///
  /// 仅在 AVIF 且使用 `XNZMemoryAvifImage` 解码路径时生效。
  final int? overrideDurationMs;

  const XNZCacheImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.color,
    this.fit,
    this.placeholder,
    this.imageBuilder,
    this.progressIndicatorBuilder,
    this.loadFailedBuilder,
    this.connectTimeout,
    this.sendTimeout,
    this.receiveTimeout,
    this.overrideDurationMs = -1,
  });

  @override
  State<StatefulWidget> createState() => StateXNZCacheImage();
}

class StateXNZCacheImage extends State<XNZCacheImage> {
  XNZCacheImageDonwloadStatus _status = XNZCacheImageDonwloadStatus.none;

  Uint8List? _imageData;
  dynamic _error;
  XNZImageDownloaderTask? _task;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant XNZCacheImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      XNZCacheImageLogs.log('XNZCacheImage',
          'didUpdateWidget url变化 ${oldWidget.url} -> ${widget.url}');
      _cancelDownload();
      _status = XNZCacheImageDonwloadStatus.none;
      _imageData = null;
      _error = null;
      _loadImage();
    }
  }

  @override
  void dispose() {
    XNZCacheImageLogs.log('XNZCacheImage', '-dispose ${widget.url}');
    _cancelDownload();
    super.dispose();
  }

  void _cancelDownload() {
    if (_task != null) {
      XNZImageDownloader().cancel(_task!);
      _task = null;
    }
  }

  void _loadImage() async {
    /// 1️⃣ 内存缓存（同步）
    final memoryData = XNZCache().getMemoryCache(widget.url);
    if (memoryData != null) {
      XNZCacheImageLogs.log('XNZCacheImage', '内存缓存命中 ${widget.url}');
      setState(() {
        _imageData = memoryData;
        _status = XNZCacheImageDonwloadStatus.complete;
      });
      return;
    }

    /// 2️⃣ 硬盘缓存（异步，但不提前 setState）
    final diskData = await XNZCache().getDiskCache(widget.url);
    if (!mounted) return;

    if (diskData != null) {
      XNZCacheImageLogs.log('XNZCacheImage', '硬盘缓存命中 ${widget.url}');
      setState(() {
        _imageData = diskData;
        _status = XNZCacheImageDonwloadStatus.complete;
      });
      return;
    }

    /// 3️⃣ 真正需要下载，才进入 downloading
    setState(() {
      _status = XNZCacheImageDonwloadStatus.downloading;
      _error = null;
    });

    _task = XNZImageDownloaderTask(
      url: widget.url,
      onReceiveProgress: (count, total) {
        if (mounted && widget.progressIndicatorBuilder != null) {
          setState(() {}); // 刷新进度
        }
      },
      onComplete: (bytes) {
        if (!mounted) return;
        XNZCache().setCache(widget.url, bytes);
        setState(() {
          _imageData = bytes;
          _status = XNZCacheImageDonwloadStatus.complete;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _status = XNZCacheImageDonwloadStatus.failed;
          _error = error;
        });
      },
      connectTimeout: widget.connectTimeout,
      sendTimeout: widget.sendTimeout,
      receiveTimeout: widget.receiveTimeout,
    );

    XNZImageDownloader().start(_task!);
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case XNZCacheImageDonwloadStatus.none:
      case XNZCacheImageDonwloadStatus.downloading:
        if (widget.progressIndicatorBuilder != null && _task != null) {
          final progress = _task!.total > 0 ? _task!.count / _task!.total : 0.0;
          return widget.progressIndicatorBuilder!(progress);
        }
        return widget.placeholder ??
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.transparent,
            );

      case XNZCacheImageDonwloadStatus.complete:
        final bytes = _imageData!;
        final isAvif = isAvifBytes(bytes);
        final provider = isAvif
            ? (avif_platform.FlutterAvifPlatform.useNativeDecoder
                ? MemoryImage(bytes) as ImageProvider
                : XNZMemoryAvifImage(
                    bytes,
                    overrideDurationMs: widget.overrideDurationMs,
                  ))
            : MemoryImage(bytes);
        if (widget.imageBuilder != null) {
          return widget.imageBuilder!(context, provider);
        }
        return Image(
          image: provider,
          width: widget.width,
          height: widget.height,
          color: widget.color,
          fit: widget.fit,
        );

      case XNZCacheImageDonwloadStatus.failed:
        if (widget.loadFailedBuilder != null) {
          return widget.loadFailedBuilder!(widget.url, _error);
        }
        return widget.placeholder ??
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.transparent,
            );
    }
  }
}

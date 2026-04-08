import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_avif_platform_interface/flutter_avif_platform_interface.dart'
    as avif_platform;
import 'package:xnz_net_cache_image/src/xnz_cache_manager.dart';
import 'package:xnz_net_cache_image/src/xnz_image_cache_logs.dart';
import 'package:xnz_net_cache_image/src/xnz_image_downloader.dart';
import 'package:xnz_net_cache_image/src/xnz_memory_avif_image_provider.dart';

enum XNZNetworkImageDonwloadStatus {
  none,
  downloading,
  complete,
  failed,
}

typedef ImageWidgetBuilder = Widget Function(
  BuildContext context,
  ImageProvider imageProvider,
);

class XNZNetworkImage extends StatefulWidget {
  final String imageUrl;
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

  const XNZNetworkImage({
    super.key,
    required this.imageUrl,
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
  State<StatefulWidget> createState() => StateXNZNetworkImage();
}

class StateXNZNetworkImage extends State<XNZNetworkImage> {
  XNZNetworkImageDonwloadStatus _status = XNZNetworkImageDonwloadStatus.none;

  Uint8List? _imageData;
  dynamic _error;
  XNZImageDownloaderTask? _task;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _status = XNZNetworkImageDonwloadStatus.failed;
      _error = UnsupportedError(
        'XNZNetworkImage does not support the web platform.',
      );
      return;
    }
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant XNZNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      XNZNetworkImageLogs.log('XNZNetworkImage',
          'didUpdateWidget url变化 ${oldWidget.imageUrl} -> ${widget.imageUrl}');
      _cancelDownload();
      _status = XNZNetworkImageDonwloadStatus.none;
      _imageData = null;
      _error = null;
      _loadImage();
    }
  }

  @override
  void dispose() {
    XNZNetworkImageLogs.log('XNZNetworkImage', '-dispose ${widget.imageUrl}');
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
    final memoryData = XNZCacheManager().getMemoryCache(widget.imageUrl);
    if (memoryData != null) {
      XNZNetworkImageLogs.log('XNZNetworkImage', '内存缓存命中 ${widget.imageUrl}');
      setState(() {
        _imageData = memoryData;
        _status = XNZNetworkImageDonwloadStatus.complete;
      });
      return;
    }

    /// 2️⃣ 硬盘缓存（异步，但不提前 setState）
    final diskData = await XNZCacheManager().getDiskCache(widget.imageUrl);
    if (!mounted) return;

    if (diskData != null) {
      XNZNetworkImageLogs.log('XNZNetworkImage', '硬盘缓存命中 ${widget.imageUrl}');
      setState(() {
        _imageData = diskData;
        _status = XNZNetworkImageDonwloadStatus.complete;
      });
      return;
    }

    /// 3️⃣ 真正需要下载，才进入 downloading
    setState(() {
      _status = XNZNetworkImageDonwloadStatus.downloading;
      _error = null;
    });

    _task = XNZImageDownloaderTask(
      url: widget.imageUrl,
      onReceiveProgress: (count, total) {
        if (mounted && widget.progressIndicatorBuilder != null) {
          setState(() {}); // 刷新进度
        }
      },
      onComplete: (bytes) {
        if (!mounted) return;
        XNZCacheManager().setCache(widget.imageUrl, bytes);
        setState(() {
          _imageData = bytes;
          _status = XNZNetworkImageDonwloadStatus.complete;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _status = XNZNetworkImageDonwloadStatus.failed;
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
      case XNZNetworkImageDonwloadStatus.none:
      case XNZNetworkImageDonwloadStatus.downloading:
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

      case XNZNetworkImageDonwloadStatus.complete:
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

      case XNZNetworkImageDonwloadStatus.failed:
        if (widget.loadFailedBuilder != null) {
          return widget.loadFailedBuilder!(widget.imageUrl, _error);
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

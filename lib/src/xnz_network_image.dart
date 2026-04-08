import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xnz_net_cache_image/src/xnz_cache_manager.dart';
import 'package:xnz_net_cache_image/src/xnz_image_cache_logs.dart';
import 'package:xnz_net_cache_image/src/xnz_image_downloader.dart';
import 'package:xnz_net_cache_image/src/xnz_memory_image_provider.dart';

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
  final int? avifOverrideDurationMs;

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
    this.avifOverrideDurationMs = -1,
  });

  @override
  State<StatefulWidget> createState() => StateXNZNetworkImage();
}

class StateXNZNetworkImage extends State<XNZNetworkImage> {
  static const Duration _progressUpdateInterval = Duration(milliseconds: 100);
  static const double _progressDeltaThreshold = 0.01;

  XNZNetworkImageDonwloadStatus _status = XNZNetworkImageDonwloadStatus.none;

  Uint8List? _imageData;
  dynamic _error;
  XNZImageDownloaderTask? _task;
  int _requestVersion = 0;
  DateTime? _lastProgressUpdateAt;
  double _lastProgressValue = -1;

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

  bool _isActiveRequest(int requestVersion, String requestUrl) {
    return mounted &&
        requestVersion == _requestVersion &&
        requestUrl == widget.imageUrl;
  }

  bool _shouldRebuildForProgress(int count, int total) {
    final progress = total > 0 ? count / total : 0.0;
    final now = DateTime.now();
    final intervalPassed = _lastProgressUpdateAt == null ||
        now.difference(_lastProgressUpdateAt!) >= _progressUpdateInterval;
    final deltaPassed = _lastProgressValue < 0 ||
        (progress - _lastProgressValue).abs() >= _progressDeltaThreshold;
    final isFinalProgress = total > 0 && count >= total;

    if (intervalPassed || deltaPassed || isFinalProgress) {
      _lastProgressUpdateAt = now;
      _lastProgressValue = progress;
      return true;
    }
    return false;
  }

  void _loadImage() async {
    final requestVersion = ++_requestVersion;
    final requestUrl = widget.imageUrl;

    /// 1️⃣ 内存缓存（同步）
    final memoryData = XNZCacheManager().getMemoryCache(requestUrl);
    if (memoryData != null) {
      XNZNetworkImageLogs.log('XNZNetworkImage', '内存缓存命中 $requestUrl');
      if (!_isActiveRequest(requestVersion, requestUrl)) return;
      setState(() {
        _imageData = memoryData;
        _status = XNZNetworkImageDonwloadStatus.complete;
      });
      return;
    }

    /// 2️⃣ 硬盘缓存（异步，但不提前 setState）
    final diskData = await XNZCacheManager().getDiskCache(requestUrl);
    if (!_isActiveRequest(requestVersion, requestUrl)) return;

    if (diskData != null) {
      XNZNetworkImageLogs.log('XNZNetworkImage', '硬盘缓存命中 $requestUrl');
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
      _lastProgressUpdateAt = null;
      _lastProgressValue = -1;
    });

    _task = XNZImageDownloaderTask(
      url: requestUrl,
      onReceiveProgress: (count, total) {
        if (_isActiveRequest(requestVersion, requestUrl) &&
            widget.progressIndicatorBuilder != null &&
            _shouldRebuildForProgress(count, total)) {
          setState(() {}); // 刷新进度
        }
      },
      onComplete: (bytes) {
        if (!_isActiveRequest(requestVersion, requestUrl)) return;
        unawaited(XNZCacheManager().setCache(requestUrl, bytes));
        setState(() {
          _imageData = bytes;
          _status = XNZNetworkImageDonwloadStatus.complete;
          _task = null;
          _lastProgressUpdateAt = null;
          _lastProgressValue = -1;
        });
      },
      onError: (error) {
        if (!_isActiveRequest(requestVersion, requestUrl)) return;
        setState(() {
          _status = XNZNetworkImageDonwloadStatus.failed;
          _error = error;
          _task = null;
          _lastProgressUpdateAt = null;
          _lastProgressValue = -1;
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
        final provider = XNZMemoryImageProvider(
          bytes,
          avifOverrideDurationMs: widget.avifOverrideDurationMs,
        );
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

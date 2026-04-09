import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

import 'package:xnz_image/src/xnz_memory_image_provider.dart';
import 'package:xnz_image/src/xnz_resolved_image.dart';

enum XNZNetworkImageDownloadStatus {
  none,
  downloading,
  complete,
  failed,
}

@Deprecated('Use XNZNetworkImageDownloadStatus instead.')
typedef XNZNetworkImageDonwloadStatus = XNZNetworkImageDownloadStatus;

class XNZNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit? fit;
  final Widget? placeholder;
  final XNZRenderBuilder? renderBuilder;
  final Widget Function(double progress)? progressIndicatorBuilder;
  final Widget Function(String url, dynamic error)? loadFailedBuilder;

  final Duration? connectTimeout;
  final Duration? sendTimeout;
  final Duration? receiveTimeout;

  final int? avifOverrideDurationMs;

  const XNZNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.color,
    this.fit,
    this.placeholder,
    this.renderBuilder,
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

  XNZNetworkImageDownloadStatus _status = XNZNetworkImageDownloadStatus.none;

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
      _status = XNZNetworkImageDownloadStatus.failed;
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
      XNZNetworkImageLogs.log(
        'XNZNetworkImage',
        'didUpdateWidget url变化 ${oldWidget.imageUrl} -> ${widget.imageUrl}',
      );
      _cancelDownload();
      _status = XNZNetworkImageDownloadStatus.none;
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

    final memoryData = XNZCacheManager().getMemoryCache(requestUrl);
    if (memoryData != null) {
      XNZNetworkImageLogs.log('XNZNetworkImage', '内存缓存命中 $requestUrl');
      if (!_isActiveRequest(requestVersion, requestUrl)) return;
      setState(() {
        _imageData = memoryData;
        _status = XNZNetworkImageDownloadStatus.complete;
      });
      return;
    }

    final diskData = await XNZCacheManager().getDiskCache(requestUrl);
    if (!_isActiveRequest(requestVersion, requestUrl)) return;

    if (diskData != null) {
      XNZNetworkImageLogs.log('XNZNetworkImage', '硬盘缓存命中 $requestUrl');
      setState(() {
        _imageData = diskData;
        _status = XNZNetworkImageDownloadStatus.complete;
      });
      return;
    }

    setState(() {
      _status = XNZNetworkImageDownloadStatus.downloading;
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
          setState(() {});
        }
      },
      onComplete: (bytes) {
        if (!_isActiveRequest(requestVersion, requestUrl)) return;
        unawaited(XNZCacheManager().setCache(requestUrl, bytes));
        setState(() {
          _imageData = bytes;
          _status = XNZNetworkImageDownloadStatus.complete;
          _task = null;
          _lastProgressUpdateAt = null;
          _lastProgressValue = -1;
        });
      },
      onError: (error) {
        if (!_isActiveRequest(requestVersion, requestUrl)) return;
        setState(() {
          _status = XNZNetworkImageDownloadStatus.failed;
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

  XNZResolvedImage _resolveImage(Uint8List bytes) {
    final request = XNZImageRequest(
      sourceType: XNZImageSourceType.network,
      uri: Uri.tryParse(widget.imageUrl),
      bytes: bytes,
      options: <String, Object?>{
        'width': widget.width,
        'height': widget.height,
        'fit': widget.fit,
        'color': widget.color,
        'scale': 1.0,
        'avifOverrideDurationMs': widget.avifOverrideDurationMs,
      },
    );
    final result = XNZImageRegistry.instance.resolve(request);
    if (result != null) {
      return XNZResolvedImage(
        kind: result.kind == XNZImageBuildKind.widget
            ? XNZResolvedKind.customWidget
            : XNZResolvedKind.bitmapProvider,
        provider: result.provider,
        widget: result.widget,
        format: result.format,
        meta: result.meta,
      );
    }

    return XNZResolvedImage(
      kind: XNZResolvedKind.bitmapProvider,
      provider: XNZMemoryImageProvider(
        bytes,
        avifOverrideDurationMs: widget.avifOverrideDurationMs,
      ),
      format: 'bitmap',
    );
  }

  Widget _buildResolved(BuildContext context, XNZResolvedImage resolved) {
    if (widget.renderBuilder != null) {
      return widget.renderBuilder!(context, resolved);
    }
    if (resolved.kind == XNZResolvedKind.customWidget) {
      return resolved.widget ?? const SizedBox.shrink();
    }

    final provider = resolved.provider!;

    return Image(
      image: provider,
      width: widget.width,
      height: widget.height,
      color: widget.color,
      fit: widget.fit,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case XNZNetworkImageDownloadStatus.none:
      case XNZNetworkImageDownloadStatus.downloading:
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
      case XNZNetworkImageDownloadStatus.complete:
        return _buildResolved(context, _resolveImage(_imageData!));
      case XNZNetworkImageDownloadStatus.failed:
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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

import 'package:xnz_image/src/xnz_memory_image_provider.dart';
import 'package:xnz_image/src/xnz_resolved_image.dart';

/// Download lifecycle states for [XNZNetworkImage].
enum XNZNetworkImageDownloadStatus {
  /// Initial state before loading starts.
  none,

  /// Image bytes are being downloaded.
  downloading,

  /// Image bytes were downloaded and can be rendered.
  complete,

  /// Download failed.
  failed,
}

@Deprecated(
  'Typo legacy alias. Use XNZNetworkImageDownloadStatus instead. '
  'This alias will be removed in next major release.',
)
typedef XNZNetworkImageDonwloadStatus = XNZNetworkImageDownloadStatus;

/// Stateful widget that downloads, caches, and renders a network image.
class XNZNetworkImage extends StatefulWidget {
  /// Remote image url.
  final String imageUrl;

  /// Target render width.
  final double? width;

  /// Target render height.
  final double? height;

  /// Optional color filter.
  final Color? color;

  /// Box fit for the rendered image.
  final BoxFit? fit;

  /// Placeholder widget shown while loading or when failing without callback.
  final Widget? placeholder;

  /// Optional render hook to wrap or replace the default rendered result.
  final XNZRenderBuilder? renderBuilder;

  /// Progress widget builder with value in range `0.0..1.0`.
  final Widget Function(double progress)? progressIndicatorBuilder;

  /// Error widget builder when download fails.
  final Widget Function(String url, dynamic error)? loadFailedBuilder;

  /// Optional HTTP send timeout.
  final Duration? sendTimeout;

  /// Optional HTTP receive timeout.
  final Duration? receiveTimeout;

  /// Optional HTTP headers.
  ///
  /// Use this for authenticated or tenant-scoped image endpoints.
  final Map<String, String>? headers;

  /// Cache key generation strategy.
  ///
  /// Defaults to [XNZCacheKeyStrategy.urlOnly].
  final XNZCacheKeyStrategy cacheKeyStrategy;

  /// Optional frame duration override used by AVIF decoders.
  final int? avifOverrideDurationMs;

  /// Creates an [XNZNetworkImage].
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
    this.sendTimeout,
    this.receiveTimeout,
    this.headers,
    this.cacheKeyStrategy = XNZCacheKeyStrategy.urlOnly,
    this.avifOverrideDurationMs = -1,
  });

  @override
  State<StatefulWidget> createState() => StateXNZNetworkImage();
}

/// State for [XNZNetworkImage].
class StateXNZNetworkImage extends State<XNZNetworkImage> {
  /// Creates [StateXNZNetworkImage].
  StateXNZNetworkImage();

  static const Duration _progressUpdateInterval = Duration(milliseconds: 100);
  static const double _progressDeltaThreshold = 0.01;

  XNZNetworkImageDownloadStatus _status = XNZNetworkImageDownloadStatus.none;

  Uint8List? _imageData;
  dynamic _error;
  XNZImageDownloaderTask? _task;
  int _requestVersion = 0;
  DateTime? _lastProgressUpdateAt;
  double _lastProgressValue = -1;
  XNZResolvedImage? _resolvedImageCache;
  Uint8List? _resolvedImageCacheBytes;
  String? _resolvedImageCacheUrl;
  double? _resolvedImageCacheWidth;
  double? _resolvedImageCacheHeight;
  Color? _resolvedImageCacheColor;
  BoxFit? _resolvedImageCacheFit;
  int? _resolvedImageCacheAvifOverrideDurationMs;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant XNZNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldReload(oldWidget)) {
      XNZImageLogs.log(
        'XNZNetworkImage',
        'didUpdateWidget 触发重载 ${oldWidget.imageUrl} -> ${widget.imageUrl}',
      );
      _cancelDownload();
      _status = XNZNetworkImageDownloadStatus.none;
      _imageData = null;
      _error = null;
      _clearResolvedCache();
      _loadImage();
    }
  }

  bool _shouldReload(XNZNetworkImage oldWidget) {
    final oldUrl = xnzNormalizeNetworkUrl(oldWidget.imageUrl);
    final newUrl = xnzNormalizeNetworkUrl(widget.imageUrl);
    return oldUrl != newUrl ||
        !mapEquals(oldWidget.headers, widget.headers) ||
        oldWidget.cacheKeyStrategy != widget.cacheKeyStrategy ||
        oldWidget.sendTimeout != widget.sendTimeout ||
        oldWidget.receiveTimeout != widget.receiveTimeout ||
        oldWidget.avifOverrideDurationMs != widget.avifOverrideDurationMs;
  }

  @override
  void dispose() {
    XNZImageLogs.log('XNZNetworkImage', '-dispose ${widget.imageUrl}');
    _cancelDownload();
    super.dispose();
  }

  void _cancelDownload() {
    if (_task != null) {
      XNZImageDownloader().cancel(_task!);
      _task = null;
    }
  }

  XNZUrlRequest _buildRequest() {
    return XNZUrlRequest(
      widget.imageUrl,
      headers: widget.headers,
      cacheKeyStrategy: widget.cacheKeyStrategy,
    );
  }

  void _setCacheSafely(XNZUrlRequest request, Uint8List bytes) {
    unawaited(
      XNZCacheManager().setCache(request, bytes).catchError((Object error) {
        XNZImageLogs.log(
          'XNZNetworkImage',
          '缓存写入失败 url:${request.url} error:$error',
        );
      }),
    );
  }

  void _clearResolvedCache() {
    _resolvedImageCache = null;
    _resolvedImageCacheBytes = null;
    _resolvedImageCacheUrl = null;
    _resolvedImageCacheWidth = null;
    _resolvedImageCacheHeight = null;
    _resolvedImageCacheColor = null;
    _resolvedImageCacheFit = null;
    _resolvedImageCacheAvifOverrideDurationMs = null;
  }

  bool _isActiveRequest(int requestVersion, String requestKey) {
    return mounted &&
        requestVersion == _requestVersion &&
        requestKey == _buildRequest().requestKey;
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
    final request = _buildRequest();
    final requestKey = request.requestKey;
    final normalizedUrl = request.url;

    if (normalizedUrl.isEmpty) {
      if (!_isActiveRequest(requestVersion, requestKey)) return;
      setState(() {
        _status = XNZNetworkImageDownloadStatus.failed;
        _error = ArgumentError.value(widget.imageUrl, 'imageUrl', 'is empty');
        _task = null;
        _clearResolvedCache();
      });
      return;
    }
    try {
      final memoryData = XNZCacheManager().getMemoryCache(request);
      if (memoryData != null) {
        XNZImageLogs.log('XNZNetworkImage', '内存缓存命中 $normalizedUrl');
        if (!_isActiveRequest(requestVersion, requestKey)) return;
        setState(() {
          _imageData = memoryData;
          _status = XNZNetworkImageDownloadStatus.complete;
          _clearResolvedCache();
        });
        return;
      }

      final diskData = await XNZCacheManager().getDiskCache(request);
      if (!_isActiveRequest(requestVersion, requestKey)) return;

      if (diskData != null) {
        XNZImageLogs.log('XNZNetworkImage', '硬盘缓存命中 $normalizedUrl');
        setState(() {
          _imageData = diskData;
          _status = XNZNetworkImageDownloadStatus.complete;
          _clearResolvedCache();
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
        request: request,
        onReceiveProgress: (count, total) {
          if (_isActiveRequest(requestVersion, requestKey) &&
              widget.progressIndicatorBuilder != null &&
              _shouldRebuildForProgress(count, total)) {
            setState(() {});
          }
        },
        onComplete: (bytes) {
          if (!_isActiveRequest(requestVersion, requestKey)) return;
          _setCacheSafely(request, bytes);
          setState(() {
            _imageData = bytes;
            _status = XNZNetworkImageDownloadStatus.complete;
            _task = null;
            _lastProgressUpdateAt = null;
            _lastProgressValue = -1;
            _clearResolvedCache();
          });
        },
        onError: (error) {
          if (!_isActiveRequest(requestVersion, requestKey)) return;
          setState(() {
            _status = XNZNetworkImageDownloadStatus.failed;
            _error = error;
            _task = null;
            _lastProgressUpdateAt = null;
            _lastProgressValue = -1;
            _clearResolvedCache();
          });
        },
        sendTimeout: widget.sendTimeout,
        receiveTimeout: widget.receiveTimeout,
      );

      XNZImageDownloader().start(_task!);
    } catch (error) {
      if (!_isActiveRequest(requestVersion, requestKey)) return;
      setState(() {
        _status = XNZNetworkImageDownloadStatus.failed;
        _error = error;
        _task = null;
        _lastProgressUpdateAt = null;
        _lastProgressValue = -1;
        _clearResolvedCache();
      });
    }
  }

  XNZResolvedImage _resolveImage(Uint8List bytes) {
    final requestUrl = _buildRequest();
    final request = XNZImageRequest(
      sourceType: XNZImageSourceType.network,
      uri: requestUrl.uri,
      bytes: bytes,
      options: <String, Object?>{
        'headers': widget.headers,
        'cacheKeyStrategy': widget.cacheKeyStrategy,
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

  Widget _defaultRender(XNZResolvedImage resolved) {
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

  Widget _buildResolved(BuildContext context, XNZResolvedImage resolved) {
    final child = _defaultRender(resolved);
    return xnzApplyRenderBuilder(
      context: context,
      child: child,
      renderBuilder: widget.renderBuilder,
    );
  }

  XNZResolvedImage _getResolvedImage(Uint8List bytes) {
    final requestKey = _buildRequest().requestKey;
    final canUseCache = _resolvedImageCache != null &&
        identical(_resolvedImageCacheBytes, bytes) &&
        _resolvedImageCacheUrl == requestKey &&
        _resolvedImageCacheWidth == widget.width &&
        _resolvedImageCacheHeight == widget.height &&
        _resolvedImageCacheColor == widget.color &&
        _resolvedImageCacheFit == widget.fit &&
        _resolvedImageCacheAvifOverrideDurationMs ==
            widget.avifOverrideDurationMs;
    if (canUseCache) {
      return _resolvedImageCache!;
    }

    final resolved = _resolveImage(bytes);
    _resolvedImageCache = resolved;
    _resolvedImageCacheBytes = bytes;
    _resolvedImageCacheUrl = requestKey;
    _resolvedImageCacheWidth = widget.width;
    _resolvedImageCacheHeight = widget.height;
    _resolvedImageCacheColor = widget.color;
    _resolvedImageCacheFit = widget.fit;
    _resolvedImageCacheAvifOverrideDurationMs = widget.avifOverrideDurationMs;
    return resolved;
  }

  Widget _buildEmptyPlaceholder() {
    if (widget.width == null && widget.height == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(width: widget.width, height: widget.height);
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
        return widget.placeholder ?? _buildEmptyPlaceholder();
      case XNZNetworkImageDownloadStatus.complete:
        return _buildResolved(context, _getResolvedImage(_imageData!));
      case XNZNetworkImageDownloadStatus.failed:
        if (widget.loadFailedBuilder != null) {
          return widget.loadFailedBuilder!(widget.imageUrl, _error);
        }
        return widget.placeholder ?? _buildEmptyPlaceholder();
    }
  }
}

import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:xnz_image_core/src/xnz_cache_manager.dart';
import 'package:xnz_image_core/src/xnz_image_cache_logs.dart';
import 'package:xnz_image_core/src/support/xnz_url_request.dart';

typedef XNZProgressCallback = void Function(int count, int total);

class XNZImageDownloader {
  static final XNZImageDownloader _singleton = XNZImageDownloader._internal();
  static final Map<String, Future<Uint8List?>> _inflightDownloads = {};

  /// 下载图片并缓存
  static Future<Uint8List?> downloadImageDataAndCache(
    XNZUrlRequest request,
  ) async {
    if (request.url.isEmpty) {
      XNZImageLogs.event(
        'XNZImageDownloader',
        'download_skip_empty_url',
      );
      return null;
    }

    // requestKey is used for in-flight de-duplication (URL + headers).
    // cacheKey behavior is controlled inside [request] separately.
    final requestKey = request.requestKey;
    final cacheManager = XNZCacheManager();
    final cachedData = await cacheManager.getCache(request);
    if (cachedData != null) {
      XNZImageLogs.event('XNZImageDownloader', 'download_cache_hit', fields: {
        'requestKey': requestKey,
      });
      return cachedData;
    }

    final inflight = _inflightDownloads[requestKey];
    if (inflight != null) {
      XNZImageLogs.event(
        'XNZImageDownloader',
        'download_reuse_inflight',
        fields: {
          'requestKey': requestKey,
        },
      );
      return inflight;
    }

    final completer = Completer<Uint8List?>();
    final future = completer.future.whenComplete(() {
      _inflightDownloads.remove(requestKey);
    });
    _inflightDownloads[requestKey] = future;

    final task = XNZImageDownloaderTask(
      request: request,
      onComplete: (bytes) {
        unawaited(cacheManager.setCache(request, bytes));
        if (!completer.isCompleted) {
          completer.complete(bytes);
        }
        XNZImageLogs.event('XNZImageDownloader', 'download_complete', fields: {
          'requestKey': requestKey,
        });
      },
      onError: (error) {
        XNZImageLogs.event('XNZImageDownloader', 'download_failed', fields: {
          'requestKey': requestKey,
          'error': error,
        });
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    try {
      XNZImageDownloader().start(task);
    } catch (e) {
      XNZImageLogs.event(
        'XNZImageDownloader',
        'download_start_failed',
        fields: {
          'requestKey': requestKey,
          'error': e,
        },
      );
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    return future;
  }

  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
    ),
  );
  final List<XNZImageDownloaderTask> tasks = [];
  final Map<String, _SharedDownload> _sharedDownloads = {};

  factory XNZImageDownloader() {
    return _singleton;
  }

  XNZImageDownloader._internal();

  void start(XNZImageDownloaderTask task) {
    tasks.add(task);
    final shared = _sharedDownloads[task.requestKey];
    if (shared != null) {
      shared.subscribers.add(task);
      if (shared.total > 0) {
        task.count = shared.count;
        task.total = shared.total;
        task.onReceiveProgress?.call(shared.count, shared.total);
      }
      XNZImageLogs.event('XNZImageDownloader', 'task_reuse_shared', fields: {
        'requestKey': task.requestKey,
      });
      return;
    }

    final newShared = _SharedDownload();
    newShared.subscribers.add(task);
    _sharedDownloads[task.requestKey] = newShared;

    XNZImageLogs.event('XNZImageDownloader', 'task_start', fields: {
      'requestKey': task.requestKey,
      'url': task.url,
    });
    dio.get<List<int>>(
      task.url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: task.headers,
        followRedirects: true,
        sendTimeout: task.sendTimeout,
        receiveTimeout: task.receiveTimeout,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
      onReceiveProgress: (int count, int total) {
        newShared.count = count;
        newShared.total = total;
        for (final subscriber
            in List<XNZImageDownloaderTask>.from(newShared.subscribers)) {
          subscriber.count = count;
          subscriber.total = total;
          subscriber.onReceiveProgress?.call(count, total);
        }
      },
      cancelToken: newShared.cancelToken,
    ).then((Response<List<int>> response) {
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw StateError('Image download returned empty bytes: ${task.url}');
      }
      Uint8List bytes = Uint8List.fromList(data);
      XNZImageLogs.event('XNZImageDownloader', 'task_complete', fields: {
        'requestKey': task.requestKey,
        'url': task.url,
        'bytes': bytes.length,
      });

      final subscribers =
          List<XNZImageDownloaderTask>.from(newShared.subscribers);
      for (final subscriber in subscribers) {
        subscriber.onComplete?.call(bytes);
        tasks.remove(subscriber);
      }
      _sharedDownloads.remove(task.requestKey);
    }).catchError((e) {
      XNZImageLogs.event('XNZImageDownloader', 'task_failed', fields: {
        'requestKey': task.requestKey,
        'url': task.url,
        'error': e,
      });

      final subscribers =
          List<XNZImageDownloaderTask>.from(newShared.subscribers);
      for (final subscriber in subscribers) {
        subscriber.onError?.call(e);
        tasks.remove(subscriber);
      }
      _sharedDownloads.remove(task.requestKey);
    });
  }

  void cancel(XNZImageDownloaderTask task) {
    task.cancel();
    tasks.remove(task);
    final shared = _sharedDownloads[task.requestKey];
    if (shared == null) return;

    shared.subscribers.remove(task);
    if (shared.subscribers.isEmpty) {
      shared.cancelToken.cancel('Canceled by user!');
      _sharedDownloads.remove(task.requestKey);
    }
  }

  void cancelAll() {
    for (var task in tasks) {
      task.cancel();
    }
    for (final shared in _sharedDownloads.values) {
      shared.cancelToken.cancel('Canceled by user!');
    }
    _sharedDownloads.clear();
    tasks.clear();
  }
}

class XNZImageDownloaderTask {
  final XNZUrlRequest request;
  final XNZProgressCallback? onReceiveProgress;
  final Function(Uint8List)? onComplete;
  final Function(dynamic)? onError;
  final CancelToken? cancelToken;

  /// 各类超时时间（毫秒）
  final Duration sendTimeout;
  final Duration receiveTimeout;

  int count = 0;
  int total = 0;

  String get url => request.url;

  Map<String, String>? get headers =>
      request.headers.isEmpty ? null : request.headers;

  String get requestKey => request.requestKey;

  XNZImageDownloaderTask({
    required this.request,
    required this.onComplete,
    required this.onError,
    this.onReceiveProgress,
    Duration? sendTimeout, // 发送超时
    Duration? receiveTimeout, // 接收超时
  })  : cancelToken = CancelToken(),
        sendTimeout = sendTimeout ?? const Duration(milliseconds: 5000),
        receiveTimeout = receiveTimeout ?? const Duration(seconds: 12);

  void cancel() {
    cancelToken?.cancel('Canceled by user!');
  }
}

class _SharedDownload {
  final CancelToken cancelToken = CancelToken();
  final List<XNZImageDownloaderTask> subscribers = [];
  int count = 0;
  int total = 0;
}

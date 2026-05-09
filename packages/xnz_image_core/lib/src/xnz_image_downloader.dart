import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:xnz_image_core/src/xnz_cache_manager.dart';
import 'package:xnz_image_core/src/xnz_image_cache_logs.dart';
import 'package:xnz_image_core/src/support/xnz_network_url.dart';

typedef XNZProgressCallback = void Function(int count, int total);

class XNZImageDownloader {
  static final XNZImageDownloader _singleton = XNZImageDownloader._internal();
  static final Map<String, Future<Uint8List?>> _inflightDownloads = {};

  static String _buildRequestKey(
    String imageUrl, {
    Map<String, String>? headers,
  }) {
    final normalizedUrl = xnzNormalizeNetworkUrl(imageUrl);
    if (headers == null || headers.isEmpty) {
      return normalizedUrl;
    }
    final normalized = headers.entries
        .map((entry) => MapEntry(entry.key.toLowerCase(), entry.value))
        .toList(growable: false)
      ..sort((a, b) {
        final keyCompare = a.key.compareTo(b.key);
        if (keyCompare != 0) {
          return keyCompare;
        }
        return a.value.compareTo(b.value);
      });
    final serialized =
        normalized.map((entry) => '${entry.key}:${entry.value}').join('|');
    return '$normalizedUrl|headers:$serialized';
  }

  /// 下载图片并缓存
  static Future<Uint8List?> downloadImageDataAndCache(
    String imageUrl, {
    Map<String, String>? headers,
  }) async {
    final normalizedUrl = xnzNormalizeNetworkUrl(imageUrl);
    if (normalizedUrl.isEmpty) {
      XNZImageLogs.log(
          'XNZImageDownloader', 'downloadImageDataAndCache empty image url');
      return null;
    }

    final requestKey = _buildRequestKey(normalizedUrl, headers: headers);
    final cacheManager = XNZCacheManager();
    final cachedData = await cacheManager.getCache(requestKey);
    if (cachedData != null) {
      XNZImageLogs.log('XNZImageDownloader',
          'downloadImageDataAndCache cache hit $requestKey');
      return cachedData;
    }

    final inflight = _inflightDownloads[requestKey];
    if (inflight != null) {
      XNZImageLogs.log('XNZImageDownloader',
          'downloadImageDataAndCache reuse inflight task $requestKey');
      return inflight;
    }

    final completer = Completer<Uint8List?>();
    final future = completer.future.whenComplete(() {
      _inflightDownloads.remove(requestKey);
    });
    _inflightDownloads[requestKey] = future;

    final task = XNZImageDownloaderTask(
      url: normalizedUrl,
      headers: headers,
      onComplete: (bytes) {
        unawaited(cacheManager.setCache(requestKey, bytes));
        if (!completer.isCompleted) {
          completer.complete(bytes);
        }
        XNZImageLogs.log(
            'XNZImageDownloader', 'downloadImageDataAndCache done $requestKey');
      },
      onError: (error) {
        XNZImageLogs.log('XNZImageDownloader',
            'downloadImageDataAndCache failed $requestKey, error: $error');
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    try {
      XNZImageDownloader().start(task);
    } catch (e) {
      XNZImageLogs.log('XNZImageDownloader',
          'downloadImageDataAndCache start failed $requestKey, error: $e');
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
      XNZImageLogs.log('XNZImageDownloader', '复用下载任务 ${task.requestKey}');
      return;
    }

    final newShared = _SharedDownload();
    newShared.subscribers.add(task);
    _sharedDownloads[task.requestKey] = newShared;

    XNZImageLogs.log('XNZImageDownloader', '开始下载 ${task.requestKey}');
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
      XNZImageLogs.log(
          'XNZImageDownloader', '下载完成 ${task.url}  length:${bytes.length}');

      final subscribers =
          List<XNZImageDownloaderTask>.from(newShared.subscribers);
      for (final subscriber in subscribers) {
        subscriber.onComplete?.call(bytes);
        tasks.remove(subscriber);
      }
      _sharedDownloads.remove(task.requestKey);
    }).catchError((e) {
      XNZImageLogs.log('XNZImageDownloader', '下载失败 ${task.url} e:$e');

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
  final String url;
  final Map<String, String>? headers;
  final XNZProgressCallback? onReceiveProgress;
  final Function(Uint8List)? onComplete;
  final Function(dynamic)? onError;
  final CancelToken? cancelToken;

  /// 各类超时时间（毫秒）
  final Duration sendTimeout;
  final Duration receiveTimeout;

  int count = 0;
  int total = 0;

  String get requestKey =>
      XNZImageDownloader._buildRequestKey(url, headers: headers);

  XNZImageDownloaderTask({
    required this.url,
    this.headers,
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

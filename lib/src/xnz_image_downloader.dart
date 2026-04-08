import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:xnz_net_cache_image/src/xnz_cache_manager.dart';
import 'package:xnz_net_cache_image/src/xnz_image_cache_logs.dart';

typedef XNZProgressCallback = void Function(int count, int total);

class XNZImageDownloader {
  static final XNZImageDownloader _singleton = XNZImageDownloader._internal();
  static final Map<String, Future<Uint8List?>> _inflightDownloads = {};

  /// 下载图片并缓存
  static Future<Uint8List?> downloadImageDataAndCache(String imageUrl) async {
    if (imageUrl.trim().isEmpty) {
      XNZNetworkImageLogs.log(
          'XNZImageDownloader', 'downloadImageDataAndCache empty image url');
      return null;
    }

    final cacheManager = XNZCacheManager();
    final cachedData = await cacheManager.getCache(imageUrl);
    if (cachedData != null) {
      XNZNetworkImageLogs.log('XNZImageDownloader',
          'downloadImageDataAndCache cache hit $imageUrl');
      return cachedData;
    }

    final inflight = _inflightDownloads[imageUrl];
    if (inflight != null) {
      XNZNetworkImageLogs.log('XNZImageDownloader',
          'downloadImageDataAndCache reuse inflight task $imageUrl');
      return inflight;
    }

    final completer = Completer<Uint8List?>();
    final future = completer.future.whenComplete(() {
      _inflightDownloads.remove(imageUrl);
    });
    _inflightDownloads[imageUrl] = future;

    final task = XNZImageDownloaderTask(
      url: imageUrl,
      onComplete: (bytes) {
        unawaited(cacheManager.setCache(imageUrl, bytes));
        if (!completer.isCompleted) {
          completer.complete(bytes);
        }
        XNZNetworkImageLogs.log(
            'XNZImageDownloader', 'downloadImageDataAndCache done $imageUrl');
      },
      onError: (error) {
        XNZNetworkImageLogs.log('XNZImageDownloader',
            'downloadImageDataAndCache failed $imageUrl, error: $error');
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    try {
      XNZImageDownloader().start(task);
    } catch (e) {
      XNZNetworkImageLogs.log('XNZImageDownloader',
          'downloadImageDataAndCache start failed $imageUrl, error: $e');
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    return future;
  }

  final Dio dio = Dio();
  final List<XNZImageDownloaderTask> tasks = [];
  final Map<String, _SharedDownload> _sharedDownloads = {};

  factory XNZImageDownloader() {
    return _singleton;
  }

  XNZImageDownloader._internal();

  void start(XNZImageDownloaderTask task) {
    tasks.add(task);
    final shared = _sharedDownloads[task.url];
    if (shared != null) {
      shared.subscribers.add(task);
      if (shared.total > 0) {
        task.count = shared.count;
        task.total = shared.total;
        task.onReceiveProgress?.call(shared.count, shared.total);
      }
      XNZNetworkImageLogs.log('XNZImageDownloader', '复用下载任务 ${task.url}');
      return;
    }

    final newShared = _SharedDownload();
    newShared.subscribers.add(task);
    _sharedDownloads[task.url] = newShared;

    XNZNetworkImageLogs.log('XNZImageDownloader', '开始下载 ${task.url}');
    dio.get<List<int>>(
      task.url,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        maxRedirects: 5,
        connectTimeout: task.connectTimeout,
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
      XNZNetworkImageLogs.log(
          'XNZImageDownloader', '下载完成 ${task.url}  length:${bytes.length}');

      final subscribers =
          List<XNZImageDownloaderTask>.from(newShared.subscribers);
      for (final subscriber in subscribers) {
        subscriber.onComplete?.call(bytes);
        tasks.remove(subscriber);
      }
      _sharedDownloads.remove(task.url);
    }).catchError((e) {
      XNZNetworkImageLogs.log('XNZImageDownloader', '下载失败 ${task.url} e:$e');

      final subscribers =
          List<XNZImageDownloaderTask>.from(newShared.subscribers);
      for (final subscriber in subscribers) {
        subscriber.onError?.call(e);
        tasks.remove(subscriber);
      }
      _sharedDownloads.remove(task.url);
    });
  }

  void cancel(XNZImageDownloaderTask task) {
    task.cancel();
    tasks.remove(task);
    final shared = _sharedDownloads[task.url];
    if (shared == null) return;

    shared.subscribers.remove(task);
    if (shared.subscribers.isEmpty) {
      shared.cancelToken.cancel('Canceled by user!');
      _sharedDownloads.remove(task.url);
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
  final XNZProgressCallback? onReceiveProgress;
  final Function(Uint8List)? onComplete;
  final Function(dynamic)? onError;
  final CancelToken? cancelToken;

  /// 各类超时时间（毫秒）
  final Duration connectTimeout;
  final Duration sendTimeout;
  final Duration receiveTimeout;

  int count = 0;
  int total = 0;

  XNZImageDownloaderTask({
    required this.url,
    required this.onComplete,
    required this.onError,
    this.onReceiveProgress,
    Duration? connectTimeout, // 连接超时
    Duration? sendTimeout, // 发送超时
    Duration? receiveTimeout, // 接收超时
  })  : cancelToken = CancelToken(),
        connectTimeout = connectTimeout ?? const Duration(milliseconds: 5000),
        sendTimeout = sendTimeout ?? const Duration(milliseconds: 5000),
        receiveTimeout = receiveTimeout ?? const Duration(milliseconds: 5000);

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

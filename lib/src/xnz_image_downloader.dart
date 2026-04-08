import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:xnz_net_cache_image/src/xnz_image_cache_logs.dart';

typedef XNZProgressCallback = void Function(int count, int total);

class XNZImageDownloader {
  static final XNZImageDownloader _singleton = XNZImageDownloader._internal();
  final Dio dio = Dio();
  final List<XNZImageDownloaderTask> tasks = [];

  factory XNZImageDownloader() {
    return _singleton;
  }

  XNZImageDownloader._internal();

  void start(XNZImageDownloaderTask task) {
    tasks.add(task);
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
        task.count = count;
        task.total = total;
        task.onReceiveProgress?.call(count, total);
      },
      cancelToken: task.cancelToken,
    ).then((Response<List<int>> response) {
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw StateError('Image download returned empty bytes: ${task.url}');
      }
      Uint8List bytes = Uint8List.fromList(data);
      XNZNetworkImageLogs.log(
          'XNZImageDownloader', '下载完成 ${task.url}  length:${bytes.length}');
      task.onComplete?.call(bytes);
      tasks.remove(task);
    }).catchError((e) {
      XNZNetworkImageLogs.log('XNZImageDownloader', '下载失败 ${task.url} e:$e');
      task.onError?.call(e);
      tasks.remove(task);
    });
  }

  void cancel(XNZImageDownloaderTask task) {
    task.cancel();
    tasks.remove(task);
  }

  void cancelAll() {
    for (var task in tasks) {
      task.cancel();
    }
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

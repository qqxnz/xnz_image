import 'package:flutter/foundation.dart';

class XNZImageLogs {
  /// 外部日志拦截器，返回 `true` 表示已消费并拦截默认输出。
  static bool Function(String tag, String log)? _interceptor;

  static bool showLogs = false;

  /// 设置外部日志拦截方法。
  static void setInterceptor(
      bool Function(String tag, String log)? interceptor) {
    _interceptor = interceptor;
  }

  static void log(String tag, String log) {
    final hasIntercepted = _interceptor?.call(tag, log) ?? false;
    if (!hasIntercepted && showLogs) {
      debugPrint('XNZImageLogs-$tag: $log');
    }
  }
}

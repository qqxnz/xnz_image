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

  /// Emits a structured log message with a normalized format:
  /// `[module][action][key=value,...]`.
  static void event(
    String module,
    String action, {
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    log(module, _formatEvent(module, action, fields));
  }

  static String _formatEvent(
    String module,
    String action,
    Map<String, Object?> fields,
  ) {
    final buffer = StringBuffer()..write('[$module][$action]');
    if (fields.isNotEmpty) {
      final pairs = <String>[];
      fields.forEach((key, value) {
        pairs.add('$key=$value');
      });
      buffer.write('[${pairs.join(',')}]');
    }
    return buffer.toString();
  }
}

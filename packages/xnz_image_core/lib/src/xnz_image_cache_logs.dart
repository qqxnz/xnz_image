import 'package:flutter/foundation.dart';

enum XNZImageLogFilter {
  all,
  success,
  failure,
}

enum _XNZImageEventType {
  neutral,
  success,
  failure,
}

class XNZImageLogs {
  /// 外部日志拦截器：
  /// - 兼容旧签名：`void Function(String tag, String log)`
  /// - 新签名：`bool Function(String tag, String log)`，返回 `true` 可拦截默认输出
  static Function(String tag, String log)? _interceptor;

  static bool showLogs = false;
  static XNZImageLogFilter logFilter = XNZImageLogFilter.all;

  /// 设置外部日志拦截方法。
  static void setInterceptor(Function(String tag, String log)? interceptor) {
    _interceptor = interceptor;
  }

  static void log(String tag, String log) {
    final result = _interceptor?.call(tag, log);
    final hasIntercepted = result is bool && result;
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
    if (!_shouldEmit(action)) {
      return;
    }
    log(module, _formatEvent(module, action, fields));
  }

  static bool _shouldEmit(String action) {
    if (logFilter == XNZImageLogFilter.all) {
      return true;
    }
    final type = _classify(action);
    if (logFilter == XNZImageLogFilter.success) {
      return type == _XNZImageEventType.success;
    }
    return type == _XNZImageEventType.failure;
  }

  static _XNZImageEventType _classify(String action) {
    final normalized = action.toLowerCase();

    const failureTokens = <String>[
      'failed',
      'error',
      'exception',
      'rejected',
      'invalid',
      'canceled',
      'cancelled',
      'abort',
      'timeout',
      'denied',
    ];
    for (final token in failureTokens) {
      if (normalized.contains(token)) {
        return _XNZImageEventType.failure;
      }
    }

    const successTokens = <String>[
      'success',
      'complete',
      'completed',
      'hit',
      'done',
      'loaded',
      'created',
      'saved',
    ];
    for (final token in successTokens) {
      if (normalized.contains(token)) {
        return _XNZImageEventType.success;
      }
    }

    return _XNZImageEventType.neutral;
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

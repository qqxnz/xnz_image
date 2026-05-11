import 'package:flutter/widgets.dart';
import 'package:xnz_image_core/src/xnz_cache_manager.dart';
import 'package:xnz_image_core/src/xnz_image_cache_logs.dart';

class XNZImageMemoryObserver with WidgetsBindingObserver {
  static final XNZImageMemoryObserver _instance =
      XNZImageMemoryObserver._internal();

  bool _isObserving = false;

  XNZImageMemoryObserver._internal();

  factory XNZImageMemoryObserver() => _instance;

  void init() {
    if (_isObserving) {
      XNZImageLogs.event(
        'XNZImageMemoryObserver',
        'init_skipped',
        fields: {'reason': 'already_observing'},
      );
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _isObserving = true;
    XNZImageLogs.event('XNZImageMemoryObserver', 'init');
  }

  @override
  void didHaveMemoryPressure() {
    XNZImageLogs.event('XNZImageMemoryObserver', 'memory_pressure');

    XNZCacheManager().memoryCache.clearAll();
  }

  void dispose() {
    if (!_isObserving) {
      XNZImageLogs.event(
        'XNZImageMemoryObserver',
        'dispose_skipped',
        fields: {'reason': 'not_observing'},
      );
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    _isObserving = false;
    XNZImageLogs.event('XNZImageMemoryObserver', 'dispose');
  }
}

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
      XNZImageLogs.log('XNZImageMemoryObserver', 'init skipped: already observing');
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _isObserving = true;
    XNZImageLogs.log('XNZImageMemoryObserver', 'init');
  }

  @override
  void didHaveMemoryPressure() {
    XNZImageLogs.log(
      'XNZImageMemoryObserver',
      '⚠️ Memory pressure detected → clear memory cache',
    );

    XNZCacheManager().memoryCache.clearAll();
  }

  void dispose() {
    if (!_isObserving) {
      XNZImageLogs.log('XNZImageMemoryObserver', 'dispose skipped: not observing');
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    _isObserving = false;
    XNZImageLogs.log('XNZImageMemoryObserver', 'dispose');
  }
}

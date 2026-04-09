import 'package:flutter/widgets.dart';
import 'package:xnz_image_core/src/xnz_cache_manager.dart';
import 'package:xnz_image_core/src/xnz_image_cache_logs.dart';

class XNZImageMemoryObserver with WidgetsBindingObserver {
  static final XNZImageMemoryObserver _instance =
      XNZImageMemoryObserver._internal();

  XNZImageMemoryObserver._internal();

  factory XNZImageMemoryObserver() => _instance;

  void init() {
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
  }
}
